# Cross-country results

**Main method from 12 Nov 2026: staggered-adoption event studies (section A).** The local-projection results
from 11 Nov (section B onwards) are kept as a robustness check (user's decision).

## A. Main: event studies with staggered adoption (12 Nov 2026)

Script: `scripts/analysis/11_staggered_did.R`. Table: `output/tables/staggered_did.csv` (every estimator × event
time), cohorts `staggered_cohorts.csv`. Figures: `fig17_staggered_did_estimators` (all outcomes, all estimators),
`fig18_staggered_did_samples` (without China; without China, Russia, Iran), `fig19_staggered_did_measures`.

**Design**
- Treatment = a country's **first clean episode**: the first year in 1995–2023 in which a Western economic case
  begins after ≥ 5 years with none in force. Treated from then on (absorbing, "intention to treat"): later cases and
  the end of the case are ignored.
- Never treated = no Western economic case in force in any year 1990–2023. Countries with cases in force but no
  clean episode are dropped (continuously sanctioned, e.g. Iran, Cuba, North Korea, Myanmar).
- Sample: population ≥ 1m; 106 treated countries (88 with resident patent data), 40 never treated (34 with patents).
- Event time −5 to +8, base year −1; 95% intervals clustered by country.
- Estimators:
  - **TWFE** (plain two-way fixed effects event study): shown only for comparison, biased when effects differ
    across cohorts or over time;
  - **Sun–Abraham**: each cohort compared with the never treated, then averaged;
  - **Callaway–Sant'Anna**: same idea, with never-treated controls (main) or not-yet-treated controls;
  - counts in log(1+y) (each country weighs the same); Sun–Abraham PPML on levels as a variant (big countries weigh
    more).
- Variants: without China; without China, Russia and Iran; only countries with no earlier sanction since 1985
  ("first ever"); other sanction types (arms/travel); any sender.

**Results (Western economic, base sample)**

| Outcome | Before (−5..−2) | After (0..+8) |
|---|---|---|
| Resident patents, Callaway–Sant'Anna | flat (−0.12 to +0.15, all include 0) | **rising: +0.2 (0), +0.3 (2), +0.6 to +0.8 (4–8), 4–8 exclude 0** |
| Resident patents, Sun–Abraham OLS | flat | +0.20 to +0.25 at 4–8, exclude 0 |
| Resident patents, Sun–Abraham PPML | **pre-trend: −0.20 (−5), −0.12 (−3)** | +0.07 to +0.32, exclude 0 |
| Resident patents, plain TWFE | flat | about 0 (−0.03 to +0.09) |
| Resident patents, C–S not-yet-treated | flat | +0.2 to +0.6, all include 0 |
| Non-resident patents | flat | C–S +0.4 to +0.6 (include 0); SA OLS ≈ 0; **SA PPML −0.11 (4), −0.25 (6), −0.29 (8), exclude 0** |
| OpenAlex articles | **pre-trend: −0.08 (−3), −0.06 (−2)** | +0.04 to +0.15, include 0 |
| WB journal articles | flat | +0.06 to +0.12, include 0 |
| Int. co-authored share, pp | flat | −3.0 to −3.6 at 6–8, include 0 |
| TFP | flat | −0.01 to −0.02 (SA: 0 excludes zero) |
| R&D % GDP, researchers, high-tech exports, IP payments | noisy, flat | nothing that holds across estimators |

- Without China, or without China, Russia and Iran: the same (fig18). The cross-country patent result is no
  longer a China story once each country weighs the same.
- "First ever" cohorts (71 countries): resident patents +0.35 to +0.49 (C–S), mostly include zero; non-resident
  patents +0.84 to +0.88 at 4–8 (exclude 0).
- Other sanction types (arms/travel): pre-trends in articles (−0.22 at −5), no clear patent response.

**Reading**
- The new estimators turn a flat TWFE line into a **rise** in resident patents after a first sanction episode.
  This is exactly the case where plain TWFE is biased (many cohorts, effects growing with time), so the difference is
  informative about the estimator — but **not yet evidence that sanctions raise patenting**:
  1. **The never-treated group is mostly rich Western countries** (25 of 40 high income: Germany, UK, Japan, the
     Nordics...), whose resident patenting is flat or falling, while the treated are mostly emerging economies with
     rising patenting. With not-yet-treated controls (treated countries compared with each other), the rise
     shrinks and all intervals include zero.
  2. **The treated list includes questionable "targets"**: US 2003, Canada 2003, Belgium/Switzerland/Korea/
     Singapore 2023, Ireland 1998 (open decision 1 in `data_decisions.md`: trade disputes and sanctions on Western
     countries). They should not be treated.
  3. **Event-time composition**: late cohorts (2021–23: 27 countries) only contribute to e ≤ 2, so e = 4–8 comes
     from earlier cohorts.
- Non-resident patents fall after episodes under PPML (big markets), consistent with the market-access channel
  (foreign firms stop filing; Russia −54% 2021–24), but not under equal weights.
- Consistent with the earlier finding: **no robust negative effect on innovation output at the country level.**

**Next (proposed; needs your decisions)**
1. Drop Western/OECD targets (open decision 1) and rerun.
2. Not-yet-treated controls as the main comparison, or never-treated restricted to non-high-income countries.
3. Balanced event time (cohorts with all of −5..+8 observed, i.e. 1995–2015) as a variant.
4. Pre-trend-robust bounds (Rambachan–Roth, `HonestDiD`) where leads are off (OpenAlex, PPML).

---

## A2. Synthetic difference-in-differences for single cases (12 Nov 2026)

Script: `scripts/analysis/12_synthetic_did.R` (estimator written from Arkhangelsky et al. 2021, Algorithm 1; the
`synthdid` package is GitHub-only and installing it was blocked). Simulation check `12b_sdid_simulation_check.R`:
true effect 0.5 → SDID 0.54 (sd 0.10), synthetic control 0.60 (0.36), DiD 1.14 (0.44), as the paper predicts.
Tables `sdid_estimates.csv`, `sdid_paths.csv`, `sdid_weights.csv`; figures `fig20_sdid_paths`, `fig21_sdid_estimates`.

**Setup.** One treated country per case: Russia 2014 (2000–13 vs 2014–21), Russia 2022 (2010–21 vs 2022–24),
Iran 2012 (2000–11 vs 2012–15, before the 2016 relief). Donors: population ≥ 1m, no Western economic sanction in
force in the window, outcome observed every year; former Soviet states, China and Turkey excluded for Russia, Iran's
neighbours and China for Iran (spillovers). 22–80 donors. Inference: placebo (each donor as the treated unit);
standard errors and rank p-values from that distribution. Average effect over the post years, log points.

| Case | Resident patents | Non-resident patents | Articles (OpenAlex) | Articles (WB) | Int. share, pp |
|---|---|---|---|---|---|
| Russia 2014 | −0.08 (0.23) | −0.17 (0.28) | **+0.40 (0.17), p 0.04** | +0.37 (0.25) | −3.8 (5.7) |
| Russia 2022 | +0.07 (0.38) | **−0.59 (0.29), p 0.05** | −0.17 (0.21) | −0.16 (0.10), p 0.07 | −3.0 (4.9) |
| Iran 2012 | −0.32 (0.24), poor pre-fit | **−0.68 (0.35), p 0.05** | +0.01 (0.18) | −0.28 (0.18) | −0.1 (5.9) |

**Reading**
- **Non-resident (foreign) patent filings fall sharply** after Russia 2022 and Iran 2012 (about −45 to −50%),
  against a synthetic control that tracked them well before. This is the clearest result so far and matches the
  market-access channel (foreign firms stop protecting technology in the sanctioned market). After Russia 2014 the
  fall is smaller and not distinguishable from zero.
- **Resident patents: no effect** in any case. Iran's pre-period fit is poor (the synthetic control is mostly
  Vietnam), so its estimate should not be read.
- **Papers:** Russia's output rises relative to the synthetic control after 2014 (+0.40). This coincides with
  Project 5-100 (2013) and the ministry push for indexed publications, so it is not a sanctions effect. After 2022
  output dips slightly (−0.16), at the edge of significance. Iran's papers: plain DiD and SC show large rises
  (+0.9 to +1.1) that SDID removes — Iran was already growing fast, and SDID's trend matching takes that out.
- Comparison with section A: the single-case SDID agrees with the staggered DiD under PPML that non-resident filings
  fall, and shows no rise in resident patents for these cases (the pooled rise in section A came from the
  never-treated rich-country comparison).
- Limits: one treated unit per case, so inference rests on placebos (22–80); Russia 2022 has 2–3 post years; WB
  patent data are applications at the national office (by residence of the applicant, not by origin).

**By year with 95% placebo bands (`fig22_sdid_yearly_ci`, table `sdid_yearly.csv`).** Band = ±1.96 × sd of the
yearly gap across placebo runs. Pre-period gaps stay inside the bands near zero except Iran's resident patents and
WB articles (poor fit, trend before 2008). Intervals excluding zero after the event: Russia 2022 non-resident
patents in 2023 (−0.73) and 2024 (−0.67); Iran 2012 non-residents in 2014 (−1.47); Russia 2014 OpenAlex articles
from 2015 on (+0.27 rising to +0.56). Everything else includes zero.

**Check with the Python `synthdid` package** (d2cml-ai port of the R reference package; script
`12c_synthdid_python.py`, table `sdid_python_vs_r.csv`). Same case panels (`data/clean/sdid_case_data.csv`).
- **SDID point estimates are identical** to the R implementation in all 15 case × outcome cells (to 3 decimals),
  although the package uses a different solver (Frank–Wolfe with sparsification). Placebo SEs are close
  (random placebo draws: e.g. Russia 2022 non-residents 0.285 vs 0.290; Iran 2012 0.396 vs 0.352).
- DiD estimates identical. Synthetic-control estimates differ somewhat (correlation 0.85): the package's SC keeps
  a small ridge and sparsifies the weights; the SDID results are unaffected.
- **Package caveat:** its placebo SE always re-estimates SDID, whatever the estimator, so its SEs for SC and DiD
  are really SDID SEs. Use the R script's SEs for SC and DiD.
- Setup: the package pins numpy 1.23 / pandas 1.5 / Python < 3.12 and breaks under pandas 3, so it runs in a
  separate environment (current numpy/scipy, pandas 2.2.3, package installed without its pins); commands in the
  script header.

**With country covariates (`12d_sdid_covariates.R`; data `13_get_wb_covariates.py`, WDI bulk file because the WDI
API returned 502 on 12 Nov 2026).** Figures `fig23_sdid_covariates`, `fig24_sdid_balance`; tables
`sdid_covariates.csv`, `sdid_balance.csv`.
- Covariates (pre-sanction averages only): log GDP per capita, log population, oil + gas rents, trade, FDI inflows,
  manufacturing VA (% GDP), urban share; extended set adds tertiary enrolment and R&D % GDP.
- Variants: (a) same donors without covariates; (b) **covariate-adjusted**: outcome residualised on the covariates
  with year-specific coefficients estimated on donors only, then SDID; (c) **closest half** of donors in
  standardised covariate space, then SDID.
- **Balance (fig24): the outcome-only synthetic controls are economically unlike Russia and Iran.** They are richer
  (log GDP pc 10.1–10.3 vs 8.9–9.2 for Russia), much smaller, far more open (trade 79–133% vs 47–54% of GDP) and
  have almost no resource rents (1–2% vs 11–15% Russia, 27% Iran). The donor pool has few resource exporters: most
  are sanctioned themselves or excluded as close partners.

| Effect (SE) | Original | Covariate-adjusted | Closest half |
|---|---|---|---|
| Russia 2022, non-resident patents | −0.59 (0.29) | −0.69 (0.14) | −0.78 (0.22) |
| Iran 2012, non-resident patents | −0.68 (0.35) | −0.20 (0.25) | −0.67 (0.34) |
| Russia 2014, non-resident patents | −0.17 (0.28) | −0.63 (0.25) | −0.28 (0.35) |
| Russia 2022, resident patents | +0.07 (0.38) | **−0.65 (0.17)** | +0.09 (0.48) |
| Russia 2014, OpenAlex articles | +0.40 (0.17) | +0.42 (0.13) | +0.43 (0.16) |
| Russia 2022, WB articles | −0.16 (0.10) | −0.21 (0.08) | −0.16 (0.08) |

- **Robust:** the fall in foreign filings after Russia 2022 (−0.6 to −0.8 in every variant); Russia's 2014 rise in
  papers; the small 2022 dip in papers.
- **Not robust:** Iran's foreign-filing drop shrinks with covariate adjustment; Russia 2022 resident patents turn
  strongly negative only in the adjusted variant.
- **Why the adjusted variant should be read with care:** Russia and Iran lie outside the donors' covariate range
  (resource rents, openness), so residualising them extrapolates the donor regression; with 22–27 donors and 7
  covariates per year the fit is also tight, which shrinks placebo SEs. The closest-half variant avoids
  extrapolation but has only 11–16 donors for patents.
- Next if wanted: a donor pool with resource exporters (Norway, Algeria, Nigeria, Canada...) even if lightly
  sanctioned, or Kazakhstan with a spillover caveat.

---

## B. Robustness: local projections (11 Nov 2026)

Scripts: `scripts/analysis/02_cross_country_lp.R` (specification grid), `03_leave_one_out.R`, `04_figures.R`.
Results: `output/tables/lp_results.csv`, `leave_one_out.csv`. Figures: `output/figures/fig1`–`fig5`.
Data choices: `notes/data_decisions.md`.

## Setup

- Sample: 159 economies with median population ≥ 1m, event years 1995–2023.
- Measures: Western economic sanctions (main); Western arms/travel-only cases (placebo); economic sanctions by any sender.
- Three codings, as you asked:
  - **onset**: panel LP on case onset. A new case begins in t; 2 lags of shock and outcome; shock second; country and year FE.
  - **episode5**: LP-DiD. A new case after 5 years with no case in force; clean controls; h = −5..8.
  - **intensity**: number of cases in force, otherwise as onset.
- Counts are estimated by PPML. PPML weights countries by their level, so China (≈1.5m resident patent applications a year) carries much of the weight.
- Multiple testing: 9 outcomes × 3 measures × 3 codings × 8–13 horizons. A few cells excluding zero are expected by chance.

## What the estimates show

**1. Resident patents, onset coding: a pooled decline that comes from China.**
- Base estimates: −0.19 (SE 0.04) at h = 2, −0.18 (0.07) at h = 4, −0.26 (0.07) at h = 6. All 8 horizons exclude zero.
- Without China: −0.05 (0.03), −0.06 (0.07), −0.13 (0.12). No horizon excludes zero.
- Without China, Russia and Iran: about 0 (−0.03 to +0.04).
- OLS on log(1+y), which weights all countries equally: nothing (+0.08 to −0.08, all intervals include zero).
- China's Western economic onsets are 2017–2023. China's resident applications dipped in 2019 (1.39m → 1.24m). That dip is a coincidence to explain, not evidence of a sanction effect. A Chinese patent-policy change around 2019 is the obvious alternative; still to be checked.

**2. The placebo shows the same pattern.**
- Arms/travel-only cases, resident patents: −0.38 at h = 4 and −0.53 at h = 6. All 8 horizons exclude zero.
- Without Iran: −0.23 (0.20) and −0.31 (0.24), intervals include zero.
- So the pooled patent responses track a few large countries, Iran and China, not the type of sanction.

**3. New sanction episodes (LP-DiD): no response.**
- No patent horizon excludes zero (0 of 13 for residents and non-residents).
- OpenAlex articles show a pre-trend: treated countries' output grew faster than the controls' in the 5 years before the episode (−0.08 at h = −3). Countries sanctioned for the first time are fast-growing science producers, not comparable to the clean controls.

**4. Intensity: same picture.**
- Small negative patent responses: −0.02 to −0.08 per extra case; 5 of 8 horizons exclude zero.
- These vanish without China.

**5. Science output rises after onsets, also because of China.**
- Journal articles: +0.05 at h = 2, +0.09 at h = 4 (5 of 8 horizons positive and excluding zero).
- OpenAlex articles: up to +0.15 at h = 6.
- Both go to about zero without China.
- The share of internationally co-authored papers does not move in any coding: all intervals include zero, and point estimates are within ±2 pp.

**6. The other outcomes show nothing.**
- R&D % GDP, researchers, high-tech exports and IP payments: almost all intervals include zero in all codings.
- These series are sparse for exactly the sanctioned countries: Iran has no IP-payments data, and Russia's high-tech exports start in 2007.

## Reading

The cross-country panel does **not** show a robust effect of sanctions on innovation. The large pooled estimates
come from one or two countries. The placebo behaves like the treatment. First-time episodes show no response, and
they have pre-trends in publications. This matches the warning in the design note: at the country level, only a
handful of sanctioned countries patent or publish at scale, so the pooled estimate is effectively a comparison of
China, Russia and Iran with everyone else.

What this suggests for the next step:
- The question has to be answered **within** countries: Russia and Iran by technology field, firm or institution
  (design note §3.1–3.3).
- The panel remains useful as descriptive context and as a robustness table.

## Open points

- Decisions listed at the end of `notes/data_decisions.md`: Western targets such as France, the US and India; SU/CS
  mapping; OpenAlex types.
- Patents by applicant origin (filings at home and abroad) from WIPO, instead of applications at the national
  office only. Needed to separate a real decline from a mechanical drop in filings abroad.
- Event studies for single cases (Russia 2014 and 2022, Iran 2012) with synthetic control, as a bridge to the micro work.

---

## Follow-up (11 Nov 2026): placebo, China, residents vs non-residents, papers

Scripts: `scripts/analysis/05_diagnostics.R` (tables `diag_*.csv`), `01_descriptives.R` (fig0a, fig0b).

**Why is the placebo so large?**
- Your coincidence theory holds for timing:
  - 63% of the 126 placebo onsets happen while a Western economic case is already in force.
  - 65% have an economic onset within ±2 years.
- But coincidence does not explain the size. Controlling for economic sanctions (onset, 2 lags, cases in force)
  barely moves the placebo: residents −0.33 (0.10) at h = 4 and −0.46 at h = 6, against −0.38 and −0.53 without controls.
- The size comes from **Iran**:
  - Under PPML each event is weighted by its patent level. Iran 2017 (a travel-only US case) carries 51% of the
    weight of the placebo-only events.
  - Iran's resident applications fell 0.38 log points from 2016 to 2021.
  - Without Iran, the placebo is −0.15 (0.15) and −0.20, with intervals that include zero.
- The economic estimate is **China**: China's four onset years 2017–2020 carry about 90% of the weight. China's
  patents still grew (+0.09 to +0.30 log points over 5 years), but much more slowly than its own past growth,
  which the lags in the LP extrapolate.
- So the economic and placebo estimates differ because they rest on different single countries, not on the type
  of sanction.

**Is China really "heavily sanctioned"?** In GSDB case counts, yes; in economic weight, no.
- GSDB records 14 new Western cases against China in 2017–2023, mostly **targeted**:
  - export controls on named firms (partial trade measures);
  - Hong Kong and Xinjiang asset freezes and travel bans on officials (EU, UK, Canada, US, 2021).
- Two of these cases are **multi-target lists**:
  - case 1364: US human-rights designations in 18 countries;
  - case 1480: secondary sanctions for Russia evasion in 11 countries, including Korea, Switzerland and the UAE.
- After the target split (G1), each listed country gets a full "economic sanction". Our measure counts cases, not
  their economic bite.

**Residents vs non-residents (fig0a)**
- **Russia:** non-resident applications fall from about 16,000 (2014) to about 5,000 (2024). Resident applications stay
  around 20,000–29,000.
- **Iran:** non-residents dip in 2014, jump to about 1,000 in 2016–17 (JCPOA years), then fall again after 2018.
  Residents rose from about 300 (1995) to 15,000 (2008) and have drifted down since 2017.
- **Venezuela:** non-residents fall from about 2,400 (2007) to about 200.
- **Belarus:** residents halve in 2013–2015, which is not at a sanction onset.
- Non-resident filings measure foreign firms' interest in protecting technology in the market. This is the
  market-access channel. They look more responsive than resident filings, and in Iran they move with sanctions
  relief and reimposition.

**Papers (fig0b)**
- Russia's output stops growing around 2021 and declines slightly after 2022.
- Iran's falls by about 45% in 2022–23, while its share of internationally co-authored papers jumps from about 11%
  (2016) to 30%.
- Russia's international share falls steadily from about 33% (2005) to 13%, well before 2014.
- Both patterns are partly **indexing**: OpenAlex adds or loses national-language journals, which moves the
  domestic denominator. Before reading them as effects, restrict to a stable set of journals (e.g. OpenAlex
  "core" sources; to check).

**Ideas this raises**
1. **Patents by applicant's country (WIPO, public): office × origin × year.** Filings by applicants from country o
   at office d, with sanctions by o against d, and fixed effects for o×year and d×year. This compares Western
   applicants with non-Western applicants filing in the same sanctioned office in the same year. Within-country,
   public data, and it targets exactly the non-resident result.
2. **Sanction measure by bite:** drop multi-target designation cases, or count only broad measures (complete
   trade bans, UN and EU regimes). Not done yet; needs your decision.

---

## Corrections and plan after discussion (12 Nov 2026)

- **Russia non-residents** in numbers (the log scale hides it): 16,236 (2014), 11,408 (2021), 7,954 (2022),
  6,069 (2023), 5,196 (2024). That is −54% from 2021 to 2024, while residents went from 19,569 to 21,502. The
  non-resident share fell from 0.37 to 0.19.
- **Placebo.** Arms/travel-only cases are not a placebo: they hit the same regimes at the same times (63% overlap)
  and are a different treatment. Relabel them "other sanction types". Replace the falsification checks with:
  - (a) pre-event leads (already in LP-DiD);
  - (b) fake event dates (onsets shifted 3–5 years earlier);
  - (c) randomization inference: permute onset years within country, re-estimate, and compare.
- **Method.** Local projections are uncommon in this literature, which uses event studies, panel DiD, gravity,
  synthetic control and listing-date DiD. In our data the method is not what drives results; PPML weighting and the
  country trends are. Proposed base:
  - stacked event study / LP-DiD with clean controls and leads;
  - outcomes in growth rates or with country trends, so the general upward trend in papers and patents is removed;
  - equal-weight (OLS on logs) and PPML side by side.
- Literature: `notes/literature_sanctions.md`. Wen et al. (2024) and Miromanova & Hovhannisyan (2025) already cover
  cross-country and Russian patenting, so our contribution has to come from measurement (trade-weighted intensity),
  origin-level patent data (WIPO), or Iran.

---

## TFP (12 Nov 2026)

**Data.** Penn World Table 11.0, `rtfpna`: TFP at constant national prices, 2021 = 1. It is the PWT series for
changes over time within a country. Source: FRED (`scripts/data/05_get_pwt_tfp.py`). Coverage: 114 economies,
including Russia, Iran, Venezuela and China, but not Belarus, Syria, Myanmar or North Korea.
Figure: `fig0c_tfp_key_countries`.

**Estimates (log TFP, all codings).**
- No response. Point estimates are within ±0.03 log points at every horizon, for every measure and every
  specification variant.
- In the base specification only one cell excludes zero: placebo intensity at h = 6, −0.020 (0.009).
- Pre-trends in LP-DiD are flat (+0.013 at h = −4, intervals include zero).
- Events with TFP data: 180 onset years in 65 countries; 70 clean episodes in 60 countries.
- Leave-one-out: no single country carries the estimate. Dropping Venezuela moves it most (+0.001 → +0.012 at h = 4).

**Raw series (fig0c).**
- **Iran** moves with sanction escalation and relief:
  - −7.6% in 2012 (oil and central-bank sanctions);
  - +8% in 2016 (JCPOA relief);
  - −7% in 2018–19 (reimposition);
  - then recovery to 2023 although sanctions stayed in force.
- **Venezuela** falls by about 70% from 2013 to 2020. The fall starts before the 2017 financial sanctions.
- **Russia** is flat in 2014–16 (TFP was still growing until 2013) and dips −3% in 2022.
- **China** rises steadily.

**How to read TFP here.** TFP is the residual of GDP after measured capital and labour. It contains technology, but
also capacity utilisation, misallocation, terms of trade and measurement error. When oil exports are cut, oil capital
stands idle and measured TFP falls without any change in technology. Iran's 2012/2016/2018 swings look like this.
Over a few years, sanctions show up in TFP mainly through utilisation and the loss of imported inputs. Whether they
slow technology itself would show over a longer horizon, or in measures closer to technology: patents, imported
capital goods, product upgrading.
