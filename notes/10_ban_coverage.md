# EU ban coverage by technology field, and its first stage

Session 4, 12 Nov 2026. Scripts: `scripts/data/18_parse_eu_bans.py`, `19_build_ban_coverage.py`,
`scripts/analysis/15_ban_first_stage.R`. Figures: fig28 (event-study first stage) and fig29 (coverage vs realized
change). Decisions B1–B5 and C1–C3 are in `notes/data_decisions.md`.

## Why

The pre-2022 Western import share did not work as exposure (note 09): it is highest in pharma and medical goods,
which were largely exempt. Following Kantor & Whalley, the treatment is now defined by **what the sanctioning side
banned**: the share of a field's pre-war Western imports covered by EU export bans. These lists are written in
Brussels, are fixed in law, and are dated by package.

## Data

- **Source:** all 35 consolidated versions of Council Regulation (EU) No 833/2014 (12 Sep 2014 – 24 Jul 2026),
  downloaded from the EU Publications Office's official CELLAR API. The EUR-Lex web pages answer scripts with a bot
  check, so they were not used.
- **Export-ban annexes** (identified by the article each annex title cites):
  - X: oil refining / LNG
  - XI: aviation and space
  - XVIII: luxury goods
  - XX: jet fuel
  - XXIII and its lettered parts: industrial capacity, the bulk of the list
  - XXXV: firearms
  - XL: the G7 Common High Priority List, from Dec 2023
  - For 2014: Annex II, oil-industry equipment (an authorization requirement)
- **Not mappable:** Annex VII (advanced technology, the main 2022 electronics ban) defines items by technical
  description, with no customs codes. The Common High Priority List (Annex XL) contains the battlefield-relevant
  subset of those items with customs codes, but only from Dec 2023. So electronics bans enter **too late** in the
  dated series. The end-2023 measure is unaffected.
- **Code conversion:** CN codes are converted to HS 2007 using the vintage in force (HS2012 / HS2017 / HS2022).
  Each HS07 code gets the share of its source codes that are banned. Partial "ex" bans are flagged; the C2 variant
  drops them.

## Coverage

Share of Russia's 2019–21 Western imports of manufactured goods covered by the bans:

| End of | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---|---|---|---|---|
| Covered | 25% | 49% | 57% | 64% | 65% |

The 2014 oil list covered **1.4%** of 2011–13 Western manufactured imports. At most 4–9% of any field is covered
(metallurgy, civil engineering, machine tools).

**By field at end-2023** (industry map / product-name map; field-level correlation of the two maps 0.62):
- **Highest:** telecom 0.65/0.83, digital communication 0.65/0.81, semiconductors 0.58/0.72, computer technology
  0.56/0.71, transport 0.61/0.67, engines 0.61/0.57, machine tools 0.57/0.61.
- **Lowest:** medical technology 0.13/0.23, pharma 0.25/0.10, analysis of biological materials 0.29/0.20,
  biotech 0.35/0.13.

## First stage

PPML of imports by field and year on coverage(z) × year, with field and year FE and SEs clustered by field (35).
Manufactured goods.

| | 2022 | 2023 | 2024 | Pre-period |
|---|---|---|---|---|
| **Western imports**, industry map | −0.18 [−0.21, −0.16] | −0.31 [−0.33, −0.28] | −0.38 [−0.41, −0.35] | 2019–20 ≈ 0; 2015–17 +0.03 to +0.08 |
| **Western imports**, product-name map | −0.28 [−0.36, −0.19] | −0.48 [−0.57, −0.38] | −0.61 [−0.69, −0.53] | 2019–20 ≈ 0; 2015–17 +0.03 to +0.11 |
| Chinese imports | CIs include 0 in 2023–24 (both maps) | | | |
| **All imports**, product-name map | −0.12 | −0.06 | −0.08 (CIs exclude 0) | ≈ 0 |
| All imports, industry map | −0.08 | −0.02 | −0.02 (CI touches 0) | ≈ 0 |

- **Cross-section of fields:** coverage vs the realized log change in Western imports from 2019–21 to 2023–24 has
  correlation **−0.94** (industry map) and **−0.90** (product-name map). Coverage vs the change in total imports:
  −0.35 / −0.49. Coverage vs the old pre-war Western share: −0.45 / −0.62.
- **2014 oil list:** Western imports −0.04 to −0.07 per SD of coverage in 2015–19 (CIs exclude 0 in most years).
  This is a small shock.

**Reading.** Ban coverage is a strong, sender-defined predictor of which fields lost Western supply. China did
**not** replace disproportionately in banned fields, so these fields lost supply in net terms. That is the
condition under which import substitution should show up in domestic patenting.

**Caveats**
1. Mild pre-trend 2015–17: in later-banned fields, Western imports drifted down relative to others between 2017
   and 2021.
2. Bans are EU only. US/UK/JP lists overlap heavily but are not added.
3. "Others" (Central Asia, Caucasus, Turkey) are probably undercounted in BACI, so parallel imports may replace
   more than shown.
4. Annex VII electronics are dated Dec 2023 (B5).

## Next: the reduced form on patents

Domestic patents (`n_top`, field × filing year, 2015–2025) on coverage(z) × year, PPML with field and year FE,
base 2021:
- with and without the classifier's weak fields;
- with world patenting by field × year as a control;
- with randomization inference over fields;
- plus the IV version: realized West drop instrumented by coverage.

Import substitution predicts **β > 0** after 2022. Note 09's descriptives (patents rising in pharma/medical, the
*least* covered fields) suggest the reduced form may be ≤ 0.
