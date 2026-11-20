"""Russia's imports by HS6 product (HS 2007) x partner group x year, from CEPII BACI (exposure for the import-
substitution design, notes/09_import_exposure.md).

Input : data/raw/baci/BACI_HS07_V202601.zip  (cepii.fr, release Jan 2026; downloaded 12 Nov 2026; one CSV per year
        with t (year), i (exporter), j (importer), k (HS6), v (value, thousand current US$), q (tonnes);
        reconciled from importer and exporter reports, so Russia's imports after 2021 come from partners' reports)
Output: data/clean/ru_imports_hs6.parquet  year, hs6, group, v   (group: west, china, other)

Rules (I1-I2 in notes/data_decisions.md)
  I1 west = the 2022 sanctions coalition, same list as data/scripts/cleaning/clean_rospatent.py (EU27, US, GB, CA,
     JP, KR, TW, SG, AU, NZ, CH, NO, IS, LI). Taiwan is BACI code 490 ("Other Asia, nes"). china = CHN + HKG + MAC.
  I2 Russia = importer code 643. All years in the file are kept.
"""
import io
import re
import zipfile
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
ZIP = ROOT / "data" / "raw" / "baci" / "BACI_HS07_V202601.zip"
OUT = ROOT / "data" / "clean" / "ru_imports_hs6.parquet"

EU27 = "AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE".split()
WEST_ISO2 = set(EU27 + "US GB CA JP KR SG AU NZ CH NO IS LI".split())
RUS = 643


def main():
    z = zipfile.ZipFile(ZIP)
    names = z.namelist()
    cc = pd.read_csv(z.open(next(n for n in names if n.startswith("country_codes"))))
    print(cc.columns.tolist())
    west = set(cc.loc[cc.country_iso2.isin(WEST_ISO2), "country_code"]) | {490}
    china = set(cc.loc[cc.country_iso3.isin(["CHN", "HKG", "MAC"]), "country_code"])
    print(f"west partners: {len(west)}, china codes: {sorted(china)}")

    out = []
    for n in sorted(x for x in names if re.match(r"BACI_HS07_Y\d{4}", x)):
        d = pd.read_csv(z.open(n), dtype={"t": "int16", "i": "int32", "j": "int32", "k": "str", "v": "float64"},
                        usecols=["t", "i", "j", "k", "v"])
        d = d[d.j == RUS]
        d["group"] = "other"
        d.loc[d.i.isin(west), "group"] = "west"
        d.loc[d.i.isin(china), "group"] = "china"
        g = d.groupby(["t", "k", "group"]).v.sum().reset_index()
        out.append(g)
        print(n, len(d), f"total {g.v.sum() / 1e6:.1f} bn US$, west share {g[g.group == 'west'].v.sum() / g.v.sum():.2f}")
    r = pd.concat(out).rename(columns={"t": "year", "k": "hs6"})
    r["hs6"] = r.hs6.str.zfill(6)
    r.to_parquet(OUT, index=False)
    print(r.pivot_table(index="year", columns="group", values="v", aggfunc="sum").div(1e6).round(1))


if __name__ == "__main__":
    main()
