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

## Correction (19 Nov 2026, after full API data)
The pooled subclass + year FE coefficient (about -0.10, CI excludes 0) is NOT a clean replication of the field result.
Its PPML event study (fig40, re-run on official IPC for all years) has positive, declining pre-period coefficients
(continuous: 2015 +0.05 -> 2020 +0.01, 2017-2018 significant; above-median: +0.05 to +0.11), so the pooled estimate
mixes a pre-existing downward drift with the 2022 break. Only OLS log(1+n) above-median has a flat pre-period, and it
shows an effect with the industry map (-0.13, -0.15, -0.10 in 2023-25) but not with the product-name map.
Within fields (subclass + field x year FE) there is no break. Status: no credible significant subclass result yet.
Next: ORIV with the two maps (judged on the event study, not the pooled coefficient); IPC class level; fix the
pre-trend by design (finer group x year FE, pre-war characteristics x year), not by detrending.

## ORIV (19 Nov 2026, script 18i, fig49, tables oriv.csv / oriv_es.csv)
Gillen, Snowberg & Yariv (2019): each ban-coverage map instruments the other (stacked data, FE interacted with the
copy, SEs clustered by unit). Linear, outcome log(1 + n_frac), per 10 pp of coverage. PPML: approximate control
function, cluster bootstrap (199 draws). 282 subclasses with both maps; official IPC; 2015-2025, base 2021.

| Level | naive OLS (avg of maps) | ORIV OLS | first-stage F | ORIV-CF PPML |
|---|---|---|---|---|
| 35 fields | -0.059 (p 0.008) | -0.071 [-0.125, -0.017] | 54 | -0.075 [-0.121, -0.029] |
| subclasses, subclass + year FE | -0.019 (p 0.02) | -0.037 [-0.070, -0.005] | 52 | -0.098 [-0.143, -0.054] |
| subclasses within fields | +0.005 | +0.014 [-0.041, +0.068] | 12 | -0.026 [-0.104, +0.052] |

- Fields: little attenuation (maps correlate 0.73), ORIV ~ naive. ORIV event study pre-period joint p 0.03 (OLS log;
  2018 +0.03), post -0.03, -0.07, -0.08, -0.08.
- Subclasses across fields: ORIV doubles the naive OLS estimate and the pre-period is flat (joint p 0.92), but the
  individual post coefficients (-0.02, -0.02, -0.04) are not significant; only the pooled one is (p 0.025).
- Within fields: ORIV does not produce an effect. The OLS ORIV CI excludes an effect as large as the field-level one
  (-0.071 per 10 pp), so attenuation alone does NOT explain the within-field null; the PPML-CF CI is too wide to say.
  Caveats: weak-ish first stage (F 12), ORIV assumes independent map errors (both maps share the HS ban data and the
  product -> technology logic, so errors may be correlated).
- Reading: the effect operates between technology fields; within fields, subclasses with more banned imports do not
  fall more. Consistent with field-level channels (shared labs, inventors, funding, spillovers) or with subclass
  coverage carrying little real information beyond the field.

## Spillovers (19 Nov 2026; scripts 25 and 18j; fig50, fig51; tables spillovers*.csv)
Neighbour exposure N_i = sum_{j != i} w_ij Ban_j, weights from pre-war domestic patents 2010-21 (official IPC):
P1 co-classification (patents listing both units), P2 holder overlap (cosine of holders' patent portfolios); and at the
subclass level "rest of field" (import-weighted coverage of the subclass's WIPO field without the subclass). Own and
neighbour exposure per 10 pp, both in one model. Specification fixed before running (P1 main, P2 mechanism, rest of field check).

Correlation own vs neighbour (industry map): subclasses co-class 0.65, holder 0.40, rest of field 0.55; within fields
co-class 0.37; **fields co-class 0.84 (too collinear to separate)**. Holder-overlap neighbour exposure barely varies
(SD 0.17 vs own 1.62 in 10 pp units): holders patent across many subclasses, so the weights are diffuse; P2 is
uninformative (huge CIs) at both levels.

PPML, industry map, subclass + year FE, per 10 pp (own alone: -0.061):
- co-classification: own -0.032 (p 0.10), neighbour -0.047 (p 0.04)
- rest of field: own -0.029 (p 0.02), rest of field -0.044 (p 0.001); product-name map: own -0.011, rest -0.041 (p < 0.001)
- with field x year FE: nothing (co-class neighbour -0.017, p 0.46)
- fields, co-class: own -0.016, neighbour -0.091 (p 0.03), but corr 0.84, not interpretable separately

Event studies (fig51, PPML, both terms in one model):
- **rest of field: the rest-of-field term is flat before 2022 (joint p 0.79) and drops -0.036, -0.054, -0.055, -0.043
  (all significant); the subclass's own term has a mild positive pre-drift and is ~0 after (-0.01 to -0.02, n.s.).**
  This is the cleanest subclass-level result so far: subclasses respond to their field's exposure, not their own.
- co-classification: own is flat pre (p 1.00) and negative in 2024-25 (-0.044, -0.047, significant); the neighbour term
  drifts down pre-2022 and fades after 2023. Attribution between own and co-class neighbours is not stable.
Reading: "rest of field" is nearly the field's own coverage, so this is the field-level effect estimated at subclass
level, not a separately identified spillover. It restates the within-field null in one model with flat pre-trends:
given the field's exposure, a subclass's own exposure adds little. Whether that reflects spillovers (shared labs,
inventors, funding) or field-level channels cannot be separated with these data; P2 was meant to test it but its
weights are too diffuse. Possible fix: holder overlap restricted to organisations (drop individuals) or to top holders.

## ORIV horse race: own vs neighbour, both noise-corrected (19 Nov 2026; script 18k, fig52, oriv_spillovers*.csv)
Both exposures exist in two map versions; stacked ORIV instruments (own, neighbour) from one map with the other map's
(own, neighbour). 268 subclasses, subclass + year FE, OLS log(1 + n), per 10 pp. Map agreement: own 0.42, rest of
field 0.60, co-class 0.73 (the neighbour terms are indeed less noisy). First stages strong (F 62-225).

| Neighbour | naive OLS (avg of maps): own / neighbour | ORIV both terms: own / neighbour |
|---|---|---|
| rest of field | -0.005 / -0.042 (p 0.005) | -0.001 [-0.060, 0.058] / -0.064 [-0.140, 0.011] (p 0.09) |
| co-classification | +0.008 / -0.066 (p < 0.001) | +0.030 [-0.045, 0.105] / -0.104 [-0.195, -0.014] (p 0.02) |
ORIV own alone: -0.036 (p 0.03).

- Correcting both terms for noise does NOT reverse the horse race: own stays ~0, neighbour stays negative and grows.
  So "neighbour wins only because it is measured with less noise" is not supported (under ORIV's assumption that the
  two maps' errors are independent).
- But precision drops: the rest-of-field ORIV term is only p 0.09 pooled, and its event study (fig52) is noisy: post
  -0.05, -0.11, -0.16, -0.10 (2023-25 significant) but pre coefficients also mostly negative (-0.10 to +0.01; joint
  p 0.33), so the break is much less clean than in the naive version (fig51). Own: ~0 throughout.
