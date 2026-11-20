---
dataset: rospatent_api
collection_type: acquisition
provider: Rospatent search platform API
url: https://searchplatform.rospatent.gov.ru/patsearch/v0.2/search
date_retrieved: 2026-11-19 (grants); 2026-11-20 (applications)
license: TODO
format: json.gz per filing week
years: filings 1994-2026 (grants), 2010-2026 (applications)
geography: Russia
unit: patent document
codebook: patent_search_api.docx (local, not redistributed)
script: data/scripts/collection/acquire_rospatent_api.py; acquire_rospatent_api_apps.py
---

# rospatent_api

## Description

Full records of granted inventions (weeks/) and published applications (weeks_A/).

Checksums: `data/raw/MANIFEST.sha256`.

## Access quirks

Needs the author's API key in env ROSPATENT_TOKEN; one request at a time with a 1 s pause.
