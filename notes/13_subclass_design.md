# IPC subclass design: more treatment units (session 5, 18–19 Nov 2026)

Scripts: `scripts/data/14b_title_subclass_classifier.py` (classifier, SC1–SC4), `19b_subclass_ban_coverage.py`
(maps, coverage), `scripts/analysis/17_patents_subclass.R` (estimates). Tables `output/tables/patents_subclass*.csv`,
fig37. All exploratory (not pre-registered).

## Why

The field design has 35 treatment units. At the IPC subclass level the same ban-coverage treatment varies across
several hundred technologies, and field × year FE become possible: subclasses are compared only with other
subclasses in the same WIPO field. That removes the between-field drift (life sciences vs machinery) behind the
field-level pre-trend.

## Outcome: subclass from titles

- Labels: official IPC subclasses (Rospatent examiners' codes, via Google Patents) of 581,932 patents filed
  2000–2021. 458 subclasses with ≥ 200 labelled patents kept (99.1% of labelled patents have one).
- **Out of time** (train ≤ 2017, test 2018–21, n = 65,315): **top-1 70.0%, top-5 89.7%**.
- **Within-subclass changes**, out-of-fold predicted vs IPC counts, subclass and year FE, 2010–20 (204
  subclasses with ≥ 20 patents/yr): corr 0.77, slope 0.88. Fields: 0.91 / 0.93.
- 3-fold cross-fitting; runtime about 30 minutes.

## Treatment: subclass ban coverage

- Industry map: HS → ISIC → NACE → IPC subclass, Dorner–Harhoff IPC4 tables (fractional), 2-digit fallback (M3).
  6,690 HS codes, 606 subclasses.
- Product-name map: subclass classifier on TN VED product names; top 10 subclasses per product, renormalised.
  4,960 HS codes, 423 subclasses.
- Coverage end-2023: industry mean 0.52 (SD 0.19), text 0.55 (SD 0.34). **The two maps agree poorly at this level:
  correlation 0.38** (0.62 at the field level). Within-field differences in coverage are noisier still.
- Sample rule (fixed before estimation): subclasses with ≥ 10 domestic patents/yr on average in 2015–21 → 235
  subclasses (233 with industry coverage, 229 with text coverage).

## Results

PPML, Ban_s z-scored, Post = 2022+, 2015–2025. SEs clustered by subclass; the conservative variant clusters by WIPO
field. RI permutes Ban_s across subclasses within field (1,000 draws).

| Specification | Industry map | Product-name map |
|---|---|---|
| subclass + year FE | −0.090 [−0.132, −0.048] | −0.070 [−0.114, −0.026] |
| subclass + sector × year FE | −0.090 [−0.128, −0.052] | −0.062 [−0.104, −0.019] |
| **subclass + field × year FE** | **−0.057 [−0.099, −0.015]**, field-clustered [−0.108, −0.006], RI p = 0.034 | −0.007 [−0.050, +0.036], RI p = 0.76 |
| field × year FE, 2019–25 | −0.039 [−0.081, +0.003] | +0.021 [−0.024, +0.066] |
| field × year FE, no "ex" codes | −0.043 [−0.086, +0.001] | −0.001 [−0.045, +0.042] |

**Event study (fig37), base 2021**
- *Subclass + year FE* (comparison across all subclasses, as in the field design): pre +0.05 → +0.01, 2017–18
  exclude 0. Post −0.03, −0.07, −0.06, −0.07 (industry map; all exclude 0). This **replicates the field-level
  result with 233 units**.
- *Subclass + field × year FE* (within field): pre-period +0.06 to +0.09 in 2016–19 (excluding 0). Then a drop
  to 2021, and post +0.04, +0.01, +0.02, −0.05, all including 0. Product-name map: post coefficients positive.
  **There is no break at 2022 within fields.** The pooled within-field β < 0 comes from a decline in 2020–21,
  *before* the war.

**Holder types within fields (field × year × holder FE):** industry map: firms −0.075 [−0.145, −0.004],
individuals −0.069, research −0.037, universities −0.048 (last three include 0). Product-name map: all include 0.
The field-level gap between public research and firms does not survive within fields.

## Reading

1. **The field-level decline is a between-field result.** Fields that were banned more lost patents relative to
   fields banned less. Within a field, more-banned subclasses did not lose more after 2022.
2. **Two ways to read this.**
   - (a) The shock works at the level of broad technologies: inputs, equipment, people and funding move between
     fields, not between neighbouring subclasses.
   - (b) The field-level effect partly reflects field-level trends correlated with coverage (the life sciences vs
     machinery drift), which within-field comparisons remove.
   - The pre-2022 within-field drift and the absence of a 2022 break favour caution about (a).
3. **Measurement error is large at this level** and biases within-field estimates toward zero: subclass
   prediction (70% top-1), and the maps' subclass-level agreement of 0.38. A within-field null is therefore a
   weak null.
4. **Possible artefact at 2020–21:** labelled patents (≤ 2021) get cross-fit predictions, unlabelled ones (61% of
   2021, all 2022+) the final model. At the subclass level the two models may differ enough to shift levels around
   2021. Check: re-estimate with base year 2019, and predict all patents with the cross-fit models only.
   **Official IPC for 2022+ (Rospatent platform export or API) would settle this.**
5. Still no sign of substitution: no specification gives a positive and significant post-2022 coefficient.
