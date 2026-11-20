"""Russia-specific input exposure from the Rosstat basic input-output tables 2021 (rule RU1; session 5; note 15).

dep_j  = Sum_p Mimp(p,j) WS_p b_p / Sum_p (Mimp + Mdom)(p,j)   share of j's manufactured inputs that were Western
         imports later banned (main)
sh_j   = Sum_p Mimp WS b / Sum_p Mimp WS                      banned share of j's Western imported inputs (variant)
west_j = Sum_p Mimp WS / Sum_p (Mimp + Mdom)                  Western import dependence regardless of bans (control)
Mimp: «М-имп» (imported products used, CIF); Mdom: «М-отеч» (domestic products used, basic prices); million roubles.
WS_p, b_p: Western share of Russia's 2019-21 imports and banned share (end-2023 EU list) of the Western imports, for the
HS codes of product row p (HS -> ISIC4 without 33xx -> 3-digit group named by the row's code; 2-digit fallback).

Input : data/raw/rosstat_io/baz_tzv-2021.xlsx (Rosstat, recovered from the Wayback Machine, archived 4 Apr 2025)
        data/clean/concordances/concord_hs_isic4.csv, ru_imports_hs6.parquet, eu_ban_hs07.csv, industry_ban_coverage.csv
Output: data/processed/input_exposure_ru/industry_input_exposure_ru.csv  nace3, rs_col, dep, sh, west
        data/processed/input_exposure_ru/rosstat_product_shares.csv      product row, WS, b
"""
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
CLEAN = ROOT / "data" / "clean"
F = ROOT / "data" / "raw" / "rosstat_io" / "baz_tzv-2021.xlsx"
MANUF = re.compile(r"\s*(1\d|2\d|3[0-3])(\D|$)")


def read_use(sheet):
    d = pd.read_excel(F, sheet_name=sheet, header=None, dtype=str)
    cols = {j: str(d.iloc[2, j]).strip() for j in range(3, d.shape[1]) if isinstance(d.iloc[2, j], str)}
    body = d.iloc[4:]
    body = body[body[1].notna() & body[1].astype(str).str.match(MANUF)]
    out = body[[1] + list(cols)].copy()
    out.columns = ["product"] + [cols[j] for j in cols]
    out["product"] = out["product"].str.strip()
    out = out.set_index("product").apply(pd.to_numeric, errors="coerce").fillna(0)
    return out[[c for c in out.columns if MANUF.match(c)]]


def components(code):
    """'25.2+ 25.3' -> ['25.2', '25.3'];  '29.10.1' -> ['29.10']"""
    parts = [p.strip() for p in code.split("+") if p.strip()]
    return [".".join(p.split(".")[:2]) for p in parts]


def isic_prefix(comp):
    """'26.1' -> '261'; '10.31' -> '103' (3-digit group); '12' -> '12'"""
    a, *b = comp.split(".")
    return a + (b[0][0] if b else "")


def main():
    mimp, mdom = read_use("М-имп"), read_use("М-отеч")
    mdom = mdom.reindex(index=mimp.index, columns=mimp.columns).fillna(0)
    print(f"Rosstat 2021: {mimp.shape[0]} manufactured product rows x {mimp.shape[1]} manufacturing industry columns")

    c = pd.read_csv(ROOT / "data" / "clean" / "concordances" / "concord_hs_isic4.csv", dtype=str).rename(columns={"HS_6d": "hs07", "ISIC4_4d": "isic4"})
    c = c[c.isic4.str.fullmatch(r"\d{4}", na=False)].drop_duplicates()
    c = c[c.isic4.str[:2] != "33"]
    c["k"] = 1 / c.groupby("hs07").isic4.transform("size")
    imp = pd.read_parquet(ROOT / "data" / "processed" / "ru_imports" / "ru_imports_hs6.parquet").rename(columns={"hs6": "hs07"})
    imp = imp[imp.year.between(2019, 2021)].groupby(["hs07", "group"]).v.mean().unstack(fill_value=0)
    ban = pd.read_csv(ROOT / "data" / "clean" / "eu_sanctions" / "eu_ban_hs07.csv", dtype={"hs07": str, "version": str})
    b = ban[(ban.list == "eu2022") & (ban.version <= "20231231")]
    b = b[b.version == b.version.max()].set_index("hs07").share
    x = c.merge(imp.reset_index(), on="hs07")
    x["W"], x["A"] = x.k * x.west, x.k * (x.west + x.china + x.other)
    x["WB"] = x.W * x.hs07.map(b).fillna(0)
    g3 = x.groupby(x.isic4.str[:3])[["W", "A", "WB"]].sum()
    g2 = x.groupby(x.isic4.str[:2])[["W", "A", "WB"]].sum()

    rows = []
    for p in mimp.index:
        acc = pd.Series({"W": 0.0, "A": 0.0, "WB": 0.0})
        for comp in components(p):
            pre = isic_prefix(comp)
            src = g3 if len(pre) == 3 else g2
            if pre in src.index and src.loc[pre, "A"] > 0:
                acc += src.loc[pre]
            elif pre[:2] in g2.index:
                acc += g2.loc[pre[:2]]
        rows.append((p, acc.W / acc.A if acc.A > 0 else 0.0, acc.WB / acc.W if acc.W > 0 else 0.0))
    ps = pd.DataFrame(rows, columns=["product", "WS", "b"]).set_index("product")
    ps.to_csv(ROOT / "data" / "processed" / "input_exposure_ru" / "rosstat_product_shares.csv")
    print(ps.loc[[r for r in ["21.2", "26.1", "26.3", "26.5", "28.4", "29.3", "20.14", "24.1"] if r in ps.index]].round(2).to_string())

    num = (mimp.mul(ps.WS * ps.b, axis=0)).sum()
    den = (mimp + mdom).sum()
    wimp = mimp.mul(ps.WS, axis=0).sum()
    col = pd.DataFrame({"dep": num / den, "sh": num / wimp, "west": wimp / den})

    # Rosstat industry columns -> NACE 3-digit units
    units = pd.read_csv(ROOT / "data" / "processed" / "industry_panel" / "industry_ban_coverage.csv").nace3.astype(int).tolist()

    def covers(code, n3):
        s = str(n3)
        m = re.match(r"(\d+)\s*без\s*(.*)", code)
        if m:
            excl = [e.replace(".", "") for e in re.findall(r"\d+\.\d+|\d+", m.group(2))]
            return s.startswith(m.group(1)) and not any(s.startswith(e) for e in excl)
        return any(s.startswith(comp.replace(".", "")[:3]) if "." in comp else s[:2] == comp
                   for comp in [q.strip() for q in code.split("+")])
    out = []
    for n3 in units:
        hits = [cd for cd in col.index if covers(cd, n3)]
        if hits:
            cd = max(hits, key=len)  # most specific column
            out.append((n3, cd, *col.loc[cd, ["dep", "sh", "west"]].tolist()))
    o = pd.DataFrame(out, columns=["nace3", "rs_col", "dep", "sh", "west"])
    o.to_csv(ROOT / "data" / "processed" / "input_exposure_ru" / "industry_input_exposure_ru.csv", index=False)
    print(f"\nNACE3 units mapped: {len(o)} of {len(units)}; distinct Rosstat columns: {o.rs_col.nunique()}")
    show = col.loc[[k for k in ["21", "26", "27", "28", "29", "30", "32.5", "24.1 + 24.2 + 24.3", "20.1", "22.2"] if k in col.index]]
    print(show.round(3).to_string())
    oc = pd.read_csv(ROOT / "data" / "processed" / "industry_panel" / "industry_ban_coverage.csv")
    bea = pd.read_csv(ROOT / "data" / "processed" / "input_exposure" / "industry_input_exposure.csv")
    m = o.merge(oc, on="nace3").merge(bea, on="nace3")
    print(f"corr: dep vs output coverage {m.dep.corr(m.coverage):.2f}; dep vs BEA input {m.dep.corr(m.input_cov):.2f}; "
          f"sh vs BEA input {m.sh.corr(m.input_cov):.2f}; dep vs west {m.dep.corr(m.west):.2f}")


if __name__ == "__main__":
    main()
