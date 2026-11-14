# Technology fields for post-2018 Russian patents, imputed from titles

Session 4, 12 Nov 2026. Script `scripts/data/14_title_field_classifier.py`; check figure
`scripts/analysis/13_title_classifier_check.R` → `output/figures/fig25_title_classifier_fields.png`.
Decisions T1–T6 are in `notes/data_decisions.md`.

## Why

The import-substitution and Western-withdrawal designs need **domestic patents by technology field after 2022**.
The Rospatent register has no IPC codes. Google Patents (BigQuery) has IPC codes, but its RU coverage stops around
May 2022. Matched on registration number, the share of register patents with an IPC field is:

| Filing year | 2008–17 | 2018 | 2019 | 2020 | 2021 | 2022+ |
|---|---|---|---|---|---|---|
| Matched to IPC | 97–100% | 90% | 79% | 71% | 39% | ~0% |

Titles, however, are in the register for 99% of patents in every year 2010–2026.

## What was done

- **Labels:** 581k patents filed 2000–2021 with both a title and IPC. Their IPC codes are mapped to the 35 WIPO
  fields (rule D1).
- **Model:** TF-IDF of the lower-cased Russian title (word 1–2-grams plus character 3–5-grams) fed into a
  multinomial logistic regression (scikit-learn, SGD). It runs locally in about 10 minutes and costs no API tokens.
- **Prediction:** each patent gets a probability for each of the 35 fields.
  - Labelled patents filed 2000–2021 get **out-of-fold** predictions (5-fold cross-fitting), so the overlap years
    are a fair test.
  - The remaining patents are predicted by a model trained on all labelled patents.
- **Counting:** each patent is counted once, in its **top predicted field** (`n_top`). Summing the probabilities
  instead (`n_prob`) shrinks within-field changes toward the average field, which would bias event studies toward
  zero (see below).

## Validation

| Test | Result |
|---|---|
| Random 10% of 2005–17 held out: top-1 / top-3 field correct (any of the patent's true fields) | **84% / 96%** |
| Out of time: trained on filings ≤ 2017, tested on 2018–21 patents with IPC | **81% / 95%** |
| Field shares by year, predicted vs IPC (out of time, 2018–21): correlation / mean absolute error | 0.994–0.998 / 0.12–0.19 pp |
| **Within-field changes after field and year FE, 2010–20 (what an event study uses), out-of-fold `n_top` vs IPC** | **corr 0.91, slope 0.93** |
| Same with summed probabilities (`n_prob`) | corr 0.88, slope **0.55** (attenuated, not used) |

**Weak fields:** out-of-time recall is below 0.5 for IT methods for management (0.16), micro/nano-technology
(0.20), control (0.33), surface technology (0.44), textile and paper machines (0.47), semiconductors (0.49),
environmental technology (0.49) and analysis of biological materials (0.50). The median field is 0.57.
- In fig25, most of these fields have a stable level gap, which field FE absorb.
- **IT methods for management** misses the 2016–19 rise.
- **Measurement** and **materials** have level gaps.
- Robustness rule: drop fields with recall < 0.5 from the event study, or downweight them.

**Caveats**
1. The 2018–21 patents that have IPC are the faster-granted ones, so the out-of-time test sample is selected.
2. Titles are written for the patent office. If title wording changed after 2022 (e.g. "импортозамещ…"
   vocabulary), the classifier still predicts from words learnt before 2022, so a field shift could be partly
   missed. That would be attenuation, not a spurious effect.
3. Filings from 2025–26 are incomplete because of the grant lag. 2024 is close to complete; check against the
   register's growth.

## Outputs

- `data/clean/rospatent_field_probs.parquet`: one row per patent (686k, filed 2000+), with predicted
  probabilities, top field and true IPC fields where known.
- `data/clean/ru_domestic_field_year_imputed.csv`: field × filing year, domestic non-mass-filer inventions;
  `n_top` (main), `n_prob`, `n_obs` (IPC), `n_hybrid` (IPC where matched, else predicted).
- `data/clean/ru_domestic_region_field_year_imputed.csv`: region × field × year (`n_top`, `n_hybrid`).

## First look (descriptive only, fig25)

From 2022 to 2024 domestic patenting rises in medical technology, biotechnology, pharmaceuticals (2023), digital
communication and computer technology (2024). Engines/pumps/turbines and environmental technology keep falling,
and semiconductors stay low. None of this is tested yet.

## Next

The import-substitution event study: field × year, exposure = pre-period Western import share by field (BACI,
HS→IPC via the ALP concordance) and/or the 2022 export-control lists (CHPL, EU dual-use annex). Use field and year
FE with PPML. Show results with and without the weak fields.
