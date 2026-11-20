# Filings by origin: is the ban result driven by foreign filers or by the grant lag? (20 Nov 2026)

Scripts: `21c_get_rospatent_api_apps.py` (download), `22b_parse_rospatent_api_apps.py`, `23b_build_filings_panel.py`,
`18t_filings_by_origin.R`; rules AP1–AP5 in `data_decisions.md`; figure `fig60_filings_origin`; tables
`filings_origin.csv`, `filings_origin_es.csv`, `filings_benchmark.csv`.

## Question

The main result (−0.096 per SD of ban coverage) uses domestic **grants** by filing year. The cross-country result
says non-resident filings fell and resident filings did not. Is the −9% a foreign-filer effect, or a grant-lag
artefact? The main panel is domestic only, so it cannot be a foreign effect by construction; this note checks the
second part and puts both origins on the same footing.

## Data

- 247,744 application publications (kind A) for filings 2010–2026 from the Rospatent API (34 min; all weeks complete).
- Filings = A publications ∪ grants without an A publication (fast grants skip A since 2014), matched on
  application number. A numbers before ~2014 carry a "/NN" check suffix, stripped before matching (fixed 20 Nov;
  before the fix 2010–13 filings were double counted and 2014 partly). Overall match rate 59%.
- Benchmark against WIPO/World Bank applications: domestic 71–90% of resident applications in 2015–2024 (missing:
  applications withdrawn before publication, the four mass filers); foreign 83–94% of non-resident applications in
  2015–2020.

## The 2021 hole in foreign filings

- Foreign filings dated 2021: 5,202 vs 9,292 (2020) and 5,247 (2022); 46% of WIPO's non-resident count.
- Almost all of it is PCT national-phase entries, which carry the international filing date. 2021 PCT filings would
  enter Russia at 30–31 months, i.e. in 2022–23, and be published around 2024: only 334 + 20 + 250 were.
- Western applicants account for it (US 1,272 → 292, DE 571 → 129, FR 442 → 97); China does not drop (343 → 318).
- Reading: Western firms did not enter Russia with the PCT cohort whose deadline fell in 2022–23 (fee payment
  problems, the 2022 zero-compensation rule for "unfriendly" patent holders). Behaviour, not missing data, but it
  makes 2021 unusable as a base year for foreign filings. Event studies here use **base 2020**.
- Caveat: 2023–2024 foreign PCT filings are not yet fully entered/published (entry deadline 2025–26).

## Results (PPML, field + year FE, 35 fields, 2015–2024, industry map, per SD of ban coverage)

| Sample | β (SE) | without 2021 | Pre-period (base 2020) |
|---|---|---|---|
| Domestic filings | −0.109 (0.030) | −0.115 (0.034) | 2015–19 between −0.03 and −0.06, all CIs include 0; 2021 −0.08 (n.s.) |
| Foreign filings | −0.253 (0.053) | −0.262 (0.054) | **steady downward trend**: +0.21 (2015) → +0.10 (2018) → 0 (2020) |
| All filings | −0.111 (0.029) | −0.116 (0.032) | flat-ish, CIs include 0 |
| Domestic grants (main) | −0.093 (0.024) | −0.096 (0.027) | flat |

Event study post coefficients: domestic filings −0.12, −0.17, −0.17 (2022–24); foreign −0.11, −0.17, −0.20.

## Reading

1. **The domestic result is not a grant-lag artefact.** On filings it is as large or larger (−0.11), with wider
   CIs (filings include pending and refused applications, which are noisier). The 2021 point estimate (−0.08) is
   pre-treatment and not significant; it widens the band but does not look like a trend.
2. **The −9% is not driven by foreign filers.** It is estimated on domestic patents only, and pooling foreign
   filings in leaves it at −0.11.
3. **Foreign filers also shift away from banned fields, but this is not identified as a 2022 effect.** Foreigners
   were leaving high-coverage fields (electronics, telecom, transport) from 2015 on; the post-2022 coefficients
   continue that trend. A trend-adjusted reading would put the foreign break near zero to −0.1. In levels, foreign
   filings fell by about half in every field (the cross-country result).
4. For the paper: two separate facts. Foreign filers exited across the board (level effect, cross-country SDID);
   domestic inventors moved out of banned fields (relative effect, this design), robust to grants vs filings.

## Base 2013: did foreign filers start leaving in 2014? (18u, fig61)

Filings 2010–2024, PPML, field + year FE, base 2013, industry map. Joint pre-tests 2010–12: p 0.51–0.99.

| Exposure | Origin | 2014–21 vs 2010–13 | 2022–24 vs 2010–13 |
|---|---|---|---|
| 2022 ban coverage | Foreign | −0.066 (SE 0.034, p 0.054) | **−0.325 (0.068)** |
| 2022 ban coverage | Domestic | 0.000 (0.028) | −0.112 (0.049, p 0.02) |
| 2014 oil list (2014–17 vs 2010–13) | Foreign | +0.012 (0.027) | – |
| 2014 oil list (2014–17 vs 2010–13) | Domestic | −0.021 (0.019) | – |

- **Foreign, 2022 coverage:** flat 2010–2017 (2014 −0.045, then back to ~0 in 2015–17); the decline starts in
  **2018** (−0.08), reaches −0.16 to −0.20 in 2019–21 and −0.29/−0.35/−0.38 in 2022–24. So it is not a 2014 effect:
  foreign filers began to leave the later-banned fields around 2018–19 (cause untested; candidates: the 2017–18 US
  sanctions on Russian firms, global shifts in where electronics/telecom firms file), and the move accelerated after 2022. The 2022+ step relative to the 2019–21 level
  is about −0.12 to −0.18. 2019–21 foreign values partly reflect PCT dating (international filing date).
- **Foreign, 2014 oil list:** no response (flat 2014–18), −0.1 in 2019–21, n.s.
- **Domestic:** flat 2010–2021 on 2022 coverage (all CIs include 0, 2020 +0.04), then −0.08/−0.125/−0.128. Over a
  long pre-period the domestic filings result looks clean; the 2015–19 dip seen with base 2020 is a base-year effect.
  2014 oil list: small drift −0.02 to −0.06 from 2015 (CIs touch 0), as in 18o for grants.

## Which foreign filers, and is 2018 special? (18u part C, fig62, rule AP6)

Foreign filings split by the first applicant's country; 2022 ban coverage, base 2013, 2010–2024.

| | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2024 | pre p |
|---|---|---|---|---|---|---|---|---|---|---|---|
| West | −0.05* | 0.01 | −0.05 | −0.03 | −0.11 | −0.18* | −0.19* | −0.25* | −0.35* | −0.45* | 0.89 |
| West without Ford | −0.06* | −0.04 | −0.10* | −0.08 | −0.11* | −0.17* | −0.18* | −0.24* | −0.34* | −0.45* | 0.92 |
| West, PCT entries | −0.05* | −0.03 | −0.10* | −0.08 | −0.12* | −0.18* | −0.20* | −0.34* | −0.36* | −0.46* | 0.93 |
| China | −0.03 | 0.05 | −0.19* | −0.16 | −0.14 | −0.39* | −0.48* | −0.44* | −0.48* | −0.61* | **0.0001** |

- **The 2018 kink is Ford.** Ford Global Technologies filed 225 (2013), 336 (2014), 933/853/858 (2015–17), 209
  (2018), then ~0. Transport is a high-coverage field, so the surge masks the trend in 2015–17 and the exit makes
  2018 look like a break. Ford ended passenger-car production in Russia in 2019.
- **Without Ford, Western filers drift out of the later-banned fields gradually from 2014** (−0.06 in 2014, −0.10
  by 2016, −0.18 by 2019–20), then step down after 2022 (−0.34 to −0.45). Pre-period 2010–12 flat (p 0.92). The
  decline starts with the 2014 sanctions/devaluation but is not picked up by the 2014 oil list (panel A, fig61).
- PCT entries carry the result; direct Western filings are noisy (few, mostly n.s. before 2022).
- China also moves away from these fields from 2016 (−0.4 to −0.6) while its total rises, but its pre-period fails
  (p 0.0001; small counts in 2010–12), so it is descriptive only. It suggests part of the shift is a general retreat of
  electronics/telecom filers from Russia, not only a Western response.
- **Concentrated in big firms.** In high-coverage fields (top tercile), the 15 foreign applicants that cut most
  account for 46% of the fall 2013–14 → 2019–20: GE, Ford (two entities), Snecma, Samsung, Siemens, Xiaomi, Philips,
  Sony, Intel, Huawei, Nissan, Microsoft, Ericsson, Alstom (`filings_foreign_top_applicants.csv`). Most of them stopped
  in 2014–15, Philips/Sony/Microsoft declined gradually, Ford in 2018.
- Implication: foreign exit from Russia's high-tech fields is a process from 2014 that 2022 deepened; the
  foreign post-2022 coefficient should not be read as a 2022 effect. Domestic filers have no such pre-trend.

## Open

- Date PCT entries by entry date (not in the API records; the publication date is a proxy) and redo the foreign series.
- Domestic filings by holder type (universities vs firms), as in 18 for grants.
