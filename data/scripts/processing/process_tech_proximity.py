"""Technology closeness between IPC subclasses and between WIPO fields, from pre-war domestic patents (session 5).
Used for spillover ("neighbour exposure") terms in 18j_spillovers.R.

Population: domestic invention patents, mass filers dropped, filing years 2010-2021, official IPC (Rospatent API).
  P1 co-classification: C_ij = number of patents listing both i and j (distinct units per patent);
     w_coclass_ij = C_ij / sum_{k != i} C_ik (row-normalised, diagonal excluded).
  P2 holder overlap: H = holder x unit matrix of fractional patent counts; s_ij = cosine(H[:, i], H[:, j]);
     w_holder_ij = s_ij / sum_{k != i} s_ik (diagonal excluded). Holder names: lower case, quotes, country suffix
     "(RU)" and legal-form abbreviations removed; each holder of a patent gets the patent's fractional count.
Output: data/processed/tech_proximity/tech_proximity.csv  level (subclass/field), i, j, w_coclass, w_holder
"""
import re
from itertools import combinations
from pathlib import Path
import importlib.util

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
CLEAN = ROOT / "data" / "clean"
sp = importlib.util.spec_from_file_location("s10", ROOT / "data" / "scripts" / "processing" / "process_ru_patents_google.py")
s10 = importlib.util.module_from_spec(sp)
sp.loader.exec_module(s10)
BY_GROUP, BY_SUB, _ = s10.concordance()
FORMS = r"\b(ооо|оао|зао|пао|ао|фгуп|фгбоу во|фгбоу впо|фгаоу во|фгбу|фгбун|гоу впо|ано|нко|федеральное государственное[^\"«]*|общество с ограниченной ответственностью|акционерное общество|открытое|закрытое|публичное)\b"


def field_of(code):
    m = re.match(r"([A-H]\d\d[A-Z])\s*(\d+)/", code)
    if not m:
        return None
    return BY_GROUP.get((m.group(1), m.group(2))) or BY_SUB.get(m.group(1))


def norm(h):
    h = re.sub(r"\([A-Z]{2}\)\s*$", "", h.lower())
    h = re.sub(FORMS, " ", h)
    h = re.sub(r"[\"«»'“”.,]", " ", h)
    return re.sub(r"\s+", " ", h).strip()


def weights(d, col, level):
    units = sorted({u for us in d[col] for u in us})
    ix = {u: k for k, u in enumerate(units)}
    n = len(units)
    C = np.zeros((n, n))
    for us in d[col]:
        for a, b in combinations(us, 2):
            C[ix[a], ix[b]] += 1
            C[ix[b], ix[a]] += 1
    x = d[[col, "holders"]].explode(col).dropna(subset=[col])
    x["w"] = 1 / d[col].str.len().reindex(x.index)
    x = x.explode("holders").dropna(subset=["holders"])
    x["h"] = x.holders.map(norm)
    H = x.groupby(["h", col]).w.sum().unstack(fill_value=0).reindex(columns=units, fill_value=0)
    Hm = H.values
    nrm = np.linalg.norm(Hm, axis=0)
    S = (Hm.T @ Hm) / np.outer(nrm, nrm).clip(min=1e-12)
    np.fill_diagonal(S, 0)
    np.fill_diagonal(C, 0)
    rc, rs = C.sum(1, keepdims=True), S.sum(1, keepdims=True)
    Wc = np.divide(C, rc, out=np.zeros_like(C), where=rc > 0)
    Ws = np.divide(S, rs, out=np.zeros_like(S), where=rs > 0)
    i, j = np.nonzero((Wc > 0) | (Ws > 0))
    out = pd.DataFrame({"level": level, "i": np.array(units)[i], "j": np.array(units)[j],
                        "w_coclass": Wc[i, j], "w_holder": Ws[i, j]})
    multi = (d[col].str.len() >= 2).mean()
    print(f"{level}: {n} units, {len(d)} patents, {multi:.1%} with >= 2 {level}s, {H.shape[0]} distinct holders; "
          f"corr of the two weight sets (off-diagonal) {np.corrcoef(Wc[~np.eye(n, dtype=bool)], Ws[~np.eye(n, dtype=bool)])[0, 1]:.2f}")
    return out


def main():
    reg = pd.read_parquet(ROOT / "data" / "clean" / "rospatent" / "rospatent_inventions.parquet", columns=["reg_no", "app_year", "domestic", "mass_filer"])
    reg["reg_no"] = reg.reg_no.astype(str)
    api = pd.read_parquet(ROOT / "data" / "clean" / "rospatent_api" / "rospatent_api_biblio.parquet", columns=["reg_no", "ipc", "holders"])
    d = reg[reg.domestic & ~reg.mass_filer & reg.app_year.between(2010, 2021)].merge(api, on="reg_no")
    d["subs"] = d.ipc.apply(lambda cs: sorted({c[:4] for c in cs if len(c) >= 4}))
    d["fields"] = d.ipc.apply(lambda cs: sorted({f for f in map(field_of, cs) if f}))
    d["holders"] = d.holders.apply(lambda h: list(h) if h is not None else [])
    out = pd.concat([weights(d, "subs", "subclass"), weights(d, "fields", "field")])
    out.to_csv(ROOT / "data" / "processed" / "tech_proximity" / "tech_proximity.csv", index=False)
    f = out[out.level == "field"].copy()
    print("example: field 3 (telecom), top co-class neighbours:",
          f[f.i == 3].nlargest(4, "w_coclass")[["j", "w_coclass", "w_holder"]].round(3).to_dict("records"))


if __name__ == "__main__":
    main()
