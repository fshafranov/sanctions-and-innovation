"""2014 dual-use exposure by WIPO field (rule DU1 in notes/data_decisions.md; session 5).
Reg. 833/2014 Art. 2 (from 31 Jul 2014) banned dual-use goods (Annex I of Reg. 428/2009) for military end-use or
military end-users in Russia. The sanctions text has no customs codes for these goods; the Commission's dual-use
correlation table links each control number to the TARIC codes it can be declared under.

Input : data/raw/circabc/2014 - Dual use correlation table 01 Apri 2014.xlsx  (TARIC 10-digit, DU code, control no.;
        downloaded by the user from CIRCABC, Nov 2026)
        data/clean/concord_hsvintage_hs07.csv, ru_imports_hs6.parquet, hs07_field_{industry,text}.csv,
        field_ban_coverage.csv (oil list, for the comparison printout)
Output: data/clean/hs07_dualuse_2014.csv        hs07, share_broad, share_narrow
        data/clean/field_dualuse_2014.csv       map, field, du_broad, du_narrow (share of 2011-13 Western imports)
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW, CLEAN = ROOT / "data" / "raw" / "circabc", ROOT / "data" / "clean"


def main():
    d = pd.read_excel(RAW / "2014 - Dual use correlation table 01 Apri 2014.xlsx", header=None, dtype=str)
    d.columns = ["taric", "du", "ctrl"]
    d = d[d.taric.str.fullmatch(r"\d{10}", na=False)].copy()
    d["hs12"] = d.taric.str[:6]
    d["whole"] = d.taric.str[6:] == "0000"
    broad = set(d.hs12)
    narrow = set(d.loc[d.whole, "hs12"])
    print(f"table: {len(d)} TARIC lines, {d.ctrl.nunique()} control numbers, {len(broad)} HS2012 codes "
          f"({len(narrow)} listed as a whole)")

    c = pd.read_csv(CLEAN / "concord_hsvintage_hs07.csv", dtype=str)
    c = c[c.vintage == "HS2012"].copy()
    c["n_src"] = c.groupby("hs07").src.transform("size")
    c["b"] = c.src.isin(broad)
    c["n"] = c.src.isin(narrow)
    h = c.groupby("hs07").agg(share_broad=("b", "mean"), share_narrow=("n", "mean")).reset_index()
    unmatched = broad - set(c.src)
    print(f"HS2012 codes not in the concordance: {len(unmatched)}")
    h = h[(h.share_broad > 0)]
    h.to_csv(CLEAN / "hs07_dualuse_2014.csv", index=False)

    imp = pd.read_parquet(CLEAN / "ru_imports_hs6.parquet").rename(columns={"hs6": "hs07"})
    W = imp[(imp.group == "west") & imp.year.between(2011, 2013) & imp.hs07.str[:2].astype(int).between(28, 97)] \
        .groupby("hs07").v.mean().rename("W").reset_index()
    tot = W.merge(h, on="hs07", how="left").fillna(0)
    print(f"share of 2011-13 Western manufactured imports: broad {(tot.W * tot.share_broad).sum() / tot.W.sum():.3f}, "
          f"narrow {(tot.W * tot.share_narrow).sum() / tot.W.sum():.3f}")
    out = []
    for mp in ["industry", "text"]:
        w = pd.read_csv(CLEAN / f"hs07_field_{mp}.csv", dtype={"hs07": str})
        x = W.merge(w, on="hs07").merge(h, on="hs07", how="left").fillna({"share_broad": 0, "share_narrow": 0})
        x["den"] = x.w * x.W
        g = x.assign(nb=x.den * x.share_broad, nn=x.den * x.share_narrow).groupby("field")[["nb", "nn", "den"]].sum()
        out.append(pd.DataFrame({"map": mp, "field": g.index, "du_broad": (g.nb / g.den).values,
                                 "du_narrow": (g.nn / g.den).values}))
    f = pd.concat(out)
    f.to_csv(CLEAN / "field_dualuse_2014.csv", index=False)
    cov = pd.read_csv(CLEAN / "field_ban_coverage.csv")
    cov = cov[(cov["sample"] == "manuf") & (((cov.event == "eu2022") & (cov.year == 2023)) | ((cov.event == "oil2014") & (cov.year == 2014)))]
    cv = cov.pivot_table(index=["map", "field"], columns="event", values="coverage").reset_index()
    m = f.merge(cv, on=["map", "field"])
    names = pd.read_csv(CLEAN / "ru_domestic_field_year_imputed.csv").drop_duplicates("field").set_index("field").field_en
    for mp, g in m.groupby("map"):
        print(f"\n{mp}: corr dual-use broad with 2022 coverage {g.du_broad.corr(g.eu2022):.2f}, with oil list "
              f"{g.du_broad.corr(g.oil2014):.2f}; narrow vs broad {g.du_narrow.corr(g.du_broad):.2f}")
        print(g.assign(field_en=g.field.map(names)).sort_values("du_broad", ascending=False)
              [["field_en", "du_broad", "du_narrow", "oil2014", "eu2022"]].round(3).head(8).to_string(index=False))


if __name__ == "__main__":
    main()
