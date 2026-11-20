"""Synthetic DiD with the Python `synthdid` package (d2cml-ai, port of the R reference package by Arkhangelsky et
al.) on exactly the case panels used in 12_synthetic_did.R, to compare with the hand-written R estimator.

Differences of the package from 12_synthetic_did.R: Frank-Wolfe solver with a sparsification step (weights below
1/4 of the largest are set to 0 and the problem is solved again), as in the R reference package.
Inference: placebo standard errors (package default method).

Environment: the package pins numpy 1.23 / pandas 1.5 / Python < 3.12, which clash with the project; it is pure
Python, so it is installed WITHOUT its pins in a separate environment:
    uv venv --python 3.13 <env>; VIRTUAL_ENV=<env> uv pip install numpy pandas scipy matplotlib statsmodels
    VIRTUAL_ENV=<env> uv pip install --no-deps synthdid==0.10.1
    <env>/bin/python empirics/scripts/10_robust_synthdid_python.py
Input : data/clean/sdid_case_data.csv.  Output: output/tables/sdid_python_vs_r.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd
from synthdid.synthdid import Synthdid

ROOT = Path(__file__).resolve().parents[2]
np.random.seed(20261112)

d = pd.read_csv(ROOT / "data" / "clean" / "sdid_case_data.csv")
r = pd.read_csv(ROOT / "output" / "tables" / "sdid_estimates.csv")
rows = []
for (case, outcome), g in d.groupby(["case", "outcome"], sort=False):
    g = g[["iso3", "year", "treated", "y"]].copy()
    for method, kw in (("sdid", {}), ("sc", {"synth": True}), ("did", {"did": True})):
        m = Synthdid(g, unit="iso3", time="year", treatment="treated", outcome="y").fit(**kw)
        att = float(np.ravel(m.att)[0]) if hasattr(m, "att") else np.nan
        try:
            se = float(np.ravel(m.vcov(method="placebo", n_reps=200).se)[0])
        except Exception as e:  # noqa: BLE001
            print(case, outcome, method, "placebo SE failed:", e)
            se = np.nan
        rows.append({"case": case, "outcome": outcome, "method": method, "tau_py": att, "se_py": se})
        print(f"{case:12s} {outcome:12s} {method:5s} tau {att:8.3f}  se {se:6.3f}")

out = pd.DataFrame(rows).merge(r[["case", "outcome", "method", "tau", "se_placebo"]], on=["case", "outcome", "method"])
out = out.rename(columns={"tau": "tau_r", "se_placebo": "se_r"})
out.to_csv(ROOT / "output" / "tables" / "sdid_python_vs_r.csv", index=False)
print(out.round(3).to_string())
print("correlation of point estimates:", out.groupby("method")[["tau_py", "tau_r"]].corr().round(3).iloc[0::2, 1].to_dict())
