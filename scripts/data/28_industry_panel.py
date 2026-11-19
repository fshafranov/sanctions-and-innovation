"""Industry-level design (rule IND1, notes/data_decisions.md; session 5): patents and EU ban coverage by NACE Rev. 2
3-digit manufacturing industry.

Outcome side: official-IPC domestic patent counts by subclass x year (script 23, fractional) are distributed to
industries with the Dorner & Harhoff (2018) horizontal table corrtab_ipc4_frac_w08_3 (for each IPC subclass, the share
of its German EPO patents 1999-2011 made in each NACE 3-digit industry), restricted to manufacturing (divisions 10-32)
and renormalised within manufacturing.
Treatment side: HS07 -> ISIC4 (concord_hs_isic4.csv), links to ISIC 33xx (repair/installation) dropped, equal split
over the remaining links; ISIC4 -> NACE 3-digit (first 3 digits; if that group is not a NACE group in the table, equal
split over the table's groups of the same division). Coverage = banned share (end-2023 EU list) of the industry's
2019-21 Western imports, manufactured goods (HS 28-97).

Input : data/raw/concordances/iab_dorner_harhoff/horizontal tables/corrtab_ipc4_frac_w08_3_ano.dta
        data/clean/ru_domestic_subclass_year_official.csv, concord_hs_isic4.csv, ru_imports_hs6.parquet, eu_ban_hs07.csv
Output: data/clean/industry_year_patents.csv     nace3, year, n
        data/clean/industry_ban_coverage.csv     nace3, division, coverage, west_imports, n_hs
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "clean"


def main():
    t = pd.read_stata(RAW / "concordances" / "iab_dorner_harhoff" / "horizontal tables" / "corrtab_ipc4_frac_w08_3_ano.dta")
    t = t.melt(id_vars="ipc4", var_name="col", value_name="w")
    t["nace3"] = t.col.str.split("_").str[-1].astype(int)
    t["division"] = t.nace3 // 10
    t = t[t.division.between(10, 32) & (t.w > 0)]
    t["w"] = t.w / t.groupby("ipc4").w.transform("sum")
    groups = sorted(t.nace3.unique())
    print(f"DH table: {t.ipc4.nunique()} IPC subclasses with manufacturing weight, {len(groups)} manufacturing NACE groups")

    s = pd.read_csv(CLEAN / "ru_domestic_subclass_year_official.csv")
    s = s[s.year.between(2005, 2025)]
    cov_share = s[s.subclass.isin(t.ipc4)].n_frac.sum() / s.n_frac.sum()
    print(f"share of fractional domestic patents (2005-25) in subclasses covered by the table: {cov_share:.3f}")
    p = s.merge(t[["ipc4", "nace3", "w"]], left_on="subclass", right_on="ipc4")
    p["n"] = p.n_frac * p.w
    p = p.groupby(["nace3", "year"]).n.sum().reset_index()
    p.to_csv(CLEAN / "industry_year_patents.csv", index=False)

    c = pd.read_csv(CLEAN / "concord_hs_isic4.csv", dtype=str).rename(columns={"HS_6d": "hs07", "ISIC4_4d": "isic4"})
    c = c[c.isic4.str.fullmatch(r"\d{4}", na=False)].drop_duplicates()
    c = c[c.isic4.str[:2] != "33"]
    c["k"] = 1 / c.groupby("hs07").isic4.transform("size")
    c["g"] = c.isic4.str[:3].astype(int)
    c["div"] = c.g // 10
    direct = c[c.g.isin(groups)].assign(nace3=lambda d: d.g)
    rest = c[~c.g.isin(groups)]
    by_div = pd.DataFrame({"nace3": groups}).assign(div=lambda d: d.nace3 // 10)
    split = rest.merge(by_div, on="div")
    split["k"] = split.k / split.groupby(["hs07", "isic4"]).nace3.transform("size")
    m = pd.concat([direct, split])[["hs07", "nace3", "k"]]
    lost = set(rest.isic4) - set(split.isic4)
    print(f"ISIC4 codes mapped by division split: {rest.isic4.nunique()} ({len(lost)} with no manufacturing group, dropped)")

    imp = pd.read_parquet(CLEAN / "ru_imports_hs6.parquet").rename(columns={"hs6": "hs07"})
    W = imp[(imp.group == "west") & imp.year.between(2019, 2021) & imp.hs07.str[:2].astype(int).between(28, 97)] \
        .groupby("hs07").v.mean().rename("W").reset_index()
    ban = pd.read_csv(CLEAN / "eu_ban_hs07.csv", dtype={"hs07": str, "version": str})
    b = ban[(ban.list == "eu2022") & (ban.version <= "20231231")]
    b = b[b.version == b.version.max()][["hs07", "share"]]
    x = W.merge(m, on="hs07").merge(b, on="hs07", how="left").fillna({"share": 0})
    x["den"] = x.k * x.W
    g = x.assign(num=x.den * x.share).groupby("nace3").agg(num=("num", "sum"), den=("den", "sum"), n_hs=("hs07", "nunique"))
    out = pd.DataFrame({"nace3": g.index, "division": g.index // 10, "coverage": (g.num / g.den).values,
                        "west_imports": g.den.values, "n_hs": g.n_hs.values})
    out.to_csv(CLEAN / "industry_ban_coverage.csv", index=False)
    pre = p[p.year.between(2015, 2019)].groupby("nace3").n.mean()
    o = out.assign(pat=out.nace3.map(pre))
    keep = o[(o.pat >= 10) & (o.west_imports > 0)]
    print(f"industries: {len(out)} with imports; {len(keep)} with >= 10 patents/yr (2015-19) -> estimation sample")
    print(keep.sort_values("coverage", ascending=False).head(8).round(3).to_string(index=False))
    print(keep.sort_values("coverage").head(6).round(3).to_string(index=False))
    print("coverage across sample: mean %.3f sd %.3f" % (keep.coverage.mean(), keep.coverage.std()))


if __name__ == "__main__":
    main()
