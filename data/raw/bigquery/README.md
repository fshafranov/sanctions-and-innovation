---
dataset: bigquery
collection_type: acquisition
provider: Google Patents Public Data (BigQuery)
url: patents-public-data.patents.publications
date_retrieved: 2026-11-12 (ru_publications); 2026-11-20 (movers)
license: TODO
format: parquet, csv
years: filings 2000+ (RU office data end May 2022)
geography: Rospatent; all offices for movers
unit: publication; inventor-name x year aggregates
codebook: https://console.cloud.google.com/marketplace/product/google_patents_public_datasets/google-patents-public-data
script: data/scripts/collection/acquire_bigquery_ru.py; acquire_bigquery_movers.py
---

# bigquery

## Description

Rospatent publications with IPC and assignees (ru_publications.parquet) and counts of Russian-address inventors appearing abroad (movers_*.csv).

Checksums: `data/raw/MANIFEST.sha256`.

## Access quirks

Needs the user's own Google Cloud project (env GCP_PROJECT) and an OAuth login cached in ~/.pydata_google_auth. Google's RU office coverage ends May 2022.
