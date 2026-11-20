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

## Other input-output sources and IPC -> industry links (20 Nov 2026)
- **Rosstat** basic "затраты-выпуск" tables (2011, 2016; 2021 in preparation): the site's TLS chain is signed by the
  Russian state CA, not trusted on this machine; not worked around. User could download by hand
  (rosstat.gov.ru/statistics/accounts). Detail: 2016 tables recalculated to OKVED 2 / OKPD 2.
- **OECD ICIO** (45 ISIC industries, Russia included): oecd.org returns 403 to scripts; manual download only.
- **EXIOBASE 3.11.2** (Zenodo record 23039074, non-commercial academic licence, LICENSE.txt in data/raw/exiobase/):
  downloaded IOT_2019_pxp.zip (285 MB). 49 regions x 200 products, M.EUR. Manufacturing products are at the old NACE
  Rev. 1.1 2-digit level (29 machinery, 30 office machinery/computers, 31 electrical, 32 radio/TV/communication,
  33 instruments, 34 motor vehicles, 35 other transport); pharma is inside "Chemicals nec". Too coarse to separate our
  55 NACE 3-digit industries within a division, but it gives Russia's own sourcing by origin. 2019, share of Russian
  sectors' manufactured intermediate inputs: computers 58% imported / 30% Western / 24% Chinese; electrical 38/21/10;
  radio-TV-telecom 31/17/6; instruments 35/19/7; motor vehicles 40/29/4; other transport 23/13/4; machinery 14/7/3;
  chemicals 6/3/1; basic iron and steel 13/5/2. Possible use: a Russia-specific, division-level input exposure (Western
  inputs x banned share) as a check on the BEA-based measure.
- **IPC -> industry:** no official Russian (Rospatent/Rosstat/HSE) IPC -> OKVED table found (searched in Russian and
  English). European alternatives: Eurostat/KU Leuven IPC v8 -> NACE Rev. 2 (2014; only copy on the EPO forum, offline
  in Nov 2026), Fraunhofer ISI (Neuhäusler, Frietsch & Kroll 2019, Discussion Paper 60; IPC 3-digit -> NACE 2-digit,
  tables inside the PDF), OECD Technology Concordance (Johnson 2002, old ISIC). Russian terms for the user's own search:
  МПК, ОКВЭД 2, ОКПД 2, «таблица соответствия», «переходный ключ».
- **Rosstat tables recovered (20 Nov 2026):** the live links return 404, but the Internet Archive (Wayback Machine) has
  copies. Downloaded to data/raw/rosstat_io/: baz_tzv-2021.xlsx (basic input-output tables 2021, archived 4 Apr 2025),
  baz-tzv-2016.xlsx, baz-tev-2011.xlsx. Also archived but not downloaded: annual supply-use tables tri-2012..tri-2020
  (61 x 61). The 2021 file has 13 sheets incl. «М-имп» (use of IMPORTED products, CIF, about 240 products x 125
  industries), «М-отеч» (domestic), «ТИоц» (total use, basic prices) and symmetric tables. 46 manufacturing industry
  columns: 3-digit for food (10.1-10.9), chemicals (20.1-20.6), rubber/plastics, glass, metals (24.1-3, 24.4, 24.5),
  medical instruments (32.5); 2-digit for electronics (26), electrical (27), machinery (28), vehicles (29), other
  transport (30); pharma (21) separate. 120 manufactured product rows (OKPD 2).
  Planned use: Russia-specific input exposure_j = Sum_p Mimp(p,j) x WestShare_p x banned_p / Sum_p U(p,j) over
  manufactured products (share of the industry's 2021 manufactured inputs that were imported from the West and banned),
  with WestShare_p and banned_p from our HS trade and ban data mapped to OKPD 2 (CPA = HS-based product groups).

## Russia-specific input exposure from Rosstat 2021 (20 Nov 2026; rule RU1; scripts 30, 18s; fig59; rosstat_input*.csv)
dep = share of the industry's 2021 manufactured inputs that were Western imports later banned; sh = banned share of its
Western imported inputs; west = Western import dependence regardless of bans. 55 industries in 29 Rosstat columns
(treatment level; SEs clustered by column). Values: pharma dep 0.027 (west 0.32, sh 0.09); electronics 0.122;
machinery 0.118; vehicles 0.117; other transport 0.106; medical instruments 0.099; electrical 0.093; steel 0.037.
corr(dep, output coverage) 0.38; corr(dep, BEA input) 0.65; corr(sh, BEA input) 0.74.

| Spec (PPML, industry + year FE, per SD) | term | beta (SE col) | RI p | pre-test p (Wald / boot) |
|---|---|---|---|---|
| dep alone (main) | dep | -0.059 (0.018) | 0.063 | 0.000 / 0.24 |
| sh alone | sh | **-0.069 (0.016)** | **0.045** | 0.005 / **0.83** |
| dep + west | dep | -0.066 (0.009) | 0.146 | 0.000 / 0.26 |
| dep + west | west | +0.040 (0.023) | 0.38 | 0.10 / 0.91 |
| dep + output | dep | -0.034 (0.021) | 0.138 | 0.000 / 0.31 |
| dep + output | output | -0.061 (0.031) | - | 0.31 / 0.91 |

- With Russia's own 2021 input structure, industries more exposed to banned Western inputs patented less after 2022:
  -0.06 to -0.07 per SD, the same size as the output and BEA-input measures.
- **Bans, not Western dependence:** controlling for Western import dependence (regardless of bans) leaves the banned-
  input effect at -0.066; dependence itself is +0.04 (n.s.). The effect comes from what was banned, not from relying on
  the West in general.
- **The inputs-vs-output horse race is not robust:** with BEA inputs, input exposure kept the effect (-0.050) and output
  dropped (-0.030 n.s.); with Rosstat inputs it is the reverse (output -0.061, p 0.05; input -0.034, p 0.11). The two
  channels cannot be separated with 55 industries and 29 treatment clusters.
- RI p-values are marginal (0.045-0.15): treatment varies over only 29 columns. The banned-share version (sh) has the
  cleanest pre-period (bootstrap 0.83).
- **Check: does unbanned Western access help?** (scripts/analysis/checks/18s_unbanned_western_inputs.R) Banned and
  unbanned Western inputs (west - dep; corr 0.02) in one model, per SD, PPML, clustered by Rosstat column:
  all 55: banned -0.046 (p 0.008), unbanned +0.035 (p 0.07); without pharma: -0.045 / +0.029 (p 0.37); without pharma,
  medical instruments, electromedical: -0.040 / **+0.001 (p 0.87)**; without food: -0.043 / +0.036 (p 0.08).
  => The positive "unbanned access" coefficient is pharma/medical (high Western reliance, exempt, university-driven
  growth); the banned-input effect is robust to every exclusion. No evidence that remaining access raised innovation.
