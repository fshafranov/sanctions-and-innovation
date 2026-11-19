# 15. Industry-level design (session 5, 20 Nov 2026)

Rule IND1 (notes/data_decisions.md). Scripts: scripts/data/28_industry_panel.py, scripts/analysis/18q_industry_design.R.
Figure fig57_industry_es; tables industry_design*.csv.

## Why
The field design needs a product -> technology link on the TREATMENT side (industry map or product-name map). Both are
imperfect: the HS -> ISIC link splits products over several industries, and about 20% of import weight went to
repair/installation industries (ISIC 33xx). Errors in the treatment attenuate the estimate. The industry design moves
the concordance to the OUTCOME side, where errors mostly cost precision:
- patents -> industries: official IPC subclass -> NACE 3-digit with the Dorner-Harhoff horizontal table (share of each
  subclass's German EPO patents made in each industry), manufacturing only, renormalised; covers 99.7% of patents
- bans -> industries: HS -> ISIC4 (repair/installation links dropped) -> NACE 3-digit; coverage = banned share of the
  industry's 2019-21 Western imports (end-2023 list)

## Sample
55 NACE 3-digit manufacturing industries (>= 10 patents/yr 2015-19), 19 divisions. Coverage mean 0.50, SD 0.32
(fields: SD 0.15). Pharma (211, 212) 0.001: medicines were exempt; electromedical (266) 0.006; basic metals, some
machinery and aircraft near 1.

## Results (PPML, 2015-2025, base 2021, per SD of coverage)
| FE | pooled | RI p | pre-test p (Wald / bootstrap-t) |
|---|---|---|---|
| industry + year | **-0.077** (SE 0.026, p 0.003) | **0.002** | **0.59 / 0.85** |
| industry + division x year | -0.019 (SE 0.025, p 0.46) | 0.28 | 0.02 / 0.60 |
| OLS log(1+n), industry + year | -0.025 (p 0.07) | | |
Event study (industry + year): pre 2015-20 +0.01 to +0.03, all CIs include 0; post -0.035, -0.075, -0.067, -0.072
(all significant). Leave-one-division-out -0.056 to -0.101; without pharma (division 21) -0.056, SE 0.036 (CI includes 0).

## Reading
- The field result replicates with a different link on both sides and a flatter pre-period (no correction needed).
- The effect is between broad branches (divisions), not between related industries within a division (same as the
  subclass-within-field null).
- Pharma (unbanned, growing, university-heavy) vs heavily banned metals/machinery carries much of the contrast in both
  designs.
- **What "coverage" measures:** the banned share of the products an industry MAKES (Russia's imports of its products),
  not of the inputs it USES. Pharma's inputs (lab instruments HS 9027, reagents) were partly banned but are assigned to
  the instrument industry. Egorov et al. measure firms' own imports (mostly inputs). Next: input-based exposure from an
  input-output table (Rosstat or OECD ICIO): industry i's exposure = Sum_p use_{p,i} x banned_p / Sum_p use_{p,i}; run
  output and input exposure side by side (competition/substitution channel vs lost-inputs channel).

## Input vs output exposure (20 Nov 2026; rule IN1; scripts 29a-c, 18r; fig58; input_exposure*.csv)
Input exposure = banned share of what the industry BUYS: BEA 2017 detailed use table (US input structure as proxy)
x banned share of each commodity's 2019-21 Russian Western imports (end-2023). corr with output exposure 0.61 (55
industries). Largest shifts: electromedical 266 0.006 -> 0.52; pharma 211/212 0.001 -> 0.085; motor vehicles 291
0.87 -> 0.45.

| Spec (PPML, industry + year FE, per SD) | term | beta (SE) | RI p | pre-test p (Wald / boot) |
|---|---|---|---|---|
| output alone | output | -0.077 (0.026) | <0.001 | 0.59 / 0.88 |
| input alone | input | **-0.067 (0.009)** | 0.003 | 0.000 / 0.10 |
| input excl. own products | input | -0.058 (0.009) | 0.025 | 0.000 / 0.07 |
| both together | output | -0.030 (0.039) | 0.42 | 0.06 / 0.59 |
| both together | input | **-0.050 (0.023)** | 0.14 | 0.000 / 0.16 |

- Each measure alone gives a similar effect (-0.07 per SD); input exposure is much more precise (SE 0.009).
- In the horse race, input exposure keeps most of its effect (-0.050, clustered p 0.03) and output exposure drops to
  -0.030 (n.s.): suggestive that lost INPUTS, not lost competition from Western products, carry the effect. Not
  decisive: RI p for input in the joint model 0.14, and the two measures correlate 0.61.
- Input exposure's pre-period is less clean (pre coefficients +0.01 to +0.03 tightly estimated; clustered Wald rejects,
  bootstrap 0.10). Excluding the industry's own products barely changes it.
- Caveat: US input structure. Check with the OECD ICIO (Russian Western-sourced inputs, ~17 manufacturing industries)
  if this becomes a main result.
