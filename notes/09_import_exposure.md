# Import exposure by technology field and the first stage (import-substitution design)

Session 4, 12 Nov 2026. Scripts: `scripts/data/15_build_ru_imports.py`, `16a_export_concordances.R`,
`16_hs_field_maps.py`, `17_build_field_exposure.py`, `scripts/analysis/14_import_exposure_first_stage.R`.
Figures: fig26 (first stage) and fig27 (agreement of the two maps). Decisions I1–I2, M1–M2 and E1–E4 are in
`notes/data_decisions.md`.

## Data

- **Trade: CEPII BACI, HS 2007, release 2026-01 (years 2007–2024).** BACI reconciles importer and exporter reports
  from UN Comtrade. After 2021, Russia's imports come from partners' reports.
  - Russia's imports, $bn: West (2022 coalition) / China / others
    - 2013: 195 / 54 / 79
    - 2021: 139 / 73 / 72
    - 2024: 44 / 115 / 42
  - Western share of imports: 60% (2011–13), 49% (2021), 22% (2024).
  - "Others" fall after 2022, although re-exports through Kazakhstan, Belarus, Armenia and others rose. Those
    countries report poorly, so BACI probably undercounts parallel imports.
- **Product → technology field: two maps, used to check each other** (the user's choice).
  - **Product-name map.** Russian TN VED product names (tws.by list, 13,294 ten-digit codes) are run through the
    title classifier from note 08. Each HS6 product gets probabilities over the 35 fields. HS 2022 codes are
    converted to HS 2007 with the R package `concordance`.
  - **Industry map.** HS07 → ISIC Rev.4 (`concordance` 2.1.0, equal weights) → NACE Rev.2 group → 35 fields, using
    the Dorner & Harhoff (2018, *Research Policy*) table. That table gives the share of each industry's patents in
    each field and is estimated from German inventors linked to their employers (IAB FDZ Methodenreport 07/2017,
    open). The Eurostat/KU Leuven IPC–NACE2 table was the first choice, but its only copy (on the EPO forum) is
    offline. The Lybbert–Zolas ALP files are also offline (WIPO pages return 404).
  - Both maps cover 99% of import value.
  - Agreement at the product level is low: same top field for 29% of HS codes, weight correlation 0.47. The
    industry map spreads each product over all fields its industry patents in.
  - Agreement at the field level is reasonable:
    - Western import share, 2011–13 / 2019–21: correlation 0.74 / 0.81.
    - Realized fall in Western imports after 2022: correlation 0.74 (rank correlation 0.72).

## First stage: does the pre-period Western share predict the loss of Western imports?

PPML of imports by field and year on WesternShare(z) × year, with field and year fixed effects and SEs clustered by
field. Sample: manufactured goods, HS chapters 28–97.

| Event | Western imports after the event | Chinese imports | All imports |
|---|---|---|---|
| 2014 (share fixed 2011–13) | ~0 in every year, both maps | ~0 / small + (industry map, 2016–19) | ~0 |
| 2022 (share fixed 2019–21) | **positive**: +0.15 / +0.25 / +0.34 per SD in 2022/23/24 (industry map; the 2024 CI excludes 0), product-name map similar but CIs include 0 | positive: +0.13 to +0.32 by 2024 (CIs exclude 0) | ~0 |

So a **higher pre-2022 Western share predicts a *smaller* loss of Western imports**. The pre-period share is not
a valid shock measure for 2022, and it is no shock measure at all for 2014.

**Why: the 2022 shock was selective.** Log change in Western imports from 2019–21 to 2023–24 (industry map; the
product-name map gives a similar ranking):

- **Largest losses, −1.4 to −1.8** (−75 to −85%): micro/nano, semiconductors, telecom, engines, digital and basic
  communication, transport, mechanical elements, electrical machinery.
- **Smallest losses, −0.2 to −0.7:** medical technology, pharmaceuticals, analysis of biological materials,
  biotechnology, basic materials chemistry, organic fine chemistry.

The second group has the highest pre-period Western shares, and it is largely covered by the humanitarian
exemptions (medicines, medical devices). In fact, the pre-period share correlates +0.5 with the realized change
(i.e. smaller losses).

**China replaced most of the lost supply in engines (+0.9) and transport (+1.0), but not in telecom or electronics.**
In those fields Chinese imports barely rose, and total imports fell by 25–45%. That is where an unfilled gap, and
so an import-substitution incentive, would be largest.

**Link to the patent descriptives (fig25), not tested.** Domestic patenting rose after 2022 in medical technology,
biotech and pharma, which are the fields that lost the *least* Western supply. Telecom and semiconductors, which
lost the most and were not replaced, show no rise. So far this does not look like import substitution driven by
the loss of supply. More likely candidates are demand-side or state programmes (pharma localization, healthcare
procurement), but this is untested.

## Implications for the design

1. **Do not use the pre-period Western share as treatment.** The treatment has to measure what was cut off.
2. **Candidate treatment: legal ban coverage** (the Kantor–Whalley logic). This is the share of a field's
   pre-period Western imports that fall under the EU export bans (Annexes XXI/XXIII of Reg. 833/2014, as
   amended) and the US/EU/UK/JP Common High Priority List. It is sender-defined and pre-determined. The first stage
   should then be strongly negative for Western imports.
3. **Realized loss** (`dlog_west`, `dlog_total` in `field_exposure.csv`) is useful descriptively and as the
   endogenous variable in an IV with ban coverage as instrument. It is not exogenous on its own.
4. **Separate "lost and replaced" from "lost and not replaced".** Use the realized change in *total* imports
   (`dlog_total`), or the Chinese replacement, as a second dimension. The substitution motive should be strongest
   where total supply fell.
5. **2014 has no field-level import shock** (the ruble devaluation hit all fields alike). For 2014, field
   variation has to come from the narrow oil-technology controls (E21B, already in `ru_patents_e21b_year.csv`)
   or from knowledge exposure.

## Outputs

- `data/clean/ru_imports_hs6.parquet`: Russia's imports by HS07 product × West/China/other × year.
- `hs07_field_text.csv`, `hs07_field_industry.csv`: product → field weights.
- `field_imports_year.csv`: imports by field × year × map × sample.
- `field_exposure.csv`: pre-period shares, size, and realized changes by field.
- `output/tables/import_first_stage.csv`, fig26, fig27.
