---
dataset: wb
collection_type: acquisition
provider: World Bank (WDI API v2; WDI bulk file)
url: api.worldbank.org/v2 country/all/indicator/<code>; WDI_CSV.zip
date_retrieved: 2026-11-11 (API); 2026-11-12 (bulk)
license: CC BY 4.0
format: csv, zip
years: 1990-2024
geography: world
unit: country x year
codebook: manifest.json
script: data/scripts/collection/acquire_wb.py
---

# wb

## Description

Patents (resident, non-resident), articles, R&D, high-tech exports, IP flows, population, GDP per capita; WDI bulk file for covariates.

Checksums: `data/raw/MANIFEST.sha256`.

## Access quirks

The WDI bulk zip was downloaded by hand when the API was down (12 Nov 2026).
