# Design D, first results with the data in hand (12 Nov 2026)

Design: `notes/04_regional_design.md`. Data choices: D1–D4, R1–R4 in `notes/data_decisions.md`.
Two pieces, because the data in hand do not yet give patents by region:
1. **Patents by field and document type, Russia 2014** (Google Patents via BigQuery; national, no regions).
2. **Publications by region, Russia 2022** (OpenAlex; the only regional series after 2022 we have so far).

Status: exploratory. Intervals are 95%; "suggestive" = pattern with intervals that only partly exclude zero or with
pre-trends.

## 1. Patents by field and type around 2014

Scripts: `scripts/data/08_get_bigquery_ru.py`, `10_build_ru_patent_fields.py`, `scripts/analysis/08_ru_patents_types.R`.
Figures: `fig9_ru_types_eventstudy`, `fig10_ru_targeted_shares`. Tables: `output/tables/ru_types_*.csv`,
`ru_targeted_shares.csv`.

**Data facts first**
- Google's Rospatent data end in May 2022; inventions are complete for filings to about 2017, utility models to 2019.
- **One person held ~14% of Russian invention grants**: O.I. Kvasenkov, ~29,000 canning-recipe patents
  (2005–15). With him, "food chemistry" is 15–22% of domestic grants and jumps around by year. He and three other
  individual mass filers are dropped (D2). Any Russian patent count by field before ~2016 that keeps him is
  distorted, which may also matter for the WIPO data in Design A (not checked).
- Applications (kind A) fall from 27,500 (2013) to 6,000 (2017) because fast grants skip the A publication, not
  because filing fell. Not usable as a filing count.

**Event study by sender dependence of the field** (dependence from Design A; field and year FE; base 2013)

| | pre-2014 | after 2014 |
|---|---|---|
| Domestic inventions, OLS log(1+n) | flat: +0.00 to +0.05, all intervals include 0 | −0.06 (2014), −0.04, −0.09, **−0.13 (2017, −0.22 to −0.04)** |
| Domestic inventions, PPML | flat | −0.03 to −0.07, all intervals include 0 |
| Utility models, PPML | **rising**: −0.08 (2010) to 0 (2013) | +0.04, +0.01, **+0.10 (2016, +0.03 to +0.16)**, +0.05, +0.02, +0.05 |
| Utility models relative to inventions (triple difference) | −0.08 (2011), −0.11 (2012, excl. 0) | +0.10 (2014), −0.02, **+0.16 (2016)**, **+0.13 (2017)**; pooled +0.11 (0.04) |

Per SD of dependence. Truncation does not explain the invention decline: dependent fields are granted *faster*
(correlation of median grant lag with dependence −0.44), so truncation would bias them upwards.

**Reading (suggestive):** after 2014, domestic *inventions* moved away from fields where the frontier sits in the
sender countries, by about 4–13% per SD in OLS (PPML smaller and not distinguishable from zero). *Utility models*
moved towards those fields, but they were already trending that way from 2010. The utility-model-relative-to-
invention contrast is the most consistent with "incremental substitution" (adapting what can no longer be
imported, at the low end), but the 2011–12 pre-coefficients mean part of it is trend. No regional dimension yet.

**Targeted fields (fig10):** E21B (oil and gas drilling, the 2014 export-control target): no rise in the domestic
share (3.2% in 2013, 3.6% in 2014, 2.9–3.0% in 2016–18); the foreign holders' share falls from 2.6% (2013) to 1.3%
(2018), i.e. foreign firms withdrew, Russian inventors did not fill the gap in patents. Food chemistry (Russia's
August 2014 food import ban): after dropping mass filers the domestic share is stable at 3.9–4.4% (2012–16), so no
visible substitution response in patents either.

## 2. Regions and publications around 2022

Scripts: `scripts/data/09_get_openalex_regions.py`, `scripts/analysis/09_regions_openalex.R`.
Figures: `fig11_regions_eventstudy` (all articles), `fig11_regions_eventstudy_small` (teams ≤ 50 authors).
Tables: `output/tables/regions_*.csv`.

- 69 regions with ≥ 200 articles a year in 2019–21. Exposure = 2019–21 share of articles with a co-author in the 2022
  coalition: 0.8–64% for all articles, **0.8–37% for teams ≤ 50 authors**.
- **Mega-collaborations dominate the all-articles version.** Leningrad Oblast (PNPI), Moscow Oblast (JINR Dubna,
  Protvino) and Tomsk have the highest exposure. With all articles, exposed regions also lose China co-authorship
  (−2.6 pp per SD from 2023), but this disappears with teams ≤ 50 authors: the papers with both Western and Chinese
  co-authors are CERN-type collaborations that ended together. The small-team version is the main one (R4).

**Small teams, event study per SD of exposure (region and year FE, base 2021)**

| Outcome | pre-2022 | after 2022 |
|---|---|---|
| Coalition co-authored share, pp | +0.5, +0.6, −0.1 (2018–20, include 0) | **−1.8, −3.1, −3.8, −4.3** (2022–25, all exclude 0) |
| China co-authored share, pp | rising: −0.5 (2015), −0.4 (2018), −0.1 (2020) | −0.0, −0.2, −0.1, +0.1 (include 0): the pre-2022 rise stops |
| log articles | **falling**: +0.14 (2018), +0.09, +0.05 | +0.01, +0.05, +0.07, +0.04 |
| Capacity interaction (exposure × large science base) | — | log articles −0.07 in 2025 (−0.13 to −0.01); no difference in co-authorship |

**Reading**
- The knowledge link was cut, and much more where it had been strong: about 4 pp per SD by 2025 (mean exposure
  ~10%). This is a first stage, partly mechanical (more to lose).
- **No sign that exposed regions published less.** Their relative output was falling *before* 2022 and stopped
  falling afterwards. The pooled post-2022 coefficient (−0.08, permutation p < 0.01) only reflects the pre-2022
  level difference and should not be read (pre-trend; user rule: event studies, not pooled numbers).
- **No partner substitution towards China** in exposed regions, and no difference by size of the science base
  (one 2025 coefficient). So far no regional "substitution here, decline there" pattern in science.
- Limits: publications are not technology; OpenAlex indexing of Russian journals changes over time; region names
  are OpenAlex's, not official codes; capacity = output size is crude.

## 3. What this says about the user's hypothesis

- National patents (2014): a shift from inventions towards utility models in dependent fields fits incremental
  substitution, but partly trend. It says nothing yet about *where*.
- Regions (2022, science): exposure cut ties, not output, and no reorientation to China. Science may simply not be
  where substitution shows up; the test needs patents by region.
- **The decisive data is the Rospatent register (701 MB, not 30 GB).** With it: domestic inventions by region ×
  field × year 2010–2026 from postal codes, IPC for pre-2018 filings from BigQuery (matched on patent number),
  and the 2×2 of exposure × capacity on patents. Utility-model and software registers next (sizes still unknown).

## 4. Next steps

1. Download the invention register (user; resumable curl, at the server's speed probably 15 h – 4 days).
2. Postal code → region crosswalk (Russian Post index ranges; official region codes; also fixes OpenAlex names).
3. Regional exposure for patents: Western-firm plants (KSE list located via RFSD) or industry-mix shift-share.
4. Check whether Kvasenkov-type mass filers distort the WIPO field data used in Design A.
