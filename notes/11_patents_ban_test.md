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
