# Design D: regional variation in Russia (and Iran) — substitution here, decline there (12 Nov 2026)

Status: proposal for discussion, plus a data check. Nothing estimated. "(checked)" = verified on 12 Nov 2026;
"(check)" = not yet verified.

## 1. Idea

The user's hypothesis: the same sanctions shock produces **import substitution** (more inventing) in some regions
and **decline** in others. In the framework of `02_theory_and_design.md` §2 the two channels have opposite signs and
can cancel in national totals and in field totals (one reading of the Design A null for 2014). Regions differ in
both things that decide the sign:

- **Exposure** — how much the region depended, before the sanctions, on inputs, plants, markets and co-authors
  from the sanctioning coalition (incl. extraterritorial controls, §6 of the design memo).
- **Capacity** — whether the region can produce substitutes: R&D staff, engineers, universities, existing domestic
  producers of the blocked goods.

## 2. Predictions (2×2)

| | low capacity | high capacity |
|---|---|---|
| **high exposure** | decline (inputs and partners lost, nobody to substitute) | rise in *substitute* fields; ambiguous total |
| **low exposure** | little change (comparison group) | little change; maybe rise if state money for substitution goes to capacity |

Sharper versions:
- Substitution should show up in **fields/classes that replace the blocked imports** (control-list goods,
  machine tools, electronics, software), not in all fields.
- Substitution should show up more in **utility models and software registrations** (cheap, incremental, fast) than
  in inventions, at least in the first 2–3 years.
- Decline should be faster (1–2 years); substitution slower (2–5 years).

## 3. Specification (event study)

Unit r = region (85 subjects; drop or separately handle the four annexed Ukrainian regions and Crimea/Sevastopol),
optionally × field k.

  y_rt = Σ_τ β_τ · 1[t = τ] · Exp_r + Σ_τ δ_τ · 1[t = τ] · Exp_r · Cap_r + Σ_τ θ_τ · 1[t = τ] · Cap_r + α_r + γ_t + X_rt + ε

- Region × field × year version: region×year and field×year fixed effects, so the identifying variation is
  exposure of the field in the region (shift-share).
- Events: 2022 (main), 2014 (smaller; narrow export controls, East Asian substitutes open).
- Leads τ < 0 for pre-trends; no pooled post-dummy if leads are off (user preference).
- Inference: permutation of exposure across regions (as in Design A); shift-share inference (Adão, Kolesár and
  Morales 2019; Borusyak, Hull and Jaravel 2022) if exposure is built from industry mix; Conley or federal-district
  clustering for spatial correlation.

## 4. Data (Russia)

| Purpose | Source | Status |
|---|---|---|
| Patents, utility models, software, by applicant | Rospatent open data: open registers of inventions (CSV; page says 30.4 GB, **server reports 701 MB**), utility models (10.7 GB), computer programs (7.9 GB), databases, IC topologies; monthly updates, versions back to Aug 2022; CC BY 3.0. `rospatent.gov.ru/opendata`, dataset `7730176088-iz` | **Exists (checked).** Column list read (see §4a): correspondence address yes, **IPC no**, granted patents only. Plan: stream and keep only needed columns, so the 30 GB file is never stored |
| Rospatent statistics | Open data sets "use of IP by federal district" and "by economic activity" (CSV, updated Apr 2026) | Exists (checked); federal districts only (8 units), so context, not the main outcome |
| Regional innovation indicators | Rosstat: "Regions of Russia" yearbook; EMISS/fedstat: advanced production technologies developed/used, R&D staff and spending, share of innovating firms, patent applications by region | Regional Rosstat offices publish 2023 figures (checked for several regions); a full regional series on fedstat (check) |
| Publications | OpenAlex institutions have `geo.region`: 2,190 Russian institutions in 82 regions; 579 Iranian institutions in 31 provinces (checked) | Region names need a crosswalk to official codes ("Rostov", "Kuzbass", "St.-Petersburg") |
| Firm R&D, intangibles, location | RFSD (Bondarkov, Ledenev and Skougarevskiy 2025): all firms' financial statements, **2011–2025**, Parquet on Hugging Face/Zenodo, `region`, `region_taxcode`, geocoded address of incorporation, OKVED. Licence CC BY 4.0 (README text; one badge still says CC BY-NC-SA) (checked) | Address = incorporation, not plant (Rosneft example in README). Balance-sheet line 1110 (intangible assets) and 1120 (R&D results) are candidate outcomes (check coverage) |
| Exposure: regional imports | RCSI "Export and import of Russian regions: customs statistics by product, 2016–2021" (CC BY-SA, data.rcsi.science, needs registration) | Found in search; page did not load, so **partner-country detail unchecked**. FCS stopped publishing in April 2022; pre-2022 is all we need |
| Exposure: Western plants and exits | KSE Institute "Leave Russia" (leave-russia.org), partly based on the Yale CELI list | Browsable; bulk download unclear (check). Locate the subsidiaries in RFSD to get regions |
| Exposure: industry mix (shift-share) | RFSD employment/revenue by region × OKVED, × industry dependence (OECD ICIO, control-list HS codes) | Builds on Design A/C exposure measures |
| State-led substitution | Industrial Development Fund (FRP) loans: >60% labelled import substitution, projects in ~79 regions | No open project-level list found (check fondprom.ru) |

### 4a. Rospatent invention register: what the columns allow (checked 12 Nov 2026)

Structure file `structure-20180828.csv` (7 KB, cp1251). 48 columns. Useful ones:
`registration_number`, `registration_date`, `application_number`, `application_date`, `authors`,
`patent_holders`, `correspondence_address`, `paris_convention_priority_country_code`, `pct_application_*`,
`ea_application_*`, `expiration_date`, `actual`, `publication_url`.

Consequences:
1. **Region:** only from `correspondence_address`. For Russian applicants this is often their own address, but it
   is a patent attorney's address when one is used (attorneys sit mostly in Moscow), which biases towards Moscow.
   Fixes: (a) Russian postal code → region; (b) match `patent_holders` to RFSD/EGRUL firms by name and use the
   firm's registered region; universities and research institutes by name; (c) flag addresses containing
   "патентн", "ООО ... патент", known attorney firms. Size of the problem to be measured on a sample.
2. **Field:** no IPC in the register. Get IPC by patent number from Google Patents Public Data (BigQuery,
   `patents-public-data.patents.publications`, country_code = RU, SQL) or from each `publication_url` (too many
   pages to scrape). BigQuery needs a Google account; the free tier covers this.
3. **Granted patents only, not applications.** Use `application_date` for timing; recent years are truncated by the
   grant lag (roughly 1–2 years), so 2024–2025 filings are under-counted unevenly. Handle with year × field effects
   and by dropping the last years, or by modelling the lag from earlier cohorts.
4. **Foreign vs domestic:** `paris_convention_priority_country_code` and PCT entries identify foreign-origin
   patents; the address also shows the country. Keep only Russian-origin for the main outcome; foreign filers by
   region are a Design B-type outcome.
5. Utility models and software registers probably have the same layout (check their structure files).

### 4b. Sample of the data file (12 Nov 2026, with the user's OK)

Two byte-range samples of `data-20261102-structure-20180828.csv` (UTF-8 with BOM, comma-separated, sorted by
patent number): first 229 KB (Soviet-era patents, mostly empty rows) and last 180 KB (166 patents, nos.
2,872,645–2,872,810, granted 2026, filed 2019–2026). Kept in the session scratchpad only, not in `data/raw`.

Recent patents (n = 166):
- **Address:** 166/166 have a 6-digit postal code → region is mechanical.
- **Address type:** 146 own/in-house address (university patent office, firm, the inventor); 8 Russian holders via a
  patent attorney (5%; Moscow, St Petersburg, Obninsk); 12 foreign holders or foreign priority (7%), nearly all via
  Moscow attorneys — these are dropped from the domestic outcome anyway. 61/166 addresses are in Moscow.
- **Holder type (rough regex):** universities ~26%, research institutes and state bodies ~19%, firms ~17%,
  individuals/other ~38%. Implication: university patenting (driven by ministry targets) is a large share; the
  substitution test should be run on **firm** patents separately.

So the attorney problem is small for Russian applicants; postal code → region is good enough for a first pass, with
the holder-name match to RFSD as a robustness check.

**Bottleneck: download speed.** The server delivered 2–13 KB/s and reset the connection. The file is 701 MB
(`Content-Length` 700,843,804; the "30.4 Гб" on the page is wrong), so at that rate 15 hours to 4 days with a
resumable download; feasible overnight. Options:
(a) byte-range requests for the tail only (patents granted since ~2012), with resume — size of that tail unknown;
(b) Google Patents Public Data on BigQuery for RU grants (number, dates, IPC, assignee names; no addresses), with
    region from holder-name matching (RFSD/EGRUL, university list) — needs the user's Google account;
(c) ask FIPS (helpdesk@rupto.ru) for a smaller extract or a faster mirror — the user would have to send this.

### 4c. Trial run: Google Patents Public Data on BigQuery (12 Nov 2026)

`scripts/data/08_get_bigquery_ru.py`, user's own project `sanctions-innovation` (sandbox). Query scanned 25.9 GB
(free quota 1,000 GB/month); 1,222,914 RU documents filed since 2000, 47 MB Parquet in `data/raw/bigquery/`.

- **Coverage stops in May 2022.** Publications per month: ~4,000 until April 2022, 701 in May, single digits from
  June 2022 on. Presumably the end of the EPO–Rospatent data exchange (EPO suspended cooperation in March 2022), not
  a fall in Russian patenting. By filing year, counts fall from 2019 on because grants of later filings were never
  received (median grant lag 1.6 years, p90 4.3, filings 2012–16).
- **So BigQuery cannot give the 2022 outcomes.** It is usable for 2000–2018 filings: the 2014 event and the
  pre-period (field structure by region, exposure measures).
- Kind codes: A (applications) 385k, C1/C2 (granted inventions) 583k, U1 (utility models) 196k.
- IPC: 100% of grants and utility models, 89% of applications.
- Holders: 89% of invention grants have a harmonised assignee (55% only Russian, 28% foreign or mixed, 17% none);
  **utility models and applications have none**. Names are transliterated and truncated ("TUL SKIJ GU",
  "RJAZANSKIJ NEFTEPERERABATYVAJU"), so matching them to RFSD for regions would be poor. No addresses.

Consequence: for the post-2022 period the Rospatent register (§4a–4b) is the only open source with regions, and IPC
for post-2022 patents has to come from elsewhere: the FIPS publication pages (`publication_url`) or the Rospatent
search platform's API (searchplatform.rospatent.gov.ru; registration needed, unchecked).

### 4d. Rospatent search-platform API (checked 12 Nov 2026)

- Endpoint `https://searchplatform.rospatent.gov.ru/patsearch/v0.2/...` is **live**: `/datasets/tree` answers
  HTTP 401 `{"error": "Authorization error"}` in ~5 s without a token. Access is by JWT token; the platform is free.
- What it can do (from the unofficial Ruby client `rospatent`, gemdocs.org; official docs not found): search with
  `limit`/`offset` paging, dataset `ru_since_1994`, filters on `classification.ipc_group`, `application.filing_date`
  (range), `date_published`, `kind` (e.g. A1, U1), `patent_holders`, `authors`, `country`; batch retrieval of
  documents; PDF download; HTTP 429 rate limiting (limits unknown).
- So it can in principle give IPC (and probably holders) for **post-2022** Russian documents, filtered to RU and
  paged by filing date. Whether results include addresses is unknown.
- **How to get a token: not found.** The web front-end did not render from here; no public developer page.
  Contacts listed on apiportal.ru: rospatent@rospatent.gov.ru, +7 499 240-5842. Registration may require a Russian
  account (Gosuslugi or a Russian phone) — unchecked; the user has to find out by signing up.
- Plan if a token is obtained: page through RU documents by filing month 2012–2026 (inventions, utility models,
  applications), keep number, kind, dates, IPC, holders; merge with the Rospatent register on registration number.

Mirrors (searched 12 Nov 2026): none found on Hugging Face, Zenodo, Kaggle or GitHub. Other places the data exist:
- PATSTAT (EPO; licensed — check whether LMU or the MPI for Innovation and Competition has it): RU documents with
  IPC; RU applicant-address completeness unknown.
- Geocoded patent addresses from PATSTAT (de Rassenfosse et al. 2019, *Scientific Data*, doi 10.1038/s41597-019-0264-6):
  RU coverage unchecked.
- Rosstat regional counts of patents issued (85 regions, at least 2012–2021): totals only, no fields — fallback
  outcome.
- Commercial: CAS STN RUFULL, Clarivate DWPI (no access assumed).

### 4e. Regional trade by partner: Rosstat regional publications (checked 12 Nov 2026)

- Regional Rosstat sites (NN.rosstat.gov.ru) time out from abroad; their files are reachable through the Wayback
  Machine (web.archive.org, `id_` URLs give the raw file).
- Six regions checked (Voronezh, Smolensk, Samara yearbook ch. 22, Kaluga, Kostroma, Yaroslavl, Krasnoyarsk):
  **all split trade only into "far abroad" vs CIS**, no partner countries. Samara's yearbook chapter goes back to
  the mid-2000s, so the far-abroad split exists before 2014, but "far abroad" includes China, Turkey etc.
- So Rosstat regional publications cannot measure exposure to the West. Country detail exists in regional customs
  bulletins (e.g. Volga customs for Chuvashia) and in the closed FCS portal stat.customs.gov.ru (Wayback unchecked),
  and in the RCSI dataset (2016-21, login).
- **FCS files in the Wayback Machine (checked 12 Nov 2026).** The FCS portal stat.customs.ru was a JavaScript app; its
  data were never archived. But the FCS published regional summary spreadsheets (`WEB_UTSA_SRF.xls(x)`, "Итоги
  внешней торговли субъектов РФ"), and the archive holds them for **2011–2022** (old site customs.ru/attachments,
  e.g. "Субъекты РФ 2012 год.xls" with 2011 and 2012; new site customs.gov.ru/storage, monthly/annual 2017–2022).
  Content: every region × exports/imports, split **far abroad vs CIS** (US$ m); some years add a sheet by
  **product group × region** (e.g. food, machinery), also far abroad vs CIS. **No partner countries.**
- Usable from these: pre-2014 regional imports from far abroad (2011–13; in 2013 the EU was ~42% of Russia's
  imports, China ~17%), and imports of machinery from far abroad by region where the product sheet exists — a
  proxy for dependence on Western equipment. Not a clean "West" measure.
- FCS open-data set `7730176610-p5statvneshtorgsub` ("Внешняя торговля субъектов РФ", published 2014–2020, CSV;
  archived): same far-abroad/CIS split, no partner countries.
- **Papers that used region × partner-country data** (no open replication package found; ask authors):
  - Sokolova, Davidson & Mariev (2024), *Journal of Environmental Management*, doi 10.1016/j.jenvman.2023.120001:
    exports of 84 regions to 204 countries, 2013–2020 (Ural Federal University). Data availability statement unread
    (publisher page not reachable).
  - Kaukin & Idrisov (2013), Gaidar Institute WP 0088 / SSRN 2273162: imports of 80 regions from 203 countries by
    354 border crossings, 2011 (FCS + Rosstat).
  - Izotov (2021), *Журнал НЭА* no. 4(52), 143–161: Far Eastern regions × partner countries, FCS forms 1-ТС/2-ТС.
  - *Вопросы статистики* (2020) 27(4): 80–87, on FCS regional trade statistics.

## 5. Threats

1. **Headquarters bias.** Patents and accounts are booked where the legal entity is registered (often Moscow).
   Use inventor or patent-holder addresses where available; for firms use subsidiaries' own registrations; run
   the analysis with and without Moscow, Moscow Oblast and St Petersburg.
2. **2022 is more than sanctions.** Defence orders (regions with arms plants), mobilisation (poorer regions),
   IT emigration (Moscow, St Petersburg, Novosibirsk). Control for or separately estimate a defence-industry share;
   emigration is a channel of its own (design memo §2).
3. **Capacity is not random.** High-capacity regions differ in many ways. The 2×2 compares *exposure effects* within
   capacity groups, so the threat is that exposure × capacity picks up something else (e.g. big-city trends). Leads
   and the 2014 episode help.
4. **Small N.** 85 regions, a few dominant; permutation inference and leave-one-out.
5. **Data after 2022.** Rosstat publishes less; Rospatent registers are complete (administrative data) but grant
   lags cut the last years — use application dates and filings, not grants.

## 6. Iran (31 provinces) — weaker version

- No open patent data from IRIPO found; Iranian patenting abroad is tiny.
- Usable: OpenAlex publications by province (checked: 31 provinces); Statistical Centre of Iran manufacturing survey
  by province × ISIC (access unchecked); register of "knowledge-based companies" by province (a fairly direct
  measure of state-backed substitution; access unchecked).
- Events 2012 (escalation), 2016 (relief), 2018 (reimposition): a switching test.
- Related: Cheratian, Goltabar and Farzanegan (2023, *World Economy*) survey firms in five provinces.

## 7. Next steps

1. Column list and sample read (§4a, §4b): postal code → region works; attorney addresses ~5%. Next: choose the
   download route (§4b: tail by byte ranges, BigQuery, or FIPS); IPC from BigQuery by patent number either way.
2. Pull OpenAlex works by Russian region × year × field (cheap, already in the pipeline) as a first descriptive look.
3. Exposure: register at RCSI and check partner-country detail; otherwise build the shift-share exposure from RFSD.
4. Decide the capacity measure before looking at outcomes (pre-2022 R&D staff per capita, engineering graduates,
   pre-period patents per capita).

## 8. Decisions for the user

1. Main outcome: Rospatent filings by region (if addresses exist) vs Rosstat indicators vs RFSD R&D lines.
2. Exposure: direct regional imports (RCSI) vs shift-share from industry mix.
3. Capacity measure (fix before seeing outcomes).
4. Treatment of Moscow/St Petersburg and annexed regions.
5. Download of the full register to an external drive (for an exact raw copy) or streaming only.
