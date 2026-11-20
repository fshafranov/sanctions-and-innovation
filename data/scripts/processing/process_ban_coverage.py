"""Ban coverage by technology field: share of a field's pre-period Western imports that the EU export bans cover
(notes/10_ban_coverage.md). Treatment for the import-substitution design, defined by the sender (Kantor-Whalley logic).

Input : data/clean/eu_ban_hs07.csv (18), ru_imports_hs6.parquet (15), hs07_field_{text,industry}.csv (16)
Output: data/clean/field_ban_coverage.csv  map, sample, event, year, field, coverage, coverage_noex
        data/clean/hs07_ban_first.csv      hs07, first ban date (eu2022 list), share at first listing

Rules (C1-C3 in notes/data_decisions.md)
  C1 coverage_{f,y} = sum_hs w(hs,f) * W(hs) * banned(hs,y) / sum_hs w(hs,f) * W(hs), with W = Russia's imports from
     the West in the pre-period (2019-21 for the 2022 list, 2011-13 for the 2014 oil list) and banned(hs,y) = share
     of the HS07 code banned in the last consolidated version dated <= 31 Dec of year y. Main: y = 2023.
  C2 coverage_noex drops HS07 codes banned only through "ex" codes (partial bans).
  C3 samples as E2 (manuf = HS chapters 28-97; all).
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
CLEAN = ROOT / "data" / "clean"
EVENTS = {"eu2022": (range(2019, 2022), [2022, 2023, 2024, 2025, 2026]), "oil2014": (range(2011, 2014), [2014])}


def main():
    ban = pd.read_csv(CLEAN / "eu_ban_hs07.csv", dtype={"hs07": str, "version": str})
    imp = pd.read_parquet(CLEAN / "ru_imports_hs6.parquet").rename(columns={"hs6": "hs07"})
    imp = imp[imp.group == "west"]
    imp["chapter"] = imp.hs07.str[:2].astype(int)

    first = (ban[(ban.list == "eu2022") & (ban.share > 0)].sort_values("version").groupby("hs07")
             .agg(first_ban=("version", "first"), share_first=("share", "first")).reset_index())
    first.to_csv(CLEAN / "hs07_ban_first.csv", index=False)

    out = []
    for lst, (pre, years) in EVENTS.items():
        W = imp[imp.year.isin(pre)].groupby(["hs07", "chapter"]).v.mean().rename("W").reset_index()
        b = ban[ban.list == lst]
        for y in years:
            vers = b.version[b.version <= f"{y}1231"]
            if vers.empty:
                continue
            bv = b[b.version == vers.max()][["hs07", "share", "ex_only"]]
            for mname in ["text", "industry"]:
                mp = pd.read_csv(CLEAN / f"hs07_field_{mname}.csv", dtype={"hs07": str})
                for sname, keep in [("manuf", W.chapter.between(28, 97)), ("all", W.chapter > 0)]:
                    x = W[keep].merge(mp, on="hs07").merge(bv, on="hs07", how="left")
                    x["share"] = x.share.fillna(0)
                    x["share_noex"] = x.share.where(~x.ex_only.fillna(False).astype(bool), 0)
                    x["den"] = x.w * x.W
                    g = x.assign(num=x.den * x.share, num2=x.den * x.share_noex).groupby("field")[
                        ["num", "num2", "den"]].sum()
                    out.append(pd.DataFrame({"map": mname, "sample": sname, "event": lst, "year": y,
                                             "version": vers.max(), "field": g.index,
                                             "coverage": (g.num / g.den).values,
                                             "coverage_noex": (g.num2 / g.den).values}))
    c = pd.concat(out)
    names = pd.read_csv(CLEAN / "ru_domestic_field_year_imputed.csv").drop_duplicates("field").set_index("field").field_en
    c["field_en"] = c.field.map(names)
    c.to_csv(CLEAN / "field_ban_coverage.csv", index=False)

    # share of all Western imports (manufactured) covered, by year
    for lst, (pre, years) in EVENTS.items():
        W = imp[imp.year.isin(pre) & imp.chapter.between(28, 97)].groupby("hs07").v.mean()
        for y in years:
            b = ban[(ban.list == lst) & (ban.version <= f"{y}1231")]
            if b.empty:
                continue
            bv = b[b.version == b.version.max()].set_index("hs07").share
            print(f"{lst} {y}: {100 * (W * bv.reindex(W.index).fillna(0)).sum() / W.sum():.1f}% of pre-period "
                  f"Western manufactured imports covered")
    s = c[(c["sample"] == "manuf") & (c.event == "eu2022") & (c.year == 2023)].pivot(
        index="field_en", columns="map", values="coverage").sort_values("industry", ascending=False)
    print(s.round(2).to_string())
    print("corr text vs industry (2023):", round(s.text.corr(s.industry), 2))
    o = c[(c["sample"] == "manuf") & (c.event == "oil2014")].pivot(index="field_en", columns="map", values="coverage")
    print(o.sort_values("industry", ascending=False).head(6).round(3).to_string())


if __name__ == "__main__":
    main()
