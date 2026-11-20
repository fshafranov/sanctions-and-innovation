---
dataset: openalex
collection_type: acquisition
provider: OpenAlex
url: https://api.openalex.org
date_retrieved: 2026-11-11 (country-year); 2026-11-12 (regions); 2026-11-20 (authors trial)
license: CC0 (OpenAlex data)
format: csv, json.gz
years: 1990-2025
geography: world; Russian institutions
unit: country x year; region x year; author
codebook: https://docs.openalex.org
script: data/scripts/collection/acquire_openalex.py; acquire_openalex_regions.py; acquire_openalex_authors.py
---

# openalex

## Description

Article counts by country and by Russian region; author affiliation histories (random 10,000 trial).

Checksums: `data/raw/MANIFEST.sha256`.

## Access quirks

Anonymous API, no key and no email sent (author's choice); cursor paging over institutions needs a key since 2026.
