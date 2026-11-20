"""Field-level import exposure and field x year import panel (import-substitution design, notes/09_import_exposure.md).

Input : data/clean/ru_imports_hs6.parquet (15), hs07_field_text.csv and hs07_field_industry.csv (16),
        ru_domestic_field_year_imputed.csv (14; domestic patents by field, for the size measure)
Output: data/clean/field_imports_year.csv  map, sample, field, year, west, china, other (thousand US$)
        data/clean/field_exposure.csv      map, sample, field, period (2014 / 2022), west_share, west_per_patent,
                                            china_share, west_imports (pre-period annual mean)

Rules (E1-E3 in notes/data_decisions.md)
  E1 pre-periods: 2011-13 for the 2014 shock, 2019-21 for 2022; annual means.
  E2 product samples: "manuf" = HS chapters 28-97 (drops food and agriculture 01-24, hit by Russia's own 2014
     counter-embargo on Western food, and minerals/fuels 25-27); "all" = every product.
  E3 exposure = Western share of Russia's imports mapped to the field (main); size variant = Western imports per
     domestic invention patent filed in the pre-period (log).
  E4 realised change in Western, Chinese and total imports, pre-period to 2015-16 (2014) or 2023-24 (2022), log.
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
CLEAN = ROOT / "data" / "clean"
PERIODS = {2014: range(2011, 2014), 2022: range(2019, 2022)}
POST = {2014: range(2015, 2017), 2022: range(2023, 2025)}


def main():
    imp = pd.read_parquet(CLEAN / "ru_imports_hs6.parquet")
    imp = imp.pivot_table(index=["year", "hs6"], columns="group", values="v", aggfunc="sum", fill_value=0)
    imp = imp.reset_index().rename(columns={"hs6": "hs07"})
    for g in ["west", "china", "other"]:
        if g not in imp:
            imp[g] = 0.0
    imp["chapter"] = imp.hs07.str[:2].astype(int)
    pat = pd.read_csv(CLEAN / "ru_domestic_field_year_imputed.csv")

    panels, expo = [], []
    for mname in ["text", "industry"]:
        f = CLEAN / f"hs07_field_{mname}.csv"
        if not f.exists():
            print(f"map {mname}: not built, skipped")
            continue
        mp = pd.read_csv(f, dtype={"hs07": str})
        cover = imp.hs07.isin(mp.hs07)
        print(f"map {mname}: HS07 codes in imports covered {cover.mean():.3f}, "
              f"value covered {imp.loc[cover, ['west', 'china', 'other']].sum().sum() / imp[['west', 'china', 'other']].sum().sum():.3f}")
        for sname, keep in [("manuf", imp.chapter.between(28, 97)), ("all", imp.chapter > 0)]:
            x = imp[keep].merge(mp, on="hs07")
            for g in ["west", "china", "other"]:
                x[g] = x[g] * x.w
            p = x.groupby(["field", "year"])[["west", "china", "other"]].sum().reset_index()
            p.insert(0, "sample", sname)
            p.insert(0, "map", mname)
            panels.append(p)
            for ev, yrs in PERIODS.items():
                q = p[p.year.isin(yrs)].groupby("field")[["west", "china", "other"]].mean()
                tot = q.sum(axis=1)
                pp = pat[pat.year.isin(yrs)].groupby("field").n_top.mean()
                # E4 realised change after the shock (2015-16 for 2014, 2023-24 for 2022), log points; descriptive
                # and a candidate treatment once instrumented by the legal ban lists (not exogenous on its own)
                r = p[p.year.isin(POST[ev])].groupby("field")[["west", "china", "other"]].mean()
                e = pd.DataFrame({"west_share": q.west / tot, "china_share": q.china / tot,
                                  "west_imports": q.west, "west_per_patent": np.log(q.west / pp),
                                  "dlog_west": np.log(r.west / q.west), "dlog_china": np.log(r.china / q.china),
                                  "dlog_total": np.log(r.sum(axis=1) / tot)}).reset_index()
                e.insert(0, "period", ev)
                e.insert(0, "sample", sname)
                e.insert(0, "map", mname)
                expo.append(e)
    panel = pd.concat(panels)
    panel.to_csv(CLEAN / "field_imports_year.csv", index=False)
    ex = pd.concat(expo)
    names = pat.drop_duplicates("field").set_index("field").field_en
    ex["field_en"] = ex.field.map(names)
    ex.to_csv(CLEAN / "field_exposure.csv", index=False)
    show = ex[(ex["sample"] == "manuf") & (ex.period == 2022)].sort_values("west_share", ascending=False)
    print(show[["map", "field_en", "west_share", "china_share", "west_imports"]].round(3).head(36).to_string(index=False))
    w = ex[ex["sample"] == "manuf"].pivot_table(index=["map", "field"], columns="period", values="west_share")
    print("corr of west share 2011-13 vs 2019-21:", w.groupby("map").apply(lambda d: d[2014].corr(d[2022])).round(3).to_dict())


if __name__ == "__main__":
    main()
