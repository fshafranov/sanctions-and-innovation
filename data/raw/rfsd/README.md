---
dataset: rfsd
collection_type: acquisition
provider: RFSD (Hugging Face irlspbru/RFSD v3.1.0)
url: https://huggingface.co/datasets/irlspbru/RFSD
date_retrieved: TODO
license: CC BY 4.0
format: parquet
years: 2011-2025
geography: Russia
unit: firm x year
codebook: RFSD documentation
script: data/scripts/collection/acquire_rfsd.py
---

# rfsd

## Description

Russian firm financial statements, selected columns (rule RF1).

Checksums: `data/raw/MANIFEST.sha256`.

## Access quirks

Full yearly files are downloaded one at a time and deleted after column extraction.
