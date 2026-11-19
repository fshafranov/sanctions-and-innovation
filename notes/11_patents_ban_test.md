# Main test: do domestic patents respond to EU ban coverage by technology field?

## Specification (fixed 12 Nov 2026, before any estimate was seen)

**Question.** After 2022, did Russian domestic invention shift toward or away from the technology fields where the
EU banned more of Russia's Western imports?

**Main equation (PPML)**

    P_ft = exp( β · Ban_f · Post_t + α_f + γ_t ) · ε_ft

- **P_ft:** domestic invention patents (Rospatent register; mass filers dropped), counted in the top predicted WIPO
  field (`n_top`, note 08), field f = 1..35, filing year t = 2015–2025.
- **Ban_f:** EU ban coverage at end-2023, i.e. the share of 2019–21 Western imports of manufactured goods covered by
  the bans (note 10), z-scored across fields.
  - **Industry map** (Dorner–Harhoff) is the main version. The product-name map uses the same title classifier as
    the outcome, which could create correlated measurement error between treatment and outcome.
- **Post_t** = 1 for 2022–2025.
- Field and year fixed effects.
- **Inference:**
  - SEs clustered by field (35).
  - **Main p-value: randomization inference.** Ban_f is permuted across fields 2,000 times, and the share of
    |β_perm| ≥ |β| is reported.

**Event-study version:** Ban_f × year dummies, base 2021, to show the pre-trend (2015–2020) and dynamics.

**Decision rule (from note 08 and session 3's kill rule)**
- If the 95% interval of β includes 0 **and** excludes ±0.10 (i.e. ±10% per SD), report a **tight null**.
- If the interval excludes 0 and the pre-period is flat, the sign is the result:
  - β > 0 = substitution toward banned fields;
  - β < 0 = invention fell where inputs were cut.
- Otherwise the result is uninformative.

**Pre-specified robustness checks (secondary; they do not change the main result)**
1. Product-name map for Ban_f.
2. Drop the classifier's weak fields (out-of-time recall < 0.5, note 08).
3. Outcome by holder type: firms; universities; research institutes.
4. Outcome `n_hybrid` (IPC where matched).
5. Years 2015–2024 (drop the incomplete 2025).
6. Coverage without partial ("ex") bans.

## Results

Scripts: `scripts/data/20_build_field_holder_panel.py`, `scripts/analysis/16_patents_ban_test.R` (pre-registered
specification), `16b_patents_ban_trends.R` (exploratory). Tables: `output/tables/patents_ban_test.csv`,
`patents_ban_eventstudy.csv`, `patents_ban_trends.csv`. Figures: fig30 (event study), fig31 (randomization
distribution).

### Main test (as pre-registered)

**β = −0.092, 95% CI [−0.114, −0.069], randomization p = 0.0065** (2,000 permutations; 35 fields × 2015–2025).
One SD more ban coverage means about 9% fewer domestic patents in that field after 2022, relative to other fields.
- One SD of coverage is about 0.13, i.e. 13 percentage points of a field's Western imports banned.
- Telecom (0.65) vs pharma (0.25) is about 3 SD apart, so roughly −25% for telecom relative to pharma.

**Pre-specified robustness checks:** all negative.

| # | Variant | β | 95% CI |
|---|---|---|---|
| 1 | Product-name map | −0.099 | [−0.154, −0.045] |
| 2 | Drop weak fields (27 fields left) | −0.090 | [−0.114, −0.066] |
| 3a | Firms | −0.047 | [−0.101, +0.007] |
| 3b | Universities | −0.091 | [−0.122, −0.061] |
| 3c | Research institutes | −0.118 | [−0.149, −0.087] |
| 4 | `n_hybrid` | −0.090 | [−0.111, −0.069] |
| 5 | 2015–2024 | −0.087 | [−0.108, −0.065] |
| 6 | Without "ex" codes | −0.090 | [−0.114, −0.065] |

**Event study (fig30, industry map):**
- Pre-period: +0.063 (2015), +0.044, +0.036, +0.040 (2018), +0.012, −0.005 (2020), 0 (2021).
- Post: −0.031 (2022), −0.069 (2023), −0.072 (2024), −0.080 (2025).
- **The pre-period is not flat.** High-coverage fields were already drifting down relative to others, by about
  1% per SD per year. 2017 and 2018 exclude zero. 2019–2021 is flat.
- The product-name map is similar, with a flatter pre-period.

**By the decision rule** the interval excludes 0, but the pre-period is not flat. So the sign cannot be read off
the main estimate alone. The exploratory trend checks below handle this.

### Exploratory (not pre-registered): trend checks

| Specification | Industry map (main) | Product-name map |
|---|---|---|
| Window 2019–2025 (flat pre-period) | −0.066 [−0.085, −0.047] | −0.084 [−0.120, −0.049] |
| Field-specific linear trends | −0.027 [−0.080, +0.027] | −0.064 [−0.121, −0.007] |
| Linear pre-trend in the ban gradient, extrapolated: post shift | −0.021 [−0.074, +0.032] | −0.060 [−0.117, −0.003] |
| … its pre-trend slope per year | −0.011 [−0.022, 0.000] | −0.005 [−0.021, +0.011] |
| … change in slope after 2022 | −0.003 [−0.012, +0.005] | −0.004 [−0.020, +0.011] |

### Reading

1. **No import substitution.** Across every specification, pre-registered and exploratory, both maps and all holder
   types, the estimate is ≤ 0. The highest upper bound is +0.03 per SD. Substitution toward banned fields larger
   than about **3% per SD can be ruled out**. Fields cut off from Western imports did not attract more domestic
   invention. The rise was in the least-banned fields (medical, pharma, biotech).
2. **Probably a relative decline in banned fields, size uncertain:**
   - Unadjusted −9% per SD; short window −7 to −8%; trend-adjusted −2 to −6% per SD.
   - With the main (industry) map, the trend-adjusted interval includes 0. With the product-name map it excludes 0.
   - Part of the gap continues a pre-2022 drift away from machinery and electronics toward life sciences.
3. **Who:** the decline is clearest for research institutes (−12%) and universities (−9%). For firms it is −5% and
   the interval just includes 0. That fits lost access to imported equipment and inputs for research, more than
   firms dropping product lines. This interpretation is not tested.
4. **With the earlier results:** domestic invention did not fall in total (+2% nationally), and foreign filers left
   (−50%). Within domestic invention there was no shift *into* the fields Russia could no longer import. If
   anything, there was a shift *out of* them, consistent with complementarity between imported inputs and domestic
   R&D rather than substitution.

**What this supports as a paper:** *"A large, sender-defined supply shock with a strong first stage, no
substitution into the banned technologies (bounded at about +3% per SD), a likely modest relative decline, and the
exit of foreign inventors."*

**Open:**
- HonestDiD / Rambachan–Roth bounds on the pre-trend.
- The region × field version (region × year FE) as the main robustness check.
- The share of the decline due to the classifier is limited: the weak-field and IPC-hybrid checks give the same
  result.

## 2014 (exploratory, not pre-registered)

Script `scripts/analysis/16c_patents_2014.R`; tables `output/tables/patents_2014_eventstudy.csv`,
`patents_2014_pooled.csv`; fig32. Same design: PPML, field and year FE, base 2013, SEs clustered by field.

**(A) The 2014 oil-equipment controls** (Annex II coverage of 2011–13 Western imports, z-scored)
- Pre-period flat: 2008–12 within ±0.04, all intervals include 0.
- After 2014, industry map: 2014 +0.003, 2015 −0.024, **2016 −0.047, 2017 −0.070** (both exclude 0), 2018 −0.032,
  2019 −0.064.
- Pooled 2014–17 (window 2009–17): −0.022 [−0.057, +0.013] (industry map); −0.017 [−0.029, −0.005]
  (product-name map).
- **Same sign as 2022: no substitution, a mild relative decline.**
- Caveats:
  - The list is tiny (1.4% of Western manufactured imports; at most 4–9% of any field), so the z-score is driven by
    a few fields (metallurgy, civil engineering/drilling, machine tools, handling).
  - **The oil-price collapse of late 2014** cut oil-sector investment in exactly these fields. This design cannot
    separate the export controls from the oil price.
  - Fits note 05: in E21B the foreign holders' share halved after 2014 and Russian inventors did not fill the gap.

**(B) Fields later banned in 2022, long window 2008–2025, base 2013** (industry map)
- 2008–10 lower (−0.04, −0.08, −0.03); 2011–13 flat.
- **No reaction to 2014** (2014 +0.004, 2015 −0.013). The devaluation, the counter-sanctions and the
  import-substitution programmes from 2015 did not pull invention into these import-dependent fields.
- A slow drift down 2016–2021 (−0.03 to −0.08, intervals include 0), then a step in 2022: −0.11, −0.15, −0.15,
  −0.16 (all exclude 0). The pre-trend in the main test is this 2016–21 drift.
- Pooled 2014–17: +0.006 [−0.032, +0.043].
- The product-name map is noisier (post-2022 only 2023 excludes 0 with base 2013).

**Reading:** both episodes point the same way. Neither the 2014 shock (narrow controls plus a large devaluation)
nor the 2022 shock (broad bans) moved domestic invention *into* the affected technologies. Where there is a
response, it is a modest relative decline. The 2022 step is larger and cleaner. 2014 is confounded by the oil
price, and its shock was small.

## Staggered and continuous-dose versions (exploratory, not pre-registered)

Script `scripts/analysis/16d_patents_staggered.R`; tables `output/tables/patents_staggered.csv`,
`patents_staggered_es.csv`; fig33. Domestic invention patents (`n_top`), industry map, SEs clustered by field.

**Why 2014 and 2022 do not form one staggered design**
- The 2014 oil list covered at most 4% of any field's Western imports, so no field "adopts" in 2014 under any
  sensible threshold.
- The 2014 fields were treated again, much harder, in 2022, so treatment is not absorbing.
- 2014 coincides with the oil-price collapse.

They can be combined as a **time-varying continuous dose**. The genuine staggered timing is **within 2022–25**:
the EU added products package by package.

**(1) Continuous dose, both episodes, 2008–2025**

PPML of patents on Oil_ft (2014 oil-list coverage, from 2014) + EU_ft (EU coverage at end of year t, from 2022),
with field and year FE. Per 10 percentage points of coverage:

| Episode | Estimate per 10 pp | 95% CI |
|---|---|---|
| EU (2022+) | **−0.076** | [−0.100, −0.053] |
| EU only, 2015–25 | −0.068 | [−0.083, −0.053] |
| Oil list (2014+) | −0.31 | [−0.88, +0.26] |

- Banning another 10% of a field's Western imports goes with about 7% fewer domestic patents.
- The oil-list coefficient is uninformative: its coverage never exceeds 4 pp, so "per 10 pp" extrapolates far
  beyond the data. Combining the two episodes adds no information beyond 2022.

**(2) Staggered binary within 2022–25**

A field is treated from the first year its EU coverage reaches 50%.
- Cohorts: 2023: 21 fields; 2024: 5; 2025: 4.
- Never treated by 2025: medical technology, pharma, analysis of biological materials, textile and paper machines,
  other consumer goods.
- With a 60% threshold: 2023: 7, 2024: 10, 2025: 8, 2026: 1, never: 9.

| Estimator | 50% threshold | 60% threshold |
|---|---|---|
| Plain TWFE PPML | −0.217 [−0.327, −0.107] | −0.149 [−0.269, −0.029] |
| **Sun–Abraham PPML, ATT** | **−0.105 [−0.192, −0.018]** | −0.057 [−0.140, +0.025] |
| Callaway–Sant'Anna, log(1+n), never-treated | −0.125 [−0.242, −0.008] | −0.125 [−0.305, +0.055] |
| Callaway–Sant'Anna, log(1+n), not-yet-treated | −0.147 [−0.262, −0.032] | −0.110 [−0.291, +0.072] |

- TWFE is about twice the heterogeneity-robust estimates (forbidden comparisons of late with early cohorts).
  The robust estimators give **−6% to −15%**. With the 50% threshold the intervals exclude 0; with 60% they
  include 0.
- Event study by relative time (fig33):
  - Sun–Abraham, pre-period: +0.17 (e = −7), +0.14, +0.13, +0.07, +0.04, +0.06 (e = −2), 0.
  - Callaway–Sant'Anna, pre-period: +0.07 … +0.11 (e = −5) … 0.
  - **The same downward pre-drift as in the main test.**
  - Post: −0.09 to −0.10 (e = 0), −0.10 to −0.21 (e = 1), −0.13 to −0.15 (e = 2).
- Caveats:
  1. The never-treated group is five life-science and consumer fields, the ones that rose for other reasons
     (pharma localization, healthcare). The not-yet-treated comparison avoids them and gives similar numbers.
  2. Annex VII electronics bans are dated Dec 2023 via Annex XL (B5), so electronics cohorts are dated too late.
  3. Few fields per cohort (4–5 in 2024/2025).

**Reading:** the staggered and dose versions tell the same story as the main test. There is no substitution, and
domestic invention declined modestly in fields as they became banned (about 6–15% for crossing 50% coverage, about
7% per 10 pp of coverage). The pre-2022 drift is still present and limits how much of this is causal. 2014 adds no
usable variation.

## Sector × year fixed effects (exploratory, session 5, 18 Nov 2026)

Script `scripts/analysis/16e_patents_sector_fe.R`; tables `output/tables/patents_sector_fe.csv`,
`patents_sector_fe_es.csv`; fig34. Year FE replaced by WIPO sector × year FE (5 sectors, Schmoch 2008), so fields
are compared only within their sector. 73% of the cross-field variance of Ban_f is within sector. Randomization
inference permutes Ban_f within sector (2,000 draws).

| Specification | Industry map (main) | Product-name map |
|---|---|---|
| Year FE (pre-registered main) | −0.091 [−0.114, −0.069] | −0.099 [−0.154, −0.045] |
| **Sector × year FE** | **−0.099 [−0.127, −0.071]**, RI p = 0.020 | −0.115 [−0.178, −0.052], RI p = 0.009 |
| Sector × year FE, 2019–2025 | −0.074 [−0.097, −0.052] | −0.097 [−0.143, −0.050] |
| Sector × year FE + field linear trends | −0.031 [−0.049, −0.013] | −0.059 [−0.092, −0.027] |

**Event study, industry map, sector × year FE:**
- Pre: +0.068 (2015), +0.059, +0.033, +0.037 (2018), +0.005, +0.015 (2020), 0.
- 2015, 2016 and 2018 exclude 0. **The pre-trend is not removed**; the intervals are tighter.
- Post: −0.028, −0.076, −0.079, −0.085 (all exclude 0).
- Product-name map: pre-period 2018 and 2020 exclude 0; post −0.04 to −0.10.

**Reading:** the drift is within sectors (e.g. pharma/biotech vs metallurgy inside chemistry; medical vs
measurement inside instruments), not between them. Sector × year FE does not deliver a flat pre-period. What is
new: with field trends on top of sector × year FE, the industry-map estimate now excludes 0 (−3%/SD). 2019–21 is
flat in every version. Next: HonestDiD bounds, and designs with more treatment units (finer technology classes,
firm level).

**Superseded numbers.** The sector × year table above was computed before the industry-map bug fix (M3). The
corrected numbers are in the next section.

## Session 5 update: industry-map bug fix, corrected results, holder types, regions

**Bug (decision M3).** The industry map dropped HS→ISIC links whose ISIC4 group does not exist in NACE Rev.2,
mainly ISIC 2100 (pharma) and 1701/1702/1709 (paper). The product's remaining links were then renormalised, so
medicaments (HS 3004, the largest Western import line) went ⅔ to *medical technology* and none to pharma. This
affected 8% of Western manufactured import value. Fix: fall back to the Dorner–Harhoff 2-digit table.
- Coverage changes: pharma 0.25 → 0.08, biotech 0.35 → 0.19, organic fine chemistry 0.39 → 0.26, medical
  technology 0.13 → 0.20, optics 0.41 → 0.49. Correlation of old and new field coverage 0.93.
- Agreement of the two maps on the top field per HS code rose from 0.29 to 0.36.
- The product-name map is unchanged. All scripts from 16 onward were rerun (`run_all.sh` order). The
  pre-registered specification is unchanged; only the input was corrected.

**Corrected main test (industry map, as pre-registered):** β = **−0.099 [−0.151, −0.047]**, RI p = 0.002.

| Variant | β | 95% CI |
|---|---|---|
| 1 Product-name map | −0.099 | [−0.154, −0.045] |
| 2 Drop weak fields | −0.097 | [−0.152, −0.041] |
| 3a Firms | −0.041 | [−0.109, +0.027] |
| 3b Universities | −0.110 | [−0.141, −0.078] |
| 3c Research institutes | −0.131 | [−0.206, −0.056] |
| 4 n_hybrid | −0.098 | [−0.132, −0.064] |
| 5 2015–2024 | −0.097 | [−0.142, −0.051] |
| 6 Without "ex" codes | −0.096 | [−0.149, −0.043] |

**Corrected event study (industry map, field + year FE):**
- Pre: +0.047 [−0.046, 0.139] (2015), +0.032, +0.029, +0.034 [−0.006, 0.075] (2018), +0.003, −0.003 (2020), 0.
- **No pre-period coefficient excludes zero.** The point estimates still slope down (about +0.03 to +0.05 in
  2015–18). That is a drift of about 1%/SD/yr, with wider intervals than before the fix. So this passes the
  "insignificant pre-period" rule, but the drift should still be bounded (HonestDiD).
- Post: −0.047, −0.091, −0.087, −0.084 (all exclude 0).

**Corrected sector × year FE (industry map):** β = −0.105 [−0.164, −0.046], within-sector RI p = 0.012. Event
study pre-period: 2015 +0.067, 2016 +0.057, 2018 +0.035 exclude 0. So sector × year FE makes the pre-period
*worse*. With field trends added: −0.038 [−0.066, −0.010]. 2019–25 window: −0.081 [−0.127, −0.035].

### Holder types (script 16f, fig35; field × holder × year panel)

PPML with field × holder FE and holder × year FE, Ban_f × Post by holder type, SEs clustered by field:

| Holder | Industry map | + sector × year | Product-name map |
|---|---|---|---|
| Firms | −0.041 [−0.109, +0.027] | −0.049 [−0.127, +0.028] | −0.024 [−0.089, +0.040] |
| Universities | −0.110 [−0.141, −0.078] | −0.120 [−0.160, −0.080] | −0.123 [−0.158, −0.088] |
| Research institutes | −0.131 [−0.206, −0.056] | −0.133 [−0.212, −0.054] | −0.142 [−0.229, −0.055] |
| Individuals | −0.119 [−0.233, −0.005] | −0.122 [−0.204, −0.040] | −0.098 [−0.239, +0.043] |

- Universities + research institutes minus firms: **−0.078 (SE 0.029, p = 0.007)**.
- The decline is in public research (universities, institutes) and individuals. Firms show a small decline whose
  interval includes 0.
- Readings to test: (a) public labs lost imported equipment and reagents with no budget to switch suppliers;
  (b) universities file to meet ministry patent targets, so they shift filings quickly toward funded topics; firms
  keep their technology lines.

### Region × field × year (script 16f, fig36)

84 regions × 35 fields × 2015–25 (32,340 cells, 50% zero; 25,189 used after FE drop all-zero region × field
cells). PPML with region × field FE and region × year FE, so the effect is identified *within regions*, across
fields:

| Specification | Industry map | Product-name map |
|---|---|---|
| region × field + region × year FE | −0.095 [−0.146, −0.043] | −0.098 [−0.151, −0.045] |
| + sector × year FE | −0.104 [−0.156, −0.051] | −0.116 [−0.173, −0.058] |

- SEs clustered by field. Two-way clustering (field + region) gives slightly smaller SEs (0.021–0.026).
- Event study, region × year FE: pre-period +0.039, +0.028, +0.033, +0.033 [−0.001, 0.067], +0.002, −0.005; none
  exclude 0. Post −0.047, −0.093, −0.083, −0.080.
- Regional shocks (mobilisation, defence orders, local budgets) are absorbed by region × year FE and do not drive
  the result. The treatment is still field-level (35 clusters), so this is robustness, not more power.

## 2014 with official IPC and a long pre-period (20 Nov 2026; script 18o, fig55; supersedes the 16c numbers above)
PPML, 35 fields, field + year FE, base 2013, SEs clustered by field, official IPC (Rospatent API), 2005-2021/2025.
- **(A) 2014 oil-equipment list** (Annex II coverage, at most 4% of a field's imports). Industry map: pre 2005-12 flat
  (joint p 0.10), then 2015 -0.033, 2016 -0.054, 2017 -0.073 (all exclude 0), staying around -0.05 to -0.07 to 2021.
  Product-name map: smaller (-0.02 to -0.03, n.s.) and pre-period rejects (p < 0.001). Pooled 2014-17 vs 2009-13:
  -0.027 (p 0.17) / -0.021 (p 0.003). Still confounded by the late-2014 oil-price collapse.
- **(B) 2022 ban coverage over 2005-2025, base 2013:** the later-banned fields ROSE relative to the rest in 2005-2013
  (2005-09 about -0.04 to -0.07 relative to 2013), peaked in 2014 (+0.015), then drifted down 2015-2021 (to -0.055),
  then dropped in 2022-25 (-0.10, -0.15, -0.15, -0.14). Three-period pooled version (base 2005-13): 2014-21 +0.005
  (p 0.83), 2022+ -0.098 (p 0.047) industry; text +0.001 / -0.102 (p 0.048).
  => The 2015-21 "pre-trend" of the main design is the down-leg of a rise-and-fall cycle that peaked in 2014, not a
  long monotone decline; against the 2005-13 baseline, 2014-21 is on average unchanged and 2022+ is -0.10.
- Main design (2015-2025, base 2021) with oil-list coverage x year as control (corr with 2022 coverage 0.52 industry,
  0.18 text): pre Wald p 0.47 (industry; pre coefficients not flatter, SEs larger), 0.02 (text); post unchanged
  (-0.07, -0.11, -0.08, -0.08).
- Missing: the dual-use channel of 2014 (Art. 2a/2b Reg 833/2014: dual-use goods banned for military end-users).
  Needs the Commission's dual-use <-> CN correlation table (CIRCABC; the JSON API needs a login, so a manual download of
  the 2013/2014 table is required).

## 2014 with dual-use exposure (20 Nov 2026; rule DU1; scripts 27, 18p; fig56; dualuse_2014_*.csv)
Exposure = share of the field's 2011-13 Western imports in products that can be declared as dual-use goods (Commission
correlation table, 1 Apr 2014). Broad (any 10-digit line listed; 25% of Western manufactured imports) and narrow (HS6
listed as a whole; 8%). Most exposed: telecom (0.54 broad), basic/digital communication, semiconductors, nano, optics,
computers, control. Correlation with 2022 ban coverage 0.66 (industry) / 0.69 (text); with the oil list 0.21 / -0.26.

(A) 2014 event study, 2005-2021, base 2013, PPML, per SD:
- **Dual-use-exposed fields GAINED after 2014**, not lost: pooled 2014-17 +0.072 (p 0.01), 2018-21 +0.073 (p 0.08),
  industry broad; narrow +0.072 / +0.100; product-name map broad +0.055 / +0.085 (p 0.06 / 0.03); with the oil list
  in the same model similar.
- Pre-period: industry map rises from about -0.10 (2005-08) to ~0 by 2011 (clustered Wald p 0.001; bootstrap-t
  0.54); product-name map flatter (-0.04 to 0; Wald p 0.30, bootstrap 0.77) and the post rise is clearer there
  (+0.03 in 2014 to +0.10 in 2020).
- Reading: after 2014, Russian patenting moved TOWARD the dual-use technologies (electronics, communication), the
  opposite of 2022. Consistent with import substitution after 2014 (state programmes, defence procurement), but not
  identified as a sanctions effect: the 2011-2020 State Armament Programme, the devaluation and import-substitution
  policy all target the same fields, and the industry-map pre-period already rises from 2009-11.
(B) Main 2022 design with dual-use-2014 x year: the pre-period does NOT flatten (2015 coefficient rises to +0.07),
bootstrap pre-test p 0.56 -> 0.71 (industry), 0.32 -> 0.59 (text); post unchanged (-0.03, -0.08, -0.09, -0.09).
=> The 2015-21 drift of 2022-exposed fields is not early treatment through the 2014 dual-use restrictions (those
fields grew after 2014). Together with 18o: 2022-exposed fields rose until 2014 and drifted down after; dual-use
fields within them rose after 2014, so the drift comes from the non-dual-use part of 2022 coverage (machinery,
vehicles: the industrial-capacity annex).
