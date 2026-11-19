# Data decisions log

Every download and cleaning choice, with who decided. "User" means a decision made in chat on 11 Nov 2026; "Claude,
provisional" means a default that has not been confirmed yet (open points are at the end).

## Sources

| Source | What | How | Script | Date |
|---|---|---|---|---|
| GSDB V4 | sanction cases (case level, 1949–2023) | **obtained unchanged** via the GSDB request form (not redistributed; user, 11 Nov). SHA-256: `GSDB_V4.csv` ef9ed413…f3f | – | 11 Nov 2026 |
| World Bank WDI API v2 | patents (resident, non-resident; WIPO), journal articles (NSF), R&D % GDP and researchers per million (UNESCO UIS), high-tech exports (Comtrade), IP payments/receipts (IMF BoP), population, GDP per capita | `country/all/indicator/<code>`, 1990–2024; manifest in `data/raw/wb/manifest.json` | `scripts/data/01_get_wb.py` | 11 Nov 2026 |
| OpenAlex API | articles and reviews by institution country and year; same with ≥ 2 author countries | group-by queries, no API key (user: don't send an email); full counting; JG (Channel Islands) rejected by OpenAlex and skipped | `scripts/data/02_get_openalex.py` | 11 Nov 2026 |

| Penn World Table 11.0 (Feenstra, Inklaar & Timmer), via FRED | TFP at constant national prices `rtfpna` (2021 = 1), the PWT measure for comparisons over time within a country | FRED CSV per country (`RTFPNA<ISO2>A632NRUG`). The PWT bulk files on dataverse.nl are blocked for this network by bot protection (12 Nov 2026), and we did not try to get around it. 114 economies; **no TFP for Belarus, Syria, Myanmar, North Korea, Cuba** | `scripts/data/05_get_pwt_tfp.py` | 12 Nov 2026 |

| WIPO IP statistics, "Indicators by technology" | `wipo-data-patent-indicators.zip`: publications and grants by office × origin × field (35) × year, 2000–2022 (file dated Dec 2023) | downloaded from wipo.int/en/web/ip-statistics (link "Complete data sets for Indicators by class and by technology"), 12 Nov 2026; no Iran, Belarus or Venezuela office data | used in `scripts/data/07_build_field_panel.py` | 12 Nov 2026 |
| OECD Data Explorer, `DSD_PATENTS@DF_PATENTS_WIPO` | PCT, EPO and USPTO applications by inventor country × WIPO field × priority year, 2000–2022 | SDMX API (query in the script) | `scripts/data/06_get_oecd_fields.py` | 12 Nov 2026 |
| Google Patents Public Data (BigQuery) | Rospatent documents (`country_code = 'RU'`), filed 2000+: numbers, kind, dates, IPC, harmonised assignees, inventor countries | SQL via the user's own Google Cloud project `sanctions-innovation` (sandbox, OAuth login by the user); 25.9 GB scanned; **coverage ends May 2022** | `scripts/data/08_get_bigquery_ru.py` | 12 Nov 2026 |
| OpenAlex API, regions | Russian institutions with `geo.region`; articles/reviews by region × year × co-author group (all, 2022 coalition, China), each also for teams ≤ 50 authors | institutions by page (cursor paging needs a key since 2026); per region an OR filter on ≤ 100 institution ids (lineage); no API key | `scripts/data/09_get_openalex_regions.py` | 12 Nov 2026 |
| Rospatent open data (samples only) | invention register: column list and two byte-range samples (229 KB, 180 KB), scratchpad only; true file size 701 MB (page says 30.4 GB) | with the user's OK | – | 12 Nov 2026 |

Field-level co-invention is **not** in the public OECD aggregates (`DF_PATENTS_COINVENTOR` has partner country but
no field). Iran joined the PCT in 2013, so its PCT counts before 2014 are near zero for mechanical reasons.

The World Bank has no trademark series (`IP.TMK.RESD`) for Russia or Iran, so trademarks are not used.

## GSDB → country-year (`scripts/data/03_clean_gsdb.py`)

| # | Decision | By |
|---|---|---|
| G1 | Rows that list several targets are split into one case per target country | user |
| G2 | Non-state and bloc targets are dropped: EU, EEC, ECOWAS, EEU, Comecon, Balkans, League of Arab States, "Western countries", ICC Rome Statute signatories, terrorist organisations | user |
| G3 | "Yugoslavia" → Serbia (SRB) in all years; Hong Kong (HKG) and Palestine (PSE) are kept as their own units | user |
| G4 | **Western senders** = US, EU, UN, UK, Canada, Japan, Australia, Switzerland, Norway in all years ("broader Western group"). A case is Western if at least one of them is a sender | user |
| G5 | **Economic** case = trade or financial measure. **Placebo** = Western case with only arms, military, travel or other measures. "Any sender economic" = all senders | user (measure), Claude (placebo definition) |
| G6 | A case is in force in every year from begin to end, inclusive | Claude, mechanical |
| G7 | GSDB keeps historical names for present-day states. Mapped by name: South Vietnam → VNM, Yemen, North → YEM, Transjordan → JOR, Ceylon → LKA, Malaya → MYS, Malagasy Rep. → MDG (e.g. case 1364, "South Vietnam" 2022). Soviet Union → RUS. Czechoslovakia → both CZE and SVK. GDR, North Vietnam and Rhodesia cases all end before 1990 and are dropped | Claude, **provisional** for SU/CS (they only affect the 5-year clean window of 1995–96 events) |
| G8 | "Cyprus (Northern)" (case 179) is dropped as a non-state target | Claude |
| G9 | Measures per group (west_econ, west_placebo, any_econ): `n_active_*` = cases in force; `n_new_*` = cases beginning in t; `new_*` = 1 if any case begins in t (the onset coding); `episode5_*` = a case begins in t and none was in force in t−1..t−5 | user (three codings) |

Counts 1995–2023: 427 Western economic onset years (131 five-year-clean episodes, 124 countries ever under a case);
134 placebo onset years (72 episodes); 489 any-sender economic onset years (146 episodes).

## Panel (`scripts/data/04_build_panel.py`)

| # | Decision | By |
|---|---|---|
| P1 | Unit = World Bank economy (ISO3), aggregates dropped. Taiwan has GSDB cases but no WB data, so it drops out | Claude, mechanical |
| P2 | A missing WB value stays missing; it is not set to 0 | Claude |
| P3 | A year in which OpenAlex returns no works for a country is set to 0 works | Claude |
| P4 | Base sample: **median population 1995–2023 ≥ 1m, event years 1995–2023** (159 economies) | user |
| P5 | TFP merged by ISO3 × year; missing stays missing; outcome = log TFP (OLS) | Claude, mechanical (user asked for TFP) |
| O1 | OpenAlex restricted to `type:article|review` | Claude, **provisional** |

## Design A field panels (`scripts/data/07_build_field_panel.py`)

| # | Decision | By |
|---|---|---|
| F1 | Senders = GSDB 2014 Russia senders (cases 1004–1011; EU = EU28 incl. UK) | user |
| F2 | Dependence = senders' share of world PCT 2008–13 by field (z-scored); co-invention and imported inputs later | user |
| F3 | Domestic panel ends 2021 (WIPO 2022 incomplete for Russia) | Claude, data |
| F4 | Comparison countries: ≥ 500 resident publications/yr (domestic) or ≥ 100 PCT/yr (PCT) in 2008–13; Ukraine out | user (rule), Claude (thresholds) |
| F5 | Missing country-field-years inside a country's observed range = 0 | Claude |
| F6 | WIPO codes `**` and `YU` dropped | Claude, mechanical |
| F7 | Russia 2014 is the main episode; 2022 only in the PCT event study | user |

## Design D: Russian patents by field and type, regions (`10_build_ru_patent_fields.py`, `09_get_openalex_regions.py`)

| # | Decision | By |
|---|---|---|
| D1 | IPC → WIPO field via the WIPO concordance (main group first, else subclass); fractional counting over a document's distinct fields | Claude, standard |
| D2 | Drop individual mass filers with ≥ 1,000 invention grants filed 2005–17 (Kvasenkov ~29,000 canning recipes, Shchepochkina, Kochetov, Akhmedov); utility models cannot be filtered (no holders in Google's data) | Claude (rule) |
| D3 | Domestic inventions = all assignees RU (else inventors all RU); utility models not split by origin | Claude |
| D4 | Years: inventions filed 2005–17, utility models 2005–19 (grant lag and the May 2022 cut-off); applications (A) not used, because fast grants skip the A publication from 2014 | Claude |
| R1 | Region = OpenAlex `geo.region` of the institution (82 regions; names not yet matched to official codes) | Claude |
| R2 | Regions with > 100 institutions (Moscow, St Petersburg) keep the top 100 by works (OR-filter limit) | Claude, mechanical |
| R3 | Exposure = 2019–21 coalition co-authored share; capacity = 2019–21 output above the median; sample ≥ 200 articles/yr | Claude, provisional |
| R4 | Main version uses teams ≤ 50 authors (mega-collaborations drive co-authorship shares) | Claude, provisional |

## Fields imputed from titles (`14_title_field_classifier.py`, note 08)

| # | Decision | By |
|---|---|---|
| T1 | Labels: IPC (Google Patents, matched on registration number) → WIPO field (D1); multi-field patents enter training once per field, weight 1/k | Claude |
| T2 | Features: TF-IDF of the lower-cased title (ё→е), word 1–2-grams and character 3–5-grams, min_df 3 | Claude |
| T3 | Classifier: multinomial logistic regression (SGD, log loss, alpha 2e-6), local, no API | Claude (user agreed to a local simple model) |
| T4 | Validation: random 10% holdout 2005–17; out-of-time (train ≤ 2017, test 2018–21 with IPC) | Claude |
| T5 | Cross-fitting: 2000–21 labelled patents get out-of-fold predictions (5 folds); others from the model trained on all labelled 2000–21 | Claude |
| T6 | Main count = top predicted field (whole count); summed probabilities attenuate within-field changes (slope 0.55 vs 0.93) | Claude |

## Import exposure by field (`15_build_ru_imports.py`, `16_hs_field_maps.py`, `17_build_field_exposure.py`, note 09)

| # | Decision | By |
|---|---|---|
| I1 | Trade = CEPII BACI HS07, release 202601 (2007–2024); West = 2022 coalition as P3 (Taiwan = BACI 490); China = CHN+HKG+MAC | Claude |
| I2 | Russia = importer 643; values in thousand current US$ | Claude, mechanical |
| M1 | Two product → field maps, compared (user's choice): (a) title classifier on Russian TN VED product names (tws.by list), HS22 → HS07 via `concordance`; (b) HS07 → ISIC4 (`concordance` 2.1.0, equal weights) → NACE Rev.2 group → fields via Dorner & Harhoff (2018) vertical table (IAB FDZ MR 07/2017) | user (both), Claude (sources) |
| M2 | Eurostat IPC–NACE2 table not used (only copy on the offline EPO forum); ALP (Lybbert–Zolas) offline | Claude, data |
| M3 | **Bug fix (session 5, 18 Nov 2026):** ISIC4 groups that do not exist as NACE Rev.2 groups (ISIC 2100 pharma = NACE 21.1+21.2; ISIC 1701/1702/1709 paper = NACE 17.1/17.2; 2,035 HS–ISIC links) now use the Dorner–Harhoff 2-digit table. Before, these links were silently dropped and the HS code's remaining links renormalised (medicaments HS 3004 went ⅔ to medical technology via ISIC 3250); 8% of Western manufactured import value was affected. Industry-map coverage changes: pharma 0.25→0.08, biotech 0.35→0.19, organic fine chem 0.39→0.26; field correlation old/new 0.93 | Claude (found while explaining the merge) |
| SC1–SC4 | IPC subclass classifier (`14b_title_subclass_classifier.py`): labels = distinct IPC subclasses, weight 1/k; classes = subclasses with ≥ 200 labelled patents 2000–21; out-of-time validation (train ≤ 2017, test 2018–21); 3-fold cross-fitting; count = top predicted subclass | Claude |
| A1–A3 | Rospatent search platform API (`21b_get_rospatent_api.py`): user's own key from «Разработчикам» (env `ROSPATENT_TOKEN`, never in the repo); query q="*", country RU, kind C1/C2, one filing week per query, limit 500 + offset; weeks 2022–2026 first, then 2021 back to 1994; 1 request at a time, 1 s pause; full records kept (gz JSON). Test 1–7 Mar 2023: 355 documents, all matched to the register | user (key, priority, keep full records), Claude (query) |
| A4 | FIPS document pages (`21_get_fips_ipc.py`) not used: DDoS-Guard browser check on scripted requests (18 Nov 2026); nothing collected; not worked around | Claude |
| O1–O2 | Official-IPC panels (`23_build_official_ipc_panels.py`): API codes, else Google; fields via the Schmoch table, fractional over distinct fields (main) and first-listed code | Claude |
| RF1 | RFSD (`24_get_rfsd.py`, Hugging Face irlspbru/RFSD v3.1.0, CC BY 4.0): all identifier/descriptor columns + lines 1110, 1120, 1150, 1300, 1600, 2110, 2120, 2200, 2400, years 2011–2025; full yearly files downloaded one at a time and deleted after column extraction (disk had 13 GB free) | user (fetch), Claude (columns) |
| E1 | Pre-periods 2011–13 (2014 shock) and 2019–21 (2022), annual means | Claude |
| E2 | Main product sample = HS chapters 28–97 (drops food/agriculture, hit by Russia's 2014 counter-embargo, and fuels/minerals); "all" kept as a check | Claude, provisional |
| E3 | Exposure = Western share of imports mapped to the field; size variant = Western imports per domestic patent (log). **First stage fails for 2022 (sign reversed) and 2014 (zero), see note 09** | Claude |
| E4 | Realized change in West / China / total imports to 2015–16 or 2023–24 stored; descriptive, or the endogenous variable in an IV | Claude |

## EU ban coverage (`18_parse_eu_bans.py`, `19_build_ban_coverage.py`, note 10)

| # | Decision | By |
|---|---|---|
| B1 | Export-ban annexes of Reg. 833/2014 by the article in their title: II (Art. 3, oil, pre-2022 only), X (3b), XI and XX (3c), XVIII (3h), XXIII + lettered parts (3k), XXXV (2aa), XL (2/2a; 12g before mid-2025). Annex VII has no CN codes; import bans, entity lists, port access excluded | Claude |
| B2 | Codes = first table cell (or "ex" cell + next), 2–8 digits; prefix covers all 6-digit codes below it | Claude, mechanical |
| B3 | CN vintage by version date (HS2012 < 2017 ≤ HS2017 < 2022 ≤ HS2022) → HS07; share of source codes banned | Claude |
| B4 | Lists: oil2014 (Annex II, versions before 2022), eu2022 (all B1 annexes from 2022) | Claude |
| B5 | Annex XL counted from Dec 2023 as the CN-coded proxy for Annex VII electronics (ban dates too late) | Claude |
| C1 | Coverage = W-weighted share banned, W = 2019–21 (2011–13) Western imports; main year end-2023 | Claude (user chose ban coverage as treatment) |
| C2 | Variant without partial ("ex") bans | Claude |
| C3 | Samples as E2 (manuf main) | Claude |
| — | Source: CELLAR API (publications.europa.eu), not EUR-Lex pages (bot check) | Claude, data |

## Design D: Rospatent register, regions, maps (`11_parse_rospatent_register.py`, `12_build_region_panel.py`, `10_region_maps.R`)

| # | Decision | By |
|---|---|---|
| P1 | Region = postal block (first 3 digits of the address's postal code) → region from 1,109 towns' postal codes (arbaev/russia-cities) plus 36 blocks from town names in addresses (≥ 5 addresses, ≥ 70% agreement); 99.6% agreement with town names; Crimea/Sevastopol (295–299) set aside. GeoNames was the first choice but did not answer | Claude |
| P2 | Domestic = all holders (RU) (no holders: all authors RU) and no foreign Paris priority | Claude |
| P3 | Western co-invention = ≥ 1 RU author and ≥ 1 author from the 2022 coalition | Claude |
| P4 | Holder type by regex on the name: university, research institute/state science, firm, individual | Claude, provisional |
| P5 | Attorney address = "пат. пов" / "патентн" in the address; kept in the main counts, dropped as a check (r = 0.94) | Claude |
| P6 | Individual mass filers (≥ 1,000 grants filed 2005–17) dropped, as D2 | Claude |
| P7 | Patents dated by filing year; windows 2019–21 vs 2022–24 (2025 filings incomplete), and 2011–13 vs 2014–16 for 2014 (exposure: co-invention 2006–13, co-authorship 2012–13); regions with < 30 patents in 2019–21 left blank in change maps | Claude |
| X1 | Science exposure = coalition co-authored share of small-team articles 2019–21; blank on maps below 300 articles | Claude |
| X2 | Invention exposure = share of Russian-held patents filed 2012–21 with a coalition co-inventor or co-holder; blank below 100 patents | Claude |
| X3 | Trade exposure not built: RCSI/INID region × partner data not accessible (user, 12 Nov 2026) | user |
| M1 | Boundaries GADM 4.1 level 1 (83 regions; Crimea not shown); Albers equal-area, central meridian 100°E | Claude |

## Cross-country staggered DiD (`11_staggered_did.R`)

| # | Decision | By |
|---|---|---|
| S1 | Main method: staggered event studies (Callaway–Sant'Anna, Sun–Abraham, TWFE for comparison); local projections only as robustness | user |
| S2 | Treatment = first clean episode (case starts after ≥ 5 years with none) in 1995–2023, absorbing; never treated = no case 1990–2023; continuously sanctioned countries dropped | Claude |
| S3 | Event window −5..+8, base −1 (universal base period in C–S); counts log(1+y), PPML as variant | Claude |
| S4 | Synthetic DiD for single cases (Russia 2014, 2022; Iran 2012): own implementation of Arkhangelsky et al. (2021) Alg. 1; donors without a Western economic case in the window, close partners excluded; placebo inference | user (method), Claude (donors) |
| S5 | Cross-check with Python `synthdid` 0.10.1 (separate env, pandas 2.2.3, installed without its pins): SDID estimates identical; package SEs for SC/DiD not used (they re-estimate SDID) | user (package), Claude |
| S6 | Covariates for SDID: WDI bulk file (API down 12 Nov 2026); pre-sanction averages only; core 7 (log GDP pc, log pop, oil+gas rents, trade, FDI, manufacturing VA, urban), extended + tertiary, R&D; variants: residualised (year-specific coefficients, donors only) and closest-half donors | user (set), Claude (variants) |

## Open points (need your decision)

1. **Western targets.** The Western economic measure also contains trade disputes between Western countries and
   sanctions on democracies: France 1995/1998/2003, USA 2003, Canada 2003, India 1998 (nuclear tests),
   Korea 2023, Switzerland 2023. Keep them, or drop cases whose target is itself a Western or OECD country?
2. **G7.** Soviet Union → Russia and Czechoslovakia → both successor states (affects only 1995–96 clean windows).
3. **O1.** OpenAlex articles and reviews only, or all work types?
4. **OpenAlex coverage.** OpenAlex keeps adding journals, including Russian- and Persian-language ones, so country
   counts partly reflect indexing. Year fixed effects absorb the common part but not country-specific additions.

- **O3 (19 Nov 2026):** official Rospatent API codes now cover all filing years 1994-2026; the Google IPC fallback in
  script 23 is no longer used for 2010+ (share_api ≥ 0.986 every year). All official-IPC results were rerun (note 14, final update).

- **PC1 (20 Nov 2026):** pre-war controls for the field event study, fixed before estimation: university share of
  domestic patents (2015-19), Western share of total imports (2019-21, same map as Ban), foreign-holder share of
  granted patents (2015-19), log size (2015-19); each z-scored x year dummies (base 2021); each alone and all four
  together; all versions reported. Own pre-period growth is excluded (it is detrending). Script 26 builds them, 18m estimates.

- **DU1 (20 Nov 2026), 2014 dual-use exposure, fixed before estimation.** Source: Commission dual-use correlation table
  of 1 April 2014 (`data/raw/circabc/`, downloaded by the user from CIRCABC), the version in force when Reg. 833/2014
  Art. 2 (dual-use goods for military end-use/end-users) started (31 Jul 2014). TARIC 10-digit -> HS6 (CN 2014 =
  HS2012) -> HS07 via concord_hsvintage_hs07 (share = listed HS2012 codes / all HS2012 codes of the HS07 code).
  Two versions: **broad** (an HS6 counts if any 10-digit line is listed; upper bound) = main; **narrow** (only HS6 codes
  listed as a whole, TARIC ending 0000). Field exposure: Sum w(hs,f) W(hs) d(hs) / Sum w(hs,f) W(hs), W = 2011-13 Western
  imports, manufactured goods (HS 28-97), both maps, z-scored.
  Estimates: PPML, 35 fields, field + year FE, 2005-2021 (stops before the 2022 bans), base 2013, SEs clustered by
  field + pairs cluster bootstrap-t joint pre-test (2005-2012). Specs: dual-use alone (broad, narrow); dual-use + oil
  list jointly. Pooled: 2014-17 and 2014-21 vs 2005-13. Second question: in the main 2022 design (2015-2025, base 2021),
  does dual-use-2014 exposure x year absorb the 2015-21 drift? All versions reported.

- **IND1 (20 Nov 2026), industry-level design, fixed before estimation.** Unit = NACE Rev. 2 3-digit manufacturing
  industry (divisions 10-32; 33 repair/installation excluded).
  Outcome: domestic invention patents (official IPC, fractional over distinct subclasses, mass filers dropped, by filing
  year) -> industries with the Dorner-Harhoff horizontal table corrtab_ipc4_frac_w08_3 (share of each IPC subclass's
  German patents by industry), restricted to manufacturing industries and renormalised within manufacturing; subclasses
  not in the table dropped (share reported).
  Treatment: HS07 -> ISIC4 (R concordance), links to ISIC 33xx dropped, equal split over remaining links; ISIC4 -> NACE
  3-digit (= first 3 digits; where that group does not exist in NACE, equal split over the NACE groups of the same
  division). Coverage_i = Sum k W b / Sum k W, W = 2019-21 Western imports (HS 28-97), b = EU ban share end-2023. z-scored.
  Sample: industries with >= 10 patents/yr on average in 2015-19 and positive mapped Western imports.
  Estimation: PPML, industry + year FE (main) and industry + division x year FE (as Egorov et al.), 2015-2025, base 2021,
  SEs clustered by industry; event study with pairs cluster bootstrap-t joint pre-test; pooled Ban x Post with
  randomization inference (1,000 permutations). All versions reported.

- **IN1 (20 Nov 2026), input-based ban exposure, fixed before estimation.** Input structure: BEA 2017 detailed Use
  table, before redefinitions, producer prices (`data/raw/bea/AllTablesIO.zip`, apps.bea.gov), a proxy for how industries
  combine inputs (US technology). BEA detail codes -> NAICS 2017 (BEA's own list; ranges expanded) -> ISIC4 (R
  concordance, weights) -> for using industries NACE 3-digit as in IND1.
  Commodity ban share b_c = Sum_isic w(c,isic) * banned share of the ISIC4 product group's 2019-21 Western imports
  (HS -> ISIC4 without 33xx, end-2023 list). Only manufactured commodities (BEA codes in NAICS 31-33) with Western
  imports count as inputs.
  Input exposure_j = Sum_c U(c,j) b_c / Sum_c U(c,j), U = use of commodity c by NACE industry j (BEA industries mapped
  to NACE3 with ISIC weights). Main: all manufactured inputs; variant: excluding the industry's own product group.
  Estimation as IND1 (same 55 industries, PPML, industry + year FE, 2015-2025, base 2021): input exposure alone; output
  exposure alone; both in one model. Event study with bootstrap pre-test, pooled with RI. All versions reported.
