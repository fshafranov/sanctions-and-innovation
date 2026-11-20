---
dataset: eu_sanctions
collection_type: provided
provider: EU Publications Office (CELLAR API)
url: publications.europa.eu/resource/celex/<CELEX> (Accept: application/xhtml+xml); versions listed via its SPARQL endpoint
date_retrieved: 2026-11-12
license: TODO
format: xhtml
years: 35 consolidated versions 2014-09-12 to 2026-07-24
geography: EU
unit: consolidated version of Council Regulation (EU) No 833/2014
codebook: Reg. 833/2014 annexes
script: none (downloaded in session 4; no acquire script yet)
---

# eu_sanctions

## Description

Every consolidated version of Reg. 833/2014; parsed by clean_eu_sanctions.py (rules B1-B5).

Checksums: `data/raw/MANIFEST.sha256`.

## Access quirks

EUR-Lex pages answer scripted requests with a bot check; the CELLAR API does not.
