# Main tests with official IPC codes (session 5, 19 Nov 2026)

Data: Rospatent search platform API (script 21b; user's key) for filings from Feb 2020 onward, Google Patents
before (both are Rospatent examiners' codes). The collection 2015–2020 and 1994–2014 was still running; for
2015–2019 Google already covers 98–100% of domestic inventions. Panels: `23_build_official_ipc_panels.py`
(fractional counts over distinct fields/subclasses, `n_frac`, main; first-listed code `n_first`). Estimates:
`scripts/analysis/18_patents_official.R` (fig38), descriptive `18b_official_raw_series.R` (fig39). Logs:
`data/logs/22_parse_api.log`, `23_official_panels.log`, `18_patents_official_R.log`.

## Data checks

- Share of domestic inventions with official codes: 96–100% in every year 2010–2026 (2014: 95.6%).
- **Google vs API:** 24,309 patents in both; **99.8% share a subclass.**
- **Title classifier vs official codes, 2019–2026 (n = 116,078):** top subclass among official subclasses
  70.7% (2019), 72.1, 71.7, **71.9 (2022), 71.5, 71.3, 70.5 (2025)**, 68.5 (2026, partial). No drop after 2022,
  so the predicted series used in notes 11 and 13 had no post-war drift in accuracy.

## Field level (35 fields), pre-registered specification

| Specification | Industry map | Product-name map |
|---|---|---|
| **field + year FE, n_frac** | **−0.095 [−0.148, −0.042], RI p = 0.002** | −0.094 [−0.149, −0.039] |
| field + sector × year FE | −0.097 [−0.156, −0.038] | −0.100 [−0.162, −0.038] |
| window 2019–2025 | −0.079 [−0.106, −0.052] | −0.084 [−0.115, −0.053] |
| field + year FE, n_first | −0.097 [−0.203, +0.009] | −0.098 [−0.197, +0.001] |
| (predicted fields, n_top, same spec) | −0.099 [−0.151, −0.047] | |

**Event study (fig38, industry map, base 2021):**
- Pre: +0.039 [−0.052, 0.131] (2015), +0.023, +0.020, +0.023 [−0.014, 0.060] (2018), −0.002, −0.003 (2020).
  **All pre-period coefficients include zero**, and they are smaller than with predicted fields (+0.03 to +0.05).
  2019–2020 are essentially zero.
- Post: **−0.045, −0.094, −0.091, −0.089** (2022–2025), all excluding zero.
- Product-name map: same pattern (pre +0.005 to +0.033, all include 0; post −0.041 to −0.089).
- **This passes the flat-pre-period standard,** with a small residual downward slope in 2015–18 point estimates.

**Holder types (field × holder FE, holder × year FE):** firms −0.039 [−0.107, +0.029]; universities −0.102
[−0.148, −0.056]; research institutes −0.125 [−0.199, −0.051]; individuals −0.124 [−0.207, −0.041]. Public
(universities + institutes) minus firms −0.074 (SE 0.027, p = 0.007).

## Subclass level (official codes; ≥ 10 patents/yr in 2015–21: 279 subclasses industry map, 270 text map)

| Specification | Industry map | Product-name map |
|---|---|---|
| subclass + year FE | −0.098 [−0.130, −0.066] | −0.083 [−0.127, −0.038] |
| subclass + field × year FE | −0.041 [−0.082, +0.001] | +0.001 [−0.038, +0.041] |

Within-field event study (industry map): pre +0.03 to +0.06 (2018 and 2019 exclude 0), post +0.032, −0.003,
−0.006, −0.027 (all include 0). **The within-field pattern of note 13 is confirmed with official codes, so it
was not a classifier artefact.** Across subclasses the decline holds with 279 units. Within fields there is no
2022 break.

## Raw series (fig39; fields in terciles of coverage, 2021 = 100)

- All domestic, 2021 → 2023 → 2024: low-coverage fields 100 → 124 → 125; high-coverage 100 → 97 → 99 (2025:
  88, incomplete year).
- **The relative decline is mostly a rise in low-coverage fields (pharma, medical, biotech).** High-coverage
  fields are roughly flat in levels until 2024.
- Universities drive the rise: low-coverage 100 → 141 (2023); high-coverage 100 → 109 → 107.
- Research institutes: high-coverage fields decline steadily from 2012 (145 → 100 by 2021 → 83 in 2025). That is
  a long pre-trend in levels, which the field FE and year FE partly absorb.
- Firms: all terciles fall in 2022 and recover by 2024; high-coverage firms recover less (96 vs 119–122).

## Reading

1. **The field-level result is robust to official codes and now has a flat pre-period:** −9.5% per SD of ban
   coverage, permutation p = 0.002, event study flat 2015–2020, step down from 2022.
2. **"Decline in banned fields" is relative.** In levels it is mainly growth in the least-banned fields (life
   sciences), led by universities, plus a mild fall in the most-banned fields from 2025. Write it this way.
3. Still **no substitution** into banned fields in any specification.
4. Within fields, there is no break. Either the shock works at the level of broad technologies, or part of the
   field-level gap comes from field-level trends (e.g. state priority for pharma/medical localisation after 2022,
   which would raise low-coverage fields for reasons other than the bans). The second reading matters for
   interpretation and needs a test, e.g. controls for state R&D priorities or procurement by field.
5. Next (after the full download): ORIV with the two maps, technology-space spillovers, text-based exposure
   (discussed 19 Nov; user wants to discuss methods once the data are complete).

## Simple TWFE variants at subclass level (script 18c, fig40)

Official IPC, 279 subclasses (industry map; 270 product-name map), subclass FE + year FE (or sector × year FE),
2015–2025. Industry map; 95% CIs clustered by subclass (field-clustered CIs very similar).

| Specification | year FE | sector × year FE |
|---|---|---|
| PPML, continuous (per SD) | −0.098 [−0.130, −0.066] | −0.091 [−0.125, −0.058] |
| OLS log(1+n), continuous | −0.047 [−0.081, −0.014] | −0.034 [−0.068, +0.001] |
| OLS asinh(n), continuous | −0.048 [−0.083, −0.013] | −0.033 [−0.070, +0.003] |
| PPML, above-median coverage | −0.189 [−0.258, −0.121] | −0.165 [−0.236, −0.093] |
| OLS log(1+n), above-median | −0.100 [−0.161, −0.039] | −0.079 [−0.146, −0.011] |
| PPML, top vs bottom tercile | −0.209 [−0.291, −0.126] | −0.172 [−0.260, −0.085] |
| PPML, dose: coverage at end of each year, per 10 pp | −0.060 [−0.079, −0.042] | −0.056 [−0.076, −0.036] |
| PPML TWFE, staggered (coverage ≥ 50%) | −0.182 [−0.256, −0.107] | −0.146 [−0.215, −0.077] |
| **PPML Sun–Abraham ATT (coverage ≥ 50%)** | **−0.111 [−0.167, −0.056]** | |

Product-name map: same signs, mostly smaller (PPML continuous −0.083; above-median −0.127; Sun–Abraham −0.098
[−0.154, −0.043]; the OLS-log versions include zero).

Staggered cohorts (industry map, first year coverage ≥ 50%): 2022: 12 subclasses, 2023: 163, 2024: 30, 2025: 35,
2026: 1, never: 38.

**Event studies (fig40, base 2021):**
- **OLS log(1+n), above-median:** pre-period +0.03, −0.03, +0.03, +0.02, +0.01, +0.01 (2015–20), **all include
  zero and are flat**. Post +0.003 (2022), **−0.117, −0.144** (2023–24, exclude zero), −0.093 (2025, incomplete).
  This is the cleanest picture: no pre-trend, a break from 2023.
- PPML above-median: pre +0.04 to +0.10 (2018 excludes zero), post −0.05, −0.16, −0.17, −0.15.
- PPML continuous: pre declining +0.05 → +0.01 (2017–18 exclude zero), post −0.03, −0.08, −0.08, −0.09.

**Reading**
- Across subclasses, every TWFE variant gives a decline: about −5% to −10% per SD of coverage, and −10% to −19%
  for above-median subclasses. The heterogeneity-robust staggered estimate is −11%.
- PPML estimates are roughly twice the OLS-log ones. PPML weights by size, so **the decline is larger in big
  subclasses**; OLS-log gives each subclass equal weight.
- The pre-trend is a PPML feature (driven by large subclasses). With equal weights (OLS log, binary) the
  pre-period is flat. That is a strong figure for the paper next to the field-level PPML event study.

## Pre-trend tests for the continuous design (script 18e, fig43–44)

Official IPC, 35 fields, PPML, field + year FE, Ban_f z-scored. Industry map (product-name map in brackets).

| Test | Result |
|---|---|
| Joint Wald test: all 2015–2020 event-study coefficients = 0 | F = 2.24, **p = 0.039** [text map: p = 0.001] |
| Linear pre-trend, Ban_f × (year − 2021), 2015–2021 only | −0.007 per SD per year (SE 0.008), p = 0.41 [p = 0.66] |
| Placebo date: Ban_f × Post-2018, 2015–2021 only | −0.023 (SE 0.031), p = 0.46 [p = 0.75] |
| Placebo scatter: change 2015–17 → 2019–21 on coverage (size-weighted) | −0.032 per SD (SE 0.021), p = 0.15 |
| Actual: change 2019–21 → 2023–24 on coverage | −0.091 per SD (SE 0.015), p < 0.001 |

Dose bins (fig44): quarters of fields by coverage vs the lowest quarter. Pre-period: no coefficient excludes zero
except Q4 2018 (+0.112 [−0.001, 0.225], borderline). Post (2023): Q2 −0.13, Q3 −0.24, Q4 −0.26; **monotonic in
dose**.

**Reading:**
- No single pre-period coefficient is significant, and neither a linear trend nor a placebo break is. But the joint
  test rejects at 5%: the six pre-coefficients are jointly not zero (+0.02 to +0.04 in 2015–18, ~0 in 2019–20).
- With 35 clusters and 6 restrictions, cluster-robust Wald tests tend to over-reject. A wild-cluster bootstrap or
  RI version of the joint test is the right check.
- Size: whatever pre-drift there is is about a third of the post-2022 change (placebo slope −0.03 vs −0.09) and
  not statistically distinguishable from zero in the slope tests.
- Next: HonestDiD bounds (Rambachan–Roth) with M calibrated to the largest pre-period change, and a wild-bootstrap
  joint pre-test.

## Raw lines (script 18f, fig45–46; no regression)

Quarters of fields by coverage, official IPC, 2010–2025, index 2019–21 = 100.
- Q1 (lowest coverage, 8–43%): ~95–115 through 2021, then 101 (2022), **121, 123** (2023–24).
- Q4 (highest, 59–67%): ~94–107 through 2021, then 89, 92, 97 (2022–24).
- **Raw gap Q4 − Q1** (log, 2019–21 = 0): moves within about ±0.10 in 2010–2021 (2014 +0.11; 2017–18 +0.09/+0.10;
  2010 −0.10), then **−0.13, −0.27, −0.24, −0.25** (2022–25). The post-2022 gap is about 2.5 times the largest
  pre-period swing.
- **Q2 and Q3 vs Q1 show a long pre-trend:** their gap falls steadily from about +0.15 (2010–14) to 0 by 2019, then
  keeps falling to −0.18/−0.23 after 2022. The middle quarters were losing ground to the life-science fields well
  before the bans. This is the drift that the 2015–18 event-study coefficients pick up; Q4 vs Q1 has no such trend.
- fig46 (one line per field) is too busy for slides; it shows two small high-coverage fields with large swings
  (e.g. IT methods for management).

## Leave-one-out and block drops (script 18g, fig47)

Official IPC, 35 fields, PPML, field + year FE; Ban_f re-standardised on the remaining fields.
- **Leave one field out:** industry map −0.072 to −0.106 (median −0.096); product-name map −0.069 to −0.102. All
  35 intervals exclude zero in both maps. Most influential: medical technology (without it −0.072), biotechnology
  (−0.079), pharmaceuticals (−0.106).
- **Drop the 5 largest fields:** −0.080 [−0.148, −0.012] (text map −0.079).
- **Drop the electronics core** (telecom, digital comm., computers, semiconductors): −0.099 [−0.154, −0.044].
- **Drop all 5 life-science fields** (pharma, biotech, medical technology, analysis of biological materials,
  organic fine chemistry): per SD −0.048 [−0.094, −0.002] (industry) and −0.033 [−0.068, +0.003] (text).
  - The SD of coverage shrinks from 0.147 to 0.088 (industry) without them, so per-SD numbers are not comparable.
  - **Per 10 pp of coverage: −6.5% with all fields vs −5.4% without life sciences (industry map); −4.9% vs −2.3%
    (product-name map).**
  - With the industry map the gradient survives among non-life-science fields at a similar per-pp size; with the
    product-name map it halves. Life sciences carry part of the identifying variation, which is the main open
    threat (state priority for pharma/medical after 2022).

## Update 2026-11-19 03:30: API codes for all years (1994-2026)
The second API run (1994-2014) finished at 03:15: 531,365 documents in 1,096 weeks; 1,716 week files in total.
Scripts 22 and 23 were rerun, so every domestic patent from 2010 on now carries official Rospatent IPC codes (share_api = 1.00,
except 2020 0.997 and 2021 0.986), and Google codes are no longer used. Scripts 18, 18b, 18d, 18e, 18f and 18g were rerun:
- main (field + year FE, industry map): -0.096 [-0.150, -0.042], RI p 0.0015 (was -0.095); sector x year -0.096
- event study 2015-2020: 0.039, 0.025, 0.022, 0.024, -0.001, -0.003 (all CIs include 0); 2022-25: -0.045, -0.094, -0.091, -0.089
- holders unchanged: public minus firms -0.075 (p 0.006)
- top vs bottom third: pooled -0.228 (SE 0.071); dose bins Q4 post -0.11/-0.26/-0.23/-0.24
- raw Q4-Q1 gap 2015-21 within +-0.10, then -0.13, -0.27, -0.25, -0.25
- leave-one-out -0.072 to -0.107, all CIs below 0. Dropping the 5 life-science fields: industry -0.049 [-0.096, -0.002],
  text -0.036 [-0.072, 0.000]; so about half the effect comes from the life-science vs rest contrast (borderline without it).
