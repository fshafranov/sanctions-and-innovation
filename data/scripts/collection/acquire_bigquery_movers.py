"""Russian inventors who reappear abroad, from Google Patents Public Data on BigQuery (20 Nov 2026; note 17).

Question: did internationally active Russian inventors move abroad after 2022? Rospatent cannot show it (emigrants
stop filing in Russia), so this uses patent offices OTHER than Rospatent (Google's RU coverage ends May 2022).
Rules (MV1-MV3 in notes/data_decisions.md)
  MV1 inventors = harmonised inventor name (upper case) with an inventor country code, on publications with filing
      date >= 2008 at any office except RU; one row per family x year x name x country.
  MV2 pool in year y = names with a RU address in y-3..y-1. "Abroad" in y = the pooled name appears with a non-RU
      address on a family filed in y. Destination = that country (a name with several foreign countries in y is
      counted once per country in the destination table). Names are not disambiguated (homonyms count; Latin script,
      no patronymic), so levels are upper bounds and the series is read as a change over time.
  MV3 recent years are incomplete (18-month publication lag): 2024-2025 counts are lower bounds.
Login and project as script 08 (env GCP_PROJECT, OAuth token cached in ~/.pydata_google_auth; nothing in the repo).
Usage: GCP_PROJECT=<id> uv run python -I data/scripts/collection/acquire_bigquery_movers.py [--dry-run]
Output: data/raw/bigquery/movers_by_year.csv (y, pool_n, abroad_n), movers_by_destination.csv (y, cc, n), manifest
"""
import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import pydata_google_auth
from google.cloud import bigquery

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "bigquery"
BASE = """
WITH inv AS (
  SELECT DISTINCT p.family_id, CAST(DIV(p.filing_date, 10000) AS INT64) AS yr, UPPER(TRIM(i.name)) AS nm,
         i.country_code AS cc
  FROM `patents-public-data.patents.publications` p, UNNEST(p.inventor_harmonized) i
  WHERE p.filing_date >= 20080101 AND p.country_code != 'RU' AND i.country_code IS NOT NULL AND i.country_code != ''),
ru AS (SELECT DISTINCT nm, yr FROM inv WHERE cc = 'RU'),
pool AS (SELECT y, nm FROM UNNEST(GENERATE_ARRAY(2012, 2025)) y JOIN ru ON ru.yr BETWEEN y - 3 AND y - 1 GROUP BY y, nm),
ab AS (SELECT DISTINCT nm, yr, cc FROM inv WHERE cc != 'RU')
"""
SQL_YEAR = BASE + """
SELECT pool.y, COUNT(DISTINCT pool.nm) AS pool_n, COUNT(DISTINCT ab.nm) AS abroad_n
FROM pool LEFT JOIN ab ON ab.nm = pool.nm AND ab.yr = pool.y GROUP BY pool.y ORDER BY pool.y"""
SQL_DEST = BASE + """
SELECT pool.y, ab.cc, COUNT(DISTINCT pool.nm) AS n
FROM pool JOIN ab ON ab.nm = pool.nm AND ab.yr = pool.y GROUP BY pool.y, ab.cc ORDER BY pool.y, n DESC"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    creds = pydata_google_auth.get_user_credentials(["https://www.googleapis.com/auth/bigquery"], use_local_webserver=True)
    c = bigquery.Client(project=os.environ["GCP_PROJECT"], credentials=creds)
    OUT.mkdir(parents=True, exist_ok=True)
    man = {"retrieved": datetime.now(timezone.utc).isoformat(), "source": "patents-public-data.patents.publications"}
    for name, sql in (("movers_by_year", SQL_YEAR), ("movers_by_destination", SQL_DEST)):
        j = c.query(sql, job_config=bigquery.QueryJobConfig(dry_run=a.dry_run))
        if a.dry_run:
            print(f"{name}: {j.total_bytes_processed / 1e9:.1f} GB")
            continue
        df = j.result().to_dataframe()
        df.to_csv(OUT / f"{name}.csv", index=False)
        man[name] = {"rows": len(df), "gb_scanned": round(j.total_bytes_processed / 1e9, 2)}
        print(name, f"{j.total_bytes_processed / 1e9:.1f} GB")
        print(df.head(20).to_string(index=False))
    if not a.dry_run:
        (OUT / "manifest_movers.json").write_text(json.dumps(man, indent=1))


if __name__ == "__main__":
    main()
