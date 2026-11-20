---
dataset: rosstat_io
collection_type: provided
provider: Rosstat (via the Wayback Machine)
url: TODO
date_retrieved: TODO
license: TODO
format: xlsx
years: 2011, 2016, 2021
geography: Russia
unit: product x industry
codebook: TODO
script: none (manual download)
---

# rosstat_io

## Description

Rosstat basic input-output tables; the 2021 table is used (rule RU1).

Checksums: `data/raw/MANIFEST.sha256`.

## Access quirks

Live Rosstat links return 404 and its site uses a Russian CA certificate; files were recovered from the Wayback Machine. Ignore the Excel lock file ~$baz_tzv-2021.xlsx.
