"""Parse the BEA 2017 detail industry/commodity codes and their related NAICS 2017 codes (rule IN1; session 5).
Input : data/raw/bea/IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx (sheet "NAICS Codes"; from AllTablesIO.zip)
Output: data/clean/bea_detail_naics.csv  bea, naics  (one row per related NAICS code; ranges like 333995-6 expanded)
"""
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
F = ROOT / "data" / "raw" / "bea" / "IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx"


def expand(tok):
    tok = tok.strip()
    m = re.fullmatch(r"(\d+)-(\d+)", tok)
    if m:
        a, b = m.groups()
        stem, lo = a[: len(a) - len(b)], int(a[len(a) - len(b):])
        return [f"{stem}{k}" for k in range(lo, int(b) + 1)]
    return [tok] if re.fullmatch(r"\d+", tok) else []


def main():
    d = pd.read_excel(F, sheet_name="NAICS Codes", header=None, dtype=str).iloc[5:]
    d = d[d[3].notna() & d[3].str.fullmatch(r"[0-9A-Z]{6}", na=False)]
    rows = [(r[3], n) for _, r in d.iterrows() for tok in str(r[6]).split(",") for n in expand(tok)]
    out = pd.DataFrame(rows, columns=["bea", "naics"]).drop_duplicates()
    out.to_csv(ROOT / "data" / "clean" / "bea_detail_naics.csv", index=False)
    print(f"{out.bea.nunique()} BEA detail codes, {len(out)} BEA-NAICS links; manufacturing codes "
          f"{out[out.naics.str[:2].isin(['31', '32', '33'])].bea.nunique()}")


if __name__ == "__main__":
    main()
