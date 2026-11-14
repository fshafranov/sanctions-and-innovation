# Hovhannisyan & Miromanova (2025): To innovate or not to innovate

SSRN 5177287, version of 28 Feb 2025, 32 pages, not peer reviewed. PDF: `papers/downloads/ssrn-5177287.pdf`.
Read 12 Nov 2026.

## Design

**Data**
- Rospatent invention applications, 2000–2023 (about 800k patents), monthly.
- Each patent is split across author countries: fractional count = share of authors from country j.
- Collapsed to **author country j × month**: 139 countries, about 40,000 observations.
- About a quarter of patents have no author country; these are **assigned to Russia** (footnote 4).

**Treatment**
- GSDB **V3**. `Sanct_country_ij × episode_date_it` = country j sanctions Russia in episode i, and the episode is in force.
- Three episodes: Georgia 2008–2011 (one sender), Crimea 2014– (40 senders), 2022– (45 senders).

**Estimator** (eq. 1)

  patent_jt = exp(α + Σ_i β_i Sanct_ij × Episode_it + COVID travel_jt + X_jy + γ_j + γ_t) · ε

- PPML.
- Country FE and month FE.
- Country-year controls added one by one: GDP, population, number of sanction measures, diplomatic disagreement,
  WTO/EU membership, education, COVID travel restrictions, Russia as sender, bilateral imports/exports, FDI.
- SEs clustered at **country-year**.

**Comparison groups**
- (i) All authors, including Russian ones.
- (ii) Foreign authors only.
- (iii) Sender countries vs BRICS.

**Extensions**
- US vs other senders.
- Sanction types: one type at a time, then all together.
- Joint patents (at least one Russian and one foreign author), with BRICS and US interactions.
- **Russian authors:** an interrupted time series (one series, linear trend with a break in 2014), because the DiD
  cannot identify a single unit.

## Results

- 2014 episode: −0.505 → −40% (Table 3, col. 10).
- 2022 episode: about −2.5 → −93% (col. 9).
- Similar in the foreign-only and BRICS samples.
- US senders are more negative than others.
- Types: trade sanctions are negative in both episodes. Arms and military sanctions are positive in 2014 and negative
  in 2022. **Signs flip** when all types enter together: financial is +0.73 and +1.74 with all types, but −0.50 and
  −2.16 alone.
- Joint patents with sender countries fall: −85% with the US and −54% with others in 2022. Joint patents with BRICS
  rise ("diversion").
- Interrupted time series: Russian authors' monthly patents drop by 168 at the 2014 break (significant at 10%), and
  the trend falls by 7.4 per month.

## Reading it critically

1. **What the DiD measures is foreign applicants leaving the Russian patent market, not Russian innovation.** The
   treated units are author countries such as the US and Germany, compared with non-sender countries. A 93% drop
   means that inventors from sanctioning countries stopped filing in Russia. That is the market-access / foreign-firm
   channel, the same as our non-resident series. The title and abstract read it as "innovation in Russia" falling.
2. **Russia's own inventors are covered only by the interrupted time series.** It is one series with a linear trend
   and no comparison group. 2014 also brought the ruble crash and a recession. The 25% of patents with no author
   country are assigned to Russia, and that share may change over time.
3. **Comparison-group trends.** Non-sender countries include China, whose filings grew everywhere over this period.
   A relative decline of sender countries partly reflects China's rise. The paper shows no event study, leads or
   pre-trend test.
4. **Clustering at country-year** with monthly data treats each country's 12 months in a year as one cluster.
   Treatment varies by country over years, so clustering by country (139 clusters) is the standard choice. The
   reported SEs are probably too small.
5. **Bad controls.** Bilateral trade, FDI and "diplomatic disagreement" are themselves outcomes of sanctions.
   Controlling for them absorbs part of the effect, or adds bias.
6. **Sanction types are not identified.** Within an episode, senders impose bundles of measures, so type dummies are
   almost collinear. The sign flips show this. "Arms embargoes encourage innovation" is not a credible finding. It is
   the same problem as our arms/travel "placebo".
7. **Sender ≠ intensity.** A country that joins a sanction regime is coded the same whether it is the US or Albania.

## What it means for us

- **Taken:** "applicants from sanctioning countries file less in Russia" (PPML DiD at the Rospatent office). Our
  non-resident result says the same thing at the country level.
- **Open:**
  1. The same office × origin design **across all targets** (Iran, Belarus, Venezuela, Syria, Myanmar, Russia) with
     WIPO data, done with an event study, leads, country clustering, and comparison groups that allow for China's
     trend.
  2. The **other direction:** residents of sanctioned countries filing **abroad**, and at home by technology field.
     This is closer to the target's own innovation, and the paper does not identify it.
  3. **Within-Russia variation** (technology fields by import dependence), so that the war and the recession are
     absorbed by fixed effects. Their interrupted time series cannot do this.
