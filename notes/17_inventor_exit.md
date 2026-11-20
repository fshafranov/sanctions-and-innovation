# Inventors: extensive vs intensive margin and exit (20 Nov 2026)

Scripts: `31_build_inventor_panel.py`, `18v_inventor_exit.R`; rules IV1–IV4 in `data_decisions.md`; figures
`fig63_inventor_margins`, `fig64_inventor_continuation`; tables `inventor_field_*.csv`, `inventor_cont_*.csv`.
Motivation: emigration as a mechanism (Moser, Voena & Waldinger 2014 is the receiving-side mirror).

## Data

- Domestic filings 2010–2025 (applications + fast grants, as 23b), mass filers dropped: 346,677 → 310,205 apps.
- Russian inventors identified by full Cyrillic name with patronymic (98.6% of RU inventor rows have that format):
  **290,929 inventors, 629,800 inventor-years.** Homonyms merge; 19.5% have one of the 300 most common surnames.
- Nationally there is no exodus visible in Russian filings: active inventors 37–41k/yr (2017–2024; 37.1k in 2021,
  40.7k in 2024), new inventors 13–15k/yr; the share of inventors who file again within two years rose
  (0.418 cohort 2019 → 0.449 / 0.459 cohorts 2021 / 2022).
- **Rospatent cannot show destinations.** Only 584 RU inventors ever reappear with a foreign country code since
  2010 (15–25 a year, mostly BY/KZ/UA/AM), with no rise after 2022: emigrants stop filing in Russia. "Exit" here
  = stops filing in Russia (emigration, leaving R&D, or no longer patenting).

## (A) Field level: who carries the −11%? (PPML, field + year FE, 2015–2024, per SD ban coverage)

| Outcome | β (SE) | Event study 2022 / 2023 / 2024 (base 2021) |
|---|---|---|
| Applications | −0.110 (0.030) | −0.041* / −0.084* / −0.086* |
| Active inventors | −0.070 (0.024) | −0.028* / −0.066* / −0.073* |
| New inventors (entrants) | −0.067 (0.020) | −0.026* / −0.066* / −0.078* |
| Returning inventors | −0.071 (0.028) | −0.029* / −0.066* / −0.071* |
| Applications per inventor (log, OLS) | −0.034 (0.013) | 0.001 / −0.014 / −0.021 |

Pre-period: inventors drift down slowly from +0.045 (2015) to 0 (2020–21), similar to the main grants series;
2019–2020 ≈ 0.

**About two thirds of the decline is fewer inventors, one third lower output per inventor.** Fewer people enter
the banned fields and fewer incumbents stay, in equal measure.

## (B) Inventor level: do incumbents in banned fields stop filing? (LPM, cohort + modal-field FE)

Outcome: files again in t+1 or t+2 (base rate 0.43). Exposure = ban coverage of the inventor's year-t fields.

| Sample | Cohorts 2012–22 | Cohorts 2016–22 |
|---|---|---|
| All | −0.016 (0.005) | −0.012 (0.006) |
| Without common surnames | −0.015 (0.005) | −0.011 (0.006) |
| University | −0.016 (0.006) | −0.014 (0.007) |
| Research institute | −0.013 (0.008) | −0.009 (0.010) |
| Firm | 0.000 (0.006) | +0.003 (0.007) |
| Individual | −0.012 (0.008) | −0.003 (0.008) |

Event study (base cohort 2019): 2012 +0.020, falling to ≈ 0 by 2014–2019 (n.s.); cohort 2020 −0.001; cohorts
2021 / 2022 −0.014 / −0.010 (both n.s.).

- **Exit responds only weakly:** about −1.2 pp per SD on a 43% base (−3% relative), significant only when pooled;
  yearly post coefficients are not. Homonyms do not drive it.
- Concentrated in **university** inventors; firms show nothing (as for patents, note 11 holder types).
- Raw rates: in the most-banned tercile continuation stayed at 0.41–0.42; in the least-banned it rose from 0.44 to
  0.48. Again a relative pattern: low-coverage fields kept and attracted more inventors.

## Reading

1. The patent decline in banned fields is mostly an **extensive-margin** story: fewer inventors, both fewer new
   ones and fewer returning ones, plus a smaller drop in output per inventor.
2. It is **not an exodus of incumbent inventors** visible in Russian data: continuation falls only slightly, and
   nationally inventors keep filing at higher rates than before. Reduced entry matters as much as exit.
3. Emigration cannot be identified from Rospatent. The relevant emigrants may be people who never patented, or
   who stop filing; a destination test needs foreign patent offices (EPO/USPTO/PCT via Google Patents BigQuery,
   Latin-script names, matching on co-inventors and fields) or OpenAlex affiliation changes for researchers.

## Open

- Field switching: do continuing inventors move from banned to unbanned fields (exposure at t vs next active year)?
- Destinations: Russian-address inventors 2015–21 reappearing abroad 2022+ in PCT/EP/US filings; OpenAlex movers.
- Entry by holder type (are universities recruiting fewer new inventors into banned fields?).
