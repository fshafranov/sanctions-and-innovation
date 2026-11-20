"""Input-based EU ban exposure by NACE 3-digit manufacturing industry (rule IN1; session 5; note 15).
Input exposure_j = Sum_c U(c, j) b_c / Sum_c U(c, j): the banned share of what industry j BUYS, with U from the BEA
2017 detailed Use table (US input structure as proxy) and b_c the banned share of Russia's 2019-21 Western imports
in commodity c's product group (end-2023 EU list).

Input : data/raw/bea/IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx (sheet 2017), data/clean/bea_detail_naics.csv,
        concord_naics17_isic4.csv, concord_hs_isic4.csv, ru_imports_hs6.parquet, eu_ban_hs07.csv,
        industry_ban_coverage.csv (output exposure, script 28)
Output: data/clean/industry_input_exposure.csv  nace3, input_cov, input_cov_exown, input_value
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
CLEAN = ROOT / "data" / "clean"


def nace_groups():
    t = pd.read_stata(ROOT / "data" / "raw" / "concordances" / "iab_dorner_harhoff" / "horizontal tables" /
                      "corrtab_ipc4_frac_w08_3_ano.dta")
    g = sorted({int(c.split("_")[-1]) for c in t.columns if c.startswith("w08_3_")})
    return [x for x in g if 10 <= x // 10 <= 32]


def isic_to_nace(isic, groups):
    """ISIC4 code -> list of (nace3, share): first 3 digits if a NACE group, else equal split over the division."""
    g = int(isic[:3])
    if g in groups:
        return [(g, 1.0)]
    same = [x for x in groups if x // 10 == g // 10]
    return [(x, 1 / len(same)) for x in same]


def main():
    groups = nace_groups()
    bn = pd.read_csv(CLEAN / "bea_detail_naics.csv", dtype=str)
    ni = pd.read_csv(CLEAN / "concord_naics17_isic4.csv", dtype=str).dropna()
    ni["w"] = ni.w.astype(float)
    ni["w"] = ni.w / ni.groupby("naics").w.transform("sum")
    bi = bn.merge(ni, on="naics")
    bi["w"] = bi.w / bi.groupby("bea").naics.transform("nunique")
    bi = bi.groupby(["bea", "isic4"]).w.sum().reset_index()          # BEA code -> ISIC4 weights (sum 1)
    manuf_bea = set(bn[bn.naics.str[:2].isin(["31", "32", "33"])].bea)
    print(f"BEA manufacturing codes: {len(manuf_bea)}; with ISIC link: {len(manuf_bea & set(bi.bea))}")

    # banned share by ISIC4 product group (Western imports 2019-21, end-2023 list)
    c = pd.read_csv(CLEAN / "concord_hs_isic4.csv", dtype=str).rename(columns={"HS_6d": "hs07", "ISIC4_4d": "isic4"})
    c = c[c.isic4.str.fullmatch(r"\d{4}", na=False)].drop_duplicates()
    c = c[c.isic4.str[:2] != "33"]
    c["k"] = 1 / c.groupby("hs07").isic4.transform("size")
    imp = pd.read_parquet(CLEAN / "ru_imports_hs6.parquet").rename(columns={"hs6": "hs07"})
    W = imp[(imp.group == "west") & imp.year.between(2019, 2021) & imp.hs07.str[:2].astype(int).between(28, 97)] \
        .groupby("hs07").v.mean().rename("W").reset_index()
    ban = pd.read_csv(CLEAN / "eu_ban_hs07.csv", dtype={"hs07": str, "version": str})
    b = ban[(ban.list == "eu2022") & (ban.version <= "20231231")]
    b = b[b.version == b.version.max()][["hs07", "share"]]
    x = W.merge(c, on="hs07").merge(b, on="hs07", how="left").fillna({"share": 0})
    x["den"] = x.k * x.W
    gi = x.assign(num=x.den * x.share).groupby("isic4")[["num", "den"]].sum()
    gi = gi[gi.den > 0]
    gi["b"] = gi.num / gi.den

    # commodity ban share b_c (manufactured commodities with import data)
    bc = bi[bi.bea.isin(manuf_bea)].merge(gi[["b"]].reset_index(), on="isic4")
    bc["w"] = bc.w / bc.groupby("bea").w.transform("sum")
    bc = bc.assign(wb=bc.w * bc.b).groupby("bea").wb.sum().rename("b_c")
    print(f"commodities with a ban share: {len(bc)}; mean {bc.mean():.3f}")

    # use table 2017: commodity rows x industry columns
    u = pd.read_excel(CLEAN.parent / "raw" / "bea" / "IOUse_Before_Redefinitions_PRO_2017_Detail.xlsx", sheet_name="2017",
                      header=None, dtype=str)
    codes_col = u.iloc[5].tolist()
    body = u.iloc[6:].copy()
    body = body[body[0].str.fullmatch(r"[0-9A-Z]{6}", na=False)]
    ind_cols = [j for j, cd in enumerate(codes_col) if isinstance(cd, str) and len(cd) == 6 and j >= 2]
    U = body.set_index(0)[ind_cols].apply(pd.to_numeric, errors="coerce").fillna(0)
    U.columns = [codes_col[j] for j in ind_cols]
    U = U.loc[U.index.isin(bc.index)]                                   # manufactured inputs with ban share
    print(f"use table: {U.shape[0]} input commodities x {U.shape[1]} using industries")

    # using BEA industries -> NACE3 (via ISIC weights)
    bn3 = []
    for bea, g in bi.groupby("bea"):
        for _, r in g.iterrows():
            for n3, s in isic_to_nace(r.isic4, groups):
                bn3.append((bea, n3, r.w * s))
    bn3 = pd.DataFrame(bn3, columns=["bea", "nace3", "w"]).groupby(["bea", "nace3"]).w.sum().reset_index()
    bn3 = bn3[bn3.bea.isin(U.columns) & bn3.bea.isin(manuf_bea)]
    # own product group of each NACE3 (commodities whose ISIC maps to that NACE3)
    own = bn3.rename(columns={"bea": "commodity"})
    out = []
    for n3, g in bn3.groupby("nace3"):
        use = (U[g.bea.values] * g.w.values).sum(axis=1)               # commodity use by NACE3 industry n3
        own_c = set(own[(own.nace3 == n3) & (own.w > 0.5)].commodity)
        num, den = (use * bc.reindex(use.index)).sum(), use.sum()
        mask = ~use.index.isin(own_c)
        out.append((n3, num / den if den > 0 else np.nan,
                    (use[mask] * bc.reindex(use.index)[mask]).sum() / use[mask].sum() if use[mask].sum() > 0 else np.nan, den))
    o = pd.DataFrame(out, columns=["nace3", "input_cov", "input_cov_exown", "input_value"])
    o.to_csv(CLEAN / "industry_input_exposure.csv", index=False)
    oc = pd.read_csv(CLEAN / "industry_ban_coverage.csv")
    m = oc.merge(o, on="nace3")
    print(f"NACE3 industries with input exposure: {len(o)}; overlap with output sample: {len(m)}")
    print(f"corr(output coverage, input exposure) = {m.coverage.corr(m.input_cov):.2f}; "
          f"input exposure mean {m.input_cov.mean():.3f}, SD {m.input_cov.std():.3f}")
    show = m[m.nace3.isin([211, 212, 261, 262, 263, 266, 271, 281, 282, 284, 291, 303, 241, 201, 222])]
    print(show[["nace3", "coverage", "input_cov", "input_cov_exown"]].round(3).to_string(index=False))


if __name__ == "__main__":
    main()
