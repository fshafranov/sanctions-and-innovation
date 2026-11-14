# Design A, first run: Russia 2014, country × field × year (12 Nov 2026)

Script: `scripts/analysis/07_field_triple_diff.R`. Data: `scripts/data/06_get_oecd_fields.py`, `07_build_field_panel.py`.
Tables: `output/tables/field_*.csv`. Figures: `fig6_field_eventstudy`, `fig7_field_permutation`, `fig8_field_raw_series`.
Design: `notes/02_theory_and_design.md`. Data choices: F1–F7 in `scripts/data/07_build_field_panel.py`.

## Setup

- **Outcomes**
  - (1) *Domestic*: Russian residents' patent publications at Rospatent by WIPO field (35), from WIPO.
    Publication year is about 18 months after filing. 2005–2021, because WIPO's 2022 figure for Russia is incomplete.
  - (2) *PCT*: PCT applications by Russian inventors by field (OECD), priority year, 2005–2022.
- **Dependence of field k:** share of world PCT applications in field k in 2008–13 from the 2014 senders (GSDB
  cases 1004–1011: US, EU28, Japan, Canada, Australia, New Zealand, Switzerland, Norway, Iceland, Liechtenstein,
  Montenegro, Albania, Ukraine). It ranges from 0.57 (digital communication) to 0.89 (mechanical elements).
  It is low in ICT because China and Korea hold much of that technology. So it measures how much of a field's
  technology lies *outside* the coalition, i.e. how easy it is to substitute.
- **Comparison countries:** 26 (domestic; at least 500 resident publications a year in 2008–13) and 39 (PCT; at least
  100 a year); Ukraine excluded.
- **Fixed effects:** country×year, field×year, country×field.
- **Inference:** SEs clustered by field, and a permutation test (each comparison country as fake "Russia").

## Results

**Pooled post-2014 coefficient** (per SD of dependence):

| Panel | PPML | OLS log(1+y) | Without China (PPML / OLS) | Permutation p (PPML / OLS) |
|---|---|---|---|---|
| Domestic | −0.14 (0.08) | −0.10 (0.03) | −0.09 / −0.10 | 0.30 / 0.44 |
| PCT | −0.09 (0.03) | −0.10 (0.02) | −0.07 / −0.10 | 0.28 / 0.07 |

**The pooled numbers are misleading. The event study shows why (fig6):**
- **Domestic:** the high-dependence fields were already falling relative to the others **before 2014**. PPML goes
  from +0.26 (2005) to −0.24 (2012). OLS is roughly flat until 2008, then falls to −0.10 by 2012. After 2014 the
  coefficients are −0.05 to −0.16, a continuation of that slope with no visible break at 2014.
- **PCT:** the pre-period is *high*, falling from +0.38 (2008) to 0 (2013), and the post-2014 coefficients rise again
  to +0.17–0.19 by 2019–20. Relative to 2013 there is no decline. The negative pooled number only reflects the high
  2005–10 level.
- **Permutation (fig7):** Russia's pooled estimate is within the range of the comparison countries. South Africa,
  Turkey, India, the US and Taiwan have estimates as large or larger. Nothing in Russia's field composition after
  2014 is unusual.
- **Raw series (fig8):** comparison countries' filings grew strongly in both groups of fields (China). Russia's are
  flat in both. In 2021–22 Russia's PCT filings fall in *both* groups, and more in the low-dependence fields.

## Reading

**No evidence** that Russia's patenting shifted away from sender-dependent fields after 2014, beyond trends that
were already under way. Possible reasons:
1. **The 2014 sanctions had little technology bite.** They were sectoral: finance, oil exploration technology, defence.
   Broad export controls on technology came only in 2022, and the field data end in 2021–22.
2. **The dependence measure is weak.** It varies little across fields (0.57–0.89), and "share of world patents" is a
   poor proxy for what Russian inventors actually needed from the senders.
3. **Low power:** one treated country, 35 fields, and noisy annual counts.

Also, a pooled post-dummy does not work when there are pre-trends. Report event studies, or estimate against a
trend.

## Possible next steps

- **Extend to 2022–24** for the episode with real technology bite: Rospatent's open data (domestic applications
  with IPC codes; check coverage), or wait for the next WIPO/OECD releases.
- **Better dependence measures:**
  - (b) imported inputs: Russia's pre-2014 imports from senders of the products used in each field (BACI +
    concordance), or exposure to the 2022 export-control lists (CN/HS codes in EU Annex VII / US Commerce Control
    List);
  - (c) co-invention by field from patent-level data (USPTO PatentsView: Russian inventors' US patents with
    co-inventor countries and CPC classes; free bulk data).
