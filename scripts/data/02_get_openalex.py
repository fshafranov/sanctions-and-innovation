"""Country-year publication counts from OpenAlex (full counting by institution country).

Source: OpenAlex API, https://api.openalex.org/works, no API key (anonymous, shared daily budget).
Per country (ISO2 from data/raw/wb/wb_countries.csv, aggregates excluded) two group-by queries:
  all:   filter=institutions.country_code:XX,type:article|review,publication_year:1990-2024
  intl:  the same + countries_distinct_count:>1   (at least two distinct author-institution countries)
         group_by=publication_year
Full counting: a paper with authors in Iran and Germany counts once for each country.
Type restricted to journal articles and reviews (drops datasets, paratext, preprints, book chapters);
provisional default, see notes/data_decisions.md (O1).
Output: data/raw/openalex/openalex_country_year.csv (iso2, year, works, works_intl), manifest.json.
Codes OpenAlex rejects (HTTP 400) are skipped and printed.
Resumable: countries already in the output are skipped.
"""
import json
import time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "raw" / "openalex"
OUT.mkdir(parents=True, exist_ok=True)
FILE = OUT / "openalex_country_year.csv"
BASE = "type:article|review,publication_year:1990-2024"


def grouped(filter_):
    for k in range(5):
        r = requests.get("https://api.openalex.org/works",
                         params={"filter": filter_, "group_by": "publication_year", "per_page": 200}, timeout=60)
        if r.status_code == 200:
            return {int(g["key"]): g["count"] for g in r.json()["group_by"]}
        if r.status_code == 429 or r.status_code >= 500:
            print("  status", r.status_code, r.text[:200])
            time.sleep(10 * (k + 1))
            continue
        if r.status_code == 400:  # country code unknown to OpenAlex (e.g. JG Channel Islands)
            return None
        r.raise_for_status()
    raise RuntimeError(f"failed: {filter_}")


def main():
    meta = pd.read_csv(ROOT / "data" / "raw" / "wb" / "wb_countries.csv", keep_default_na=False)
    meta = meta[(meta.region != "Aggregates") & (meta.iso2.str.len() == 2)]
    done = set(pd.read_csv(FILE, keep_default_na=False).iso2) if FILE.exists() else set()
    for iso2 in sorted(set(meta.iso2) - done):
        a = grouped(f"institutions.country_code:{iso2},{BASE}")
        if a is None:
            print(iso2, "not a valid OpenAlex country code, skipped")
            continue
        b = grouped(f"institutions.country_code:{iso2},{BASE},countries_distinct_count:>1")
        rows = pd.DataFrame({"iso2": iso2, "year": sorted(a)})
        rows["works"] = rows.year.map(a)
        rows["works_intl"] = rows.year.map(b).fillna(0).astype(int)
        if rows.empty:
            rows = pd.DataFrame([{"iso2": iso2, "year": None, "works": 0, "works_intl": 0}])
        rows.to_csv(FILE, mode="a", header=not FILE.exists(), index=False)
        print(iso2, int(rows.works.sum()))
        time.sleep(0.3)
    d = pd.read_csv(FILE, keep_default_na=False)
    json.dump({"downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
               "api": "https://api.openalex.org/works", "filter_base": BASE,
               "intl_filter": "countries_distinct_count:>1", "counting": "full (by institution country)",
               "n_countries": int(d.iso2.nunique()), "n_rows": len(d)}, open(OUT / "manifest.json", "w"), indent=2)


if __name__ == "__main__":
    main()
