"""
check_baseline.py
Stage:      checks (G4, regression detection)
Purpose:    Compare pipeline outputs with a frozen baseline cell by cell, or freeze a new one.
Reads:      data/clean/, data/processed/, empirics/results/ (CSV files), archive/baseline/
Writes:     archive/baseline/ (with --set-baseline), data/logs/check_baseline.log
Usage:      uv run python data/scripts/checks/check_baseline.py [--set-baseline]
Exit code:  0 = identical (up to relative tolerance 1e-12), 1 = differences.
"""
import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "utils"))
from pipeline import get_logger, project_root  # noqa: E402

TRACKED = ["data/clean", "data/processed", "empirics/results"]
BASELINE = Path("archive/baseline")
RTOL = 1e-12


def tracked_files(root: Path):
    for d in TRACKED:
        for p in sorted((root / d).rglob("*.csv")):
            if "logs" not in p.parts:
                yield p.relative_to(root)


def compare(log, a: Path, b: Path) -> int:
    x = pd.read_csv(a, dtype=str, keep_default_na=False)
    y = pd.read_csv(b, dtype=str, keep_default_na=False)
    if list(x.columns) != list(y.columns) or x.shape != y.shape:
        log.warning("shape_or_columns_differ", file=str(b), baseline=list(x.shape), current=list(y.shape))
        return 1
    diff = x.ne(y)
    n_bad = 0
    for col in x.columns[diff.any().to_numpy()]:
        xa = pd.to_numeric(x[col], errors="coerce").to_numpy()
        ya = pd.to_numeric(y[col], errors="coerce").to_numpy()
        numeric = ~np.isnan(xa) & ~np.isnan(ya)
        real = diff[col].to_numpy() & ~(numeric & np.isclose(xa, ya, rtol=RTOL, atol=0))
        if real.any():
            n_bad += int(real.sum())
            log.warning("cells_differ", file=str(b), column=col, n=int(real.sum()))
    return int(n_bad > 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set-baseline", action="store_true")
    a = ap.parse_args()
    root = project_root()
    log = get_logger("check_baseline")
    files = list(tracked_files(root))
    if a.set_baseline:
        shutil.rmtree(root / BASELINE, ignore_errors=True)
        for f in files:
            (root / BASELINE / f).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / f, root / BASELINE / f)
        log.info("baseline_set", files=len(files))
        return
    base = {p.relative_to(root / BASELINE) for p in (root / BASELINE).rglob("*.csv")}
    changed = 0
    for f in sorted(set(files) - base):
        log.warning("new_file", file=str(f)); changed += 1
    for f in sorted(base - set(files)):
        log.warning("missing_file", file=str(f)); changed += 1
    for f in sorted(base & set(files)):
        changed += compare(log, root / BASELINE / f, root / f)
    log.info("end", files_compared=len(base & set(files)), files_with_differences=changed)
    sys.exit(1 if changed else 0)


if __name__ == "__main__":
    main()
