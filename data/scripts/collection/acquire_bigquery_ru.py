"""Russian patent documents (Rospatent, country_code RU) from Google Patents Public Data on BigQuery.

Purpose (Design D, notes/04_regional_design.md §4b): IPC classes and holder names for Russian inventions and utility
models, because the Rospatent open register has addresses but no IPC. Trial run: what is covered, from which years,
with which kind codes, and how often holder names and IPC are filled in.

Source: `patents-public-data.patents.publications` (Google, public dataset; queried through the user's own Google
Cloud project in the free BigQuery sandbox). One row per publication (an application publication and a grant of the
same application are separate rows; link them by application_number).

Columns kept: publication/application number, kind code, family id, filing/publication/grant/priority dates
(YYYYMMDD integers, 0 = missing), IPC codes, harmonised assignee names + countries, inventor countries.
No addresses exist in this table.

Usage:
  GCP_PROJECT=<your-project-id> uv run python data/scripts/collection/acquire_bigquery_ru.py --dry-run   # bytes scanned only
  GCP_PROJECT=<your-project-id> uv run python data/scripts/collection/acquire_bigquery_ru.py             # download
Login: a browser window opens once (Google OAuth via pydata-google-auth); the token is cached in
~/.pydata_google_auth. Nothing is stored in this repo.

Output: data/raw/bigquery/ru_publications.parquet, manifest.json
"""
import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import pydata_google_auth
from google.cloud import bigquery

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "raw" / "bigquery"
SCOPES = ["https://www.googleapis.com/auth/bigquery"]
MIN_FILING = 20000101  # filing date from 2000 on; pre-period for 2014 and 2022 with room for leads

SQL = f"""
SELECT
  publication_number,
  application_number,
  kind_code,
  application_kind,
  family_id,
  filing_date,
  publication_date,
  grant_date,
  priority_date,
  ARRAY(SELECT i.code FROM UNNEST(ipc) AS i) AS ipc,
  ARRAY(SELECT AS STRUCT a.name, a.country_code FROM UNNEST(assignee_harmonized) AS a) AS assignees,
  ARRAY(SELECT v.country_code FROM UNNEST(inventor_harmonized) AS v) AS inventor_countries
FROM `patents-public-data.patents.publications`
WHERE country_code = 'RU'
  AND filing_date >= {MIN_FILING}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="report bytes scanned, download nothing")
    args = ap.parse_args()

    project = os.environ["GCP_PROJECT"]
    creds = pydata_google_auth.get_user_credentials(SCOPES, auth_local_webserver=True)
    client = bigquery.Client(project=project, credentials=creds)

    dry = client.query(SQL, job_config=bigquery.QueryJobConfig(dry_run=True, use_query_cache=False))
    gb = dry.total_bytes_processed / 1e9
    print(f"query would scan {gb:.1f} GB (sandbox free quota: 1,000 GB per month)")
    if args.dry_run:
        return

    df = client.query(SQL).to_dataframe()
    OUT.mkdir(parents=True, exist_ok=True)
    df.to_parquet(OUT / "ru_publications.parquet", index=False)
    json.dump({"downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
               "source": "bigquery: patents-public-data.patents.publications",
               "sql": SQL.strip(), "gb_scanned": round(gb, 2), "rows": len(df)},
              open(OUT / "manifest.json", "w"), indent=2)
    print(f"{len(df)} rows -> {OUT / 'ru_publications.parquet'}")


if __name__ == "__main__":
    main()
