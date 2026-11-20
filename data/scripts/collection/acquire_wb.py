"""Download World Bank WDI indicators (innovation outcomes + population, GDP) for all economies.

Source: World Bank Indicators API v2, https://api.worldbank.org/v2/country/all/indicator/<code>
Selection: all economies (aggregates dropped later via the country metadata), years 1990-2024, JSON.
Output:  data/raw/wb/wb_indicators.csv  (long: iso3, year, indicator, value)
         data/raw/wb/wb_countries.csv   (country metadata: iso3, iso2, name, region, income; region == "Aggregates" marks aggregates)
         data/raw/wb/manifest.json      (download time, row counts per indicator)
Underlying sources: patents = WIPO; articles = NSF (Scopus-based, fractional counts); R&D and researchers =
UNESCO UIS; high-tech exports = UN Comtrade; IP payments = IMF BoP.
"""
import json
import time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "wb"
OUT.mkdir(parents=True, exist_ok=True)

INDICATORS = {
    "IP.PAT.RESD": "Patent applications, residents",
    "IP.PAT.NRES": "Patent applications, nonresidents",
    "IP.JRN.ARTC.SC": "Scientific and technical journal articles",
    "GB.XPD.RSDV.GD.ZS": "R&D expenditure (% of GDP)",
    "SP.POP.SCIE.RD.P6": "Researchers in R&D (per million people)",
    "TX.VAL.TECH.MF.ZS": "High-technology exports (% of manufactured exports)",
    "TX.VAL.TECH.CD": "High-technology exports (current US$)",
    "BM.GSR.ROYL.CD": "Charges for the use of intellectual property, payments (BoP, current US$)",
    "BX.GSR.ROYL.CD": "Charges for the use of intellectual property, receipts (BoP, current US$)",
    "SP.POP.TOTL": "Population, total",
    "NY.GDP.PCAP.KD": "GDP per capita (constant 2015 US$)",
}
YEARS = "1990:2024"


def get(url, params, tries=5):
    for k in range(tries):
        try:
            r = requests.get(url, params=params, timeout=120)
            r.raise_for_status()
            return r.json()
        except Exception as e:  # network hiccups: retry with backoff
            if k == tries - 1:
                raise
            time.sleep(5 * (k + 1))


def main():
    rows, counts = [], {}
    for code, label in INDICATORS.items():
        js = get(f"https://api.worldbank.org/v2/country/all/indicator/{code}",
                 {"format": "json", "per_page": 20000, "date": YEARS})
        assert js[0]["pages"] == 1, f"{code}: more than one page"
        n = 0
        for r in js[1] or []:
            if r["value"] is None or not r["countryiso3code"]:
                continue
            rows.append({"iso3": r["countryiso3code"], "year": int(r["date"]), "indicator": code,
                         "value": float(r["value"])})
            n += 1
        counts[code] = n
        print(f"{code:20s} {n:6d} non-missing  ({label})")
    pd.DataFrame(rows).sort_values(["indicator", "iso3", "year"]).to_csv(OUT / "wb_indicators.csv", index=False)

    js = get("https://api.worldbank.org/v2/country", {"format": "json", "per_page": 400})
    meta = pd.DataFrame([{"iso3": c["id"], "iso2": c["iso2Code"], "name": c["name"],
                          "region": c["region"]["value"], "income": c["incomeLevel"]["value"]} for c in js[1]])
    meta.to_csv(OUT / "wb_countries.csv", index=False)

    json.dump({"downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
               "api": "https://api.worldbank.org/v2", "years": YEARS, "indicators": INDICATORS,
               "non_missing_rows": counts, "n_countries_meta": len(meta)},
              open(OUT / "manifest.json", "w"), indent=2)


if __name__ == "__main__":
    main()
