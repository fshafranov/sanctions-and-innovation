"""
pipeline.py
Stage:   shared utilities (not a pipeline step)
Purpose: structured logging (structlog), non-silenceable assertions, attrition
         tracking, checked merges, constructed-variable summaries, post-download
         verification, deterministic writes (CSV default; Parquet/DTA on request)
         and results export, so every script logs the same way (G5, B3, C2, C3, D3).

Import from any pipeline script with:

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[N] / "data" / "scripts" / "utils"))
    from pipeline import ...

where N is the number of levels from the script up to the project root
(data/scripts/<stage>/x.py -> 3, empirics/scripts/x.py -> 2).
"""
import json
import logging
import math
import sys
import zipfile
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd
import structlog

__all__ = [
    "project_root", "get_logger", "check", "log_shape", "rename_logged",
    "recode_sentinels", "map_categories", "AttritionTracker", "checked_merge",
    "summarize_var", "verify_files", "write_table", "Discrepancies",
    "tidy_model", "check_sample_consistency", "compare_to_published",
]

# Fixed header timestamp so .dta output is byte-identical across runs (G4).
_DTA_TIMESTAMP = datetime(2000, 1, 1)


def project_root() -> Path:
    """Project root = the directory containing run_all.py (searched upwards)."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "run_all.py").exists():
            return parent
    raise RuntimeError(f"Could not locate project root (no run_all.py found above {here})")


class _Tee:
    """File-like object writing to stdout and the script's log file."""

    def __init__(self, path: Path):
        self.fh = path.open("w", encoding="utf-8")  # write mode: one log per script, replaced each run

    def write(self, s):
        sys.stdout.write(s)
        self.fh.write(s)

    def flush(self):
        sys.stdout.flush()
        self.fh.flush()


def get_logger(script_name: str, log_dir: str = "data/logs"):
    """structlog logger writing to stdout and {log_dir}/{script_name}.log (G4, G5).

    Use events with key-value context:  log.info("filter", step="age 25-65", dropped=312)
    """
    path = project_root() / log_dir / f"{script_name}.log"
    path.parent.mkdir(parents=True, exist_ok=True)
    structlog.configure(
        processors=[
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="%Y-%m-%d %H:%M:%S"),
            structlog.processors.format_exc_info,
            structlog.dev.ConsoleRenderer(colors=False, pad_event=32),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
        logger_factory=structlog.PrintLoggerFactory(file=_Tee(path)),
        cache_logger_on_first_use=False,
    )
    log = structlog.get_logger().bind(script=script_name)
    log.info("start")
    return log


def check(condition, message: str) -> None:
    """Assertion that survives `python -O`. Message should state expected vs found."""
    if not bool(condition):
        raise AssertionError(message)


def log_shape(log, df: pd.DataFrame, label: str) -> None:
    log.info("shape", data=label, rows=df.shape[0], cols=df.shape[1])


def rename_logged(log, df: pd.DataFrame, mapping: dict) -> pd.DataFrame:
    missing = [c for c in mapping if c not in df.columns]
    check(not missing, f"rename: source columns not found: {missing}")
    for old, new in mapping.items():
        log.info("rename", old=old, new=new)
    return df.rename(columns=mapping)


def recode_sentinels(log, df: pd.DataFrame, col: str, sentinels) -> pd.DataFrame:
    mask = df[col].isin(list(sentinels))
    df[col] = df[col].mask(mask)
    log.info("recode_sentinels", var=col, sentinels=list(sentinels), n_recoded=int(mask.sum()))
    return df


def map_categories(log, df: pd.DataFrame, col: str, mapping: dict, new_col: str = None):
    """Map codes to labels. Undocumented codes are kept, flagged and logged (B2)."""
    new_col = new_col or col
    raw = df[col]
    unmapped = raw.notna() & ~raw.isin(list(mapping))
    labelled = raw.map(mapping).astype(object)
    labelled[unmapped] = raw[unmapped].astype(str)
    df[new_col] = labelled
    df[f"{new_col}_unmapped"] = unmapped
    log.info("map_categories", var=col, new_var=new_col,
             n_mapped=int((~unmapped & raw.notna()).sum()), n_undocumented=int(unmapped.sum()),
             undocumented_codes=sorted(raw[unmapped].astype(str).unique().tolist())[:20])
    return df


class AttritionTracker:
    """Logs every sample-selection filter and a cumulative summary (C2)."""

    def __init__(self, log, df: pd.DataFrame, label: str = "start"):
        self.log = log
        self.steps = [(label, len(df), 0, len(df))]
        self.dropped = []
        log.info("attrition_start", data=label, obs=len(df))

    def filter(self, df: pd.DataFrame, keep_mask, reason: str) -> pd.DataFrame:
        before = len(df)
        out = df.loc[keep_mask].copy()
        self.dropped.append(df.loc[~keep_mask].assign(drop_reason=reason))
        dropped = before - len(out)
        self.steps.append((reason, before, dropped, len(out)))
        self.log.info("attrition", step=reason, before=before, dropped=dropped, remaining=len(out))
        return out

    def summary(self) -> pd.DataFrame:
        tab = pd.DataFrame(self.steps, columns=["step", "before", "dropped", "remaining"])
        tab["cumulative_dropped"] = tab["dropped"].cumsum()
        start = tab.loc[0, "remaining"]
        check(start - tab["dropped"].sum() == tab["remaining"].iloc[-1],
              "attrition does not add up: start - sum(dropped) != final")
        self.log.info("attrition_summary", start=int(start), dropped=int(tab["dropped"].sum()),
                      final=int(tab["remaining"].iloc[-1]), table="\n" + tab.to_string(index=False))
        return tab

    def write_dropped(self, rel_path: str, sort_by=None) -> None:
        """Set-aside file: every dropped row with its reason, so exclusions can be inspected."""
        frames = [d for d in self.dropped if len(d)]
        out = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame(columns=["drop_reason"])
        write_table(self.log, out, rel_path, sort_by=sort_by if len(out) else None)


def checked_merge(log, left: pd.DataFrame, right: pd.DataFrame, on, how: str,
                  validate: str, name: str = "merge") -> pd.DataFrame:
    """Assert key uniqueness before joining and log match rates from both sides (C2).

    validate: '1:1', '1:m', 'm:1' (m:m is not allowed: it is almost always a bug).
    """
    on = [on] if isinstance(on, str) else list(on)
    check(validate in ("1:1", "1:m", "m:1"), f"{name}: validate must be 1:1, 1:m or m:1")
    if validate in ("1:1", "1:m"):
        d = int(left.duplicated(on).sum())
        check(d == 0, f"{name}: left keys {on} not unique ({d} duplicates)")
    if validate in ("1:1", "m:1"):
        d = int(right.duplicated(on).sum())
        check(d == 0, f"{name}: right keys {on} not unique ({d} duplicates)")
    full = left.merge(right, on=on, how="outer", indicator=True, validate=validate)
    counts = full["_merge"].value_counts()
    lm = left.merge(right[on].drop_duplicates(), on=on, how="inner").shape[0]
    rm = right.merge(left[on].drop_duplicates(), on=on, how="inner").shape[0]
    log.info("merge", name=name, on=on, validate=validate, how=how,
             left_rows=len(left), right_rows=len(right),
             matched_rows=int(counts.get("both", 0)),
             left_only=int(counts.get("left_only", 0)), right_only=int(counts.get("right_only", 0)),
             left_match_rate=round(lm / max(len(left), 1), 4),
             right_match_rate=round(rm / max(len(right), 1), 4))
    keep = {"inner": ["both"], "left": ["both", "left_only"],
            "right": ["both", "right_only"], "outer": ["both", "left_only", "right_only"]}[how]
    out = full[full["_merge"].isin(keep)].drop(columns="_merge")
    log_shape(log, out, f"{name} result")
    return out


def summarize_var(log, df: pd.DataFrame, col: str, lower=None, upper=None, inputs=None):
    """Summary stats + bound checks for a constructed variable (C3)."""
    s = pd.to_numeric(df[col], errors="raise").astype("float64")
    n_inf = int(np.isinf(s).sum())
    check(n_inf == 0, f"{col}: {n_inf} infinite values (division by zero / log of 0?)")
    f = s.dropna()
    log.info("variable", var=col, count=int(f.size),
             mean=round(float(f.mean()), 6) if f.size else math.nan,
             min=float(f.min()) if f.size else math.nan, max=float(f.max()) if f.size else math.nan,
             share_missing=round(float(s.isna().mean()), 4))
    if lower is not None:
        bad = int((f < lower).sum())
        check(bad == 0, f"{col}: {bad} values below lower bound {lower}")
    if upper is not None:
        bad = int((f > upper).sum())
        check(bad == 0, f"{col}: {bad} values above upper bound {upper}")
    if inputs:
        implied = df[list(inputs)].isna().any(axis=1)
        log.info("variable_missingness", var=col, inputs=list(inputs),
                 missing_implied_by_inputs=int(implied.sum()),
                 additional_missing=int((s.isna() & ~implied).sum()))
        check(int((s.notna() & implied).sum()) == 0,
              f"{col}: non-missing where an input {list(inputs)} is missing")


def _sniff(path: Path, fmt: str) -> None:
    head = path.open("rb").read(16).lstrip().lower()
    check(not head.startswith((b"<!doc", b"<html")), f"{path.name}: looks like an HTML error page, not {fmt}")
    if fmt in ("zip", "xlsx", "docx"):
        check(zipfile.is_zipfile(path), f"{path.name}: declared {fmt} but not a zip container")
    elif fmt == "gz":
        check(path.open("rb").read(2) == b"\x1f\x8b", f"{path.name}: declared gzip but magic bytes differ")
    elif fmt == "parquet":
        check(path.open("rb").read(4) == b"PAR1", f"{path.name}: declared parquet but magic bytes differ")
    elif fmt == "json":
        json.loads(path.read_text(encoding="utf-8"))
    elif fmt in ("csv", "tsv", "txt"):
        sample = pd.read_csv(path, sep="\t" if fmt == "tsv" else ",", nrows=5, dtype=str)
        check(sample.shape[1] > 0, f"{path.name}: no columns parsed")
    elif fmt == "dta":
        with pd.read_stata(path, iterator=True) as reader:
            reader.read(1)


def verify_files(log, expected: dict) -> None:
    """A3: expected = {relative_path: format}. Checks exists, non-empty, format."""
    root = project_root()
    for rel, fmt in expected.items():
        p = root / rel
        check(p.exists(), f"expected file missing after acquisition: {rel}")
        size = p.stat().st_size
        check(size > 0, f"file is empty: {rel}")
        _sniff(p, fmt)
        log.info("verified", file=rel, format=fmt, bytes=size)


def write_table(log, df: pd.DataFrame, rel_path: str, sort_by=None,
                labels: dict = None, value_labels: dict = None) -> None:
    """Deterministic overwrite (G4): rows sorted by key, format from the extension.

    .csv is the default. Use .parquet for very large files (millions of rows) and .dta
    when Stata consumes the file; for .dta pass `labels` ({var: "description"}) and,
    for coded categoricals, `value_labels` ({var: {code: "label"}}).
    """
    out = project_root() / rel_path
    out.parent.mkdir(parents=True, exist_ok=True)
    if sort_by:
        df = df.sort_values(sort_by, kind="mergesort").reset_index(drop=True)
    if out.suffix == ".csv":
        df.to_csv(out, index=False)
    elif out.suffix == ".parquet":
        df.to_parquet(out, index=False)
    elif out.suffix == ".dta":
        missing = sorted(set(df.columns) - set(labels or {}))
        check(not missing, f"{rel_path}: .dta output needs a variable label for every column; missing {missing}")
        df.to_stata(out, write_index=False, version=118, variable_labels=labels,
                    value_labels=value_labels, time_stamp=_DTA_TIMESTAMP)
    else:
        raise ValueError(f"unsupported output format: {out.suffix}")
    log.info("wrote", file=rel_path, rows=df.shape[0], cols=df.shape[1])


class Discrepancies:
    """Collects codebook-vs-data disagreements and writes them to a CSV (B1)."""

    def __init__(self, log):
        self.log = log
        self.rows = []

    def add(self, variable, expected, observed, count, handling):
        self.rows.append(dict(variable=variable, expected=str(expected), observed=str(observed),
                              count=int(count), handling=handling))
        self.log.warning("discrepancy", var=variable, expected=str(expected),
                         observed=str(observed), n=int(count), handling=handling)

    def write(self, rel_path: str) -> None:
        df = pd.DataFrame(self.rows, columns=["variable", "expected", "observed", "count", "handling"])
        write_table(self.log, df, rel_path, sort_by=["variable", "expected"] if len(df) else None)


def tidy_model(res, spec: str, sample: str = "main", fe: str = "") -> pd.DataFrame:
    """Tidy a pyfixest, linearmodels or statsmodels result into the standard long format (D3)."""
    if hasattr(res, "tidy") and hasattr(res, "_N"):  # pyfixest
        t = res.tidy()
        est = t["Estimate"]
        se, stat, p = t["Std. Error"], t["t value"], t["Pr(>|t|)"]
        nobs, r2 = int(res._N), getattr(res, "_r2", np.nan)
        r2w = getattr(res, "_r2_within", np.nan)
        se_type = str(getattr(res, "_vcov_type_detail", getattr(res, "_vcov_type", "")))
        fe = fe or (getattr(res, "_fixef", None) or "")
        f1 = np.nan
        if getattr(res, "_is_iv", False):
            try:
                res.IV_Diag()
                f1 = float(getattr(res, "_f_stat_1st_stage", np.nan))
            except Exception:  # first-stage diagnostics unavailable for this model
                f1 = np.nan
    elif hasattr(res, "std_errors"):  # linearmodels
        est, se, stat, p = res.params, res.std_errors, res.tstats, res.pvalues
        nobs, r2 = int(res.nobs), getattr(res, "rsquared", np.nan)
        r2w, se_type = getattr(res, "rsquared_within", np.nan), getattr(res, "cov_type", "")
        f1 = np.nan
        if hasattr(res, "first_stage"):
            try:
                f1 = float(res.first_stage.diagnostics["f.stat"].min())
            except Exception:  # first-stage diagnostics unavailable for this estimator
                f1 = np.nan
    else:  # statsmodels
        est, se, stat, p = res.params, res.bse, res.tvalues, res.pvalues
        nobs, r2, r2w = int(res.nobs), getattr(res, "rsquared", np.nan), np.nan
        se_type, f1 = getattr(res, "cov_type", ""), np.nan
    return pd.DataFrame({
        "spec": spec, "term": list(est.index), "estimate": est.to_numpy(),
        "std_error": se.to_numpy(), "statistic": stat.to_numpy(), "p_value": p.to_numpy(),
        "nobs": nobs, "r2": r2, "r2_within": r2w, "fstat_first_stage": f1,
        "se_type": se_type, "fe": fe, "sample": sample,
    })


def check_sample_consistency(log, results: pd.DataFrame, script: str, warnings_text=()) -> list:
    """D4: compare N across specs sharing a sample label; write differences and captured
    estimation warnings to empirics/results/warnings/{script}.md (generated, overwritten)."""
    out = []
    ns = results[["spec", "sample", "nobs"]].drop_duplicates()
    for s, sub in ns.groupby("sample", sort=True):
        if sub["nobs"].nunique() > 1:
            msg = f"Sample '{s}': N differs across specs: " + ", ".join(
                f"{a}={b}" for a, b in zip(sub["spec"], sub["nobs"]))
            log.warning("sample_inconsistency", sample=s, detail=msg)
            out.append("- " + msg)
    out += ["- estimation warning: " + w for w in dict.fromkeys(warnings_text)]
    path = project_root() / "empirics" / "results" / "warnings" / f"{script}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"# Estimation warnings: {script}\n\n" + ("\n".join(out) if out else "- none") + "\n",
                    encoding="utf-8")
    return out


REGISTER_COLUMNS = ["table", "column", "row", "published", "replicated", "diff", "status",
                    "explanation", "script", "decision_id"]


def compare_to_published(log, results: pd.DataFrame, published: pd.DataFrame, script: str,
                         table: str) -> pd.DataFrame:
    """Compare replicated estimates with the paper's numbers and sync mismatch-register.csv.

    published: columns column, row, published, tolerance, source (one row per printed cell;
               transcribed into data/raw/published/ with page references). `column` is the
               paper's column label (e.g. "(3)") and must match results["spec"]; `row` matches
               results["term"]. Standard errors go in as separate rows, e.g. row "x__se".
    The register keeps the human-written `explanation` and `decision_id` for each cell and
    refreshes the numbers. Status: match | explained | open (explanation starts with UNRESOLVED:) | unexplained.
    """
    res = results.melt(id_vars=["spec", "term"], value_vars=["estimate", "std_error"])
    res["row"] = np.where(res["variable"] == "estimate", res["term"], res["term"] + "__se")
    res = res.rename(columns={"spec": "column", "value": "replicated"})[["column", "row", "replicated"]]
    m = published.merge(res, on=["column", "row"], how="left", validate="1:1")
    m["diff"] = m["replicated"] - m["published"]
    ok = m["diff"].abs() <= m["tolerance"]

    path = project_root() / "mismatch-register.csv"
    reg = pd.read_csv(path, dtype=str, keep_default_na=False) if path.exists() else pd.DataFrame(columns=REGISTER_COLUMNS)
    key = ["table", "column", "row", "script"]
    old = reg.set_index(key) if len(reg) else None
    rows = []
    for r, is_ok in zip(m.itertuples(), ok):
        k = (table, r.column, r.row, script)
        expl = old.loc[k, "explanation"] if old is not None and k in old.index else ""
        dec = old.loc[k, "decision_id"] if old is not None and k in old.index else ""
        if is_ok:
            status = "match"
        elif not expl:
            status = "unexplained"
        else:  # investigated but unresolved mismatches stay visible as "open"
            status = "open" if expl.upper().startswith("UNRESOLVED") else "explained"
        rows.append(dict(table=table, column=r.column, row=r.row, published=r.published,
                         replicated="" if pd.isna(r.replicated) else round(float(r.replicated), 6),
                         diff="" if pd.isna(r.diff) else round(float(r.diff), 6), status=status,
                         explanation=expl, script=script, decision_id=dec))
    new = pd.DataFrame(rows, columns=REGISTER_COLUMNS)
    keep = reg[~((reg["table"] == table) & (reg["script"] == script))] if len(reg) else reg
    out = pd.concat([keep, new.astype(str)], ignore_index=True).sort_values(key, kind="mergesort")
    out.to_csv(path, index=False)
    n_un = int((new["status"] == "unexplained").sum())
    log.info("compare_to_published", script=script, table=table, cells=len(new),
             matched=int((new["status"] == "match").sum()),
             explained=int((new["status"] == "explained").sum()), unexplained=n_un)
    if n_un:
        log.warning("unexplained_mismatches", n=n_un,
                    detail="add an explanation (and decision_id) in mismatch-register.csv")
    return new
