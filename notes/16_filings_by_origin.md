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
  application number. Match rate of A to grants 2014–2023: 30–64% (refusals and pending cases); before 2013 the
  register uses another number format, so use 2014+ only.
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

## Open

- Date PCT entries by entry date (not in the API records; the publication date is a proxy) and redo the foreign series.
- Domestic filings by holder type (universities vs firms), as in 18 for grants.
