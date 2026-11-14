# Design D: maps of regional exposure and of post-2022 (and post-2014) changes in patents and papers (12 Nov 2026, session 3)

Design: `notes/04_regional_design.md`. Earlier results: `notes/05_design_d_first_results.md`. Data choices:
P1–P7, X1–X3, M1 in `notes/data_decisions.md`. Status: descriptive and exploratory; intervals are 95%.

Scripts: `scripts/data/11_parse_rospatent_register.py`, `12_build_region_panel.py`,
`scripts/analysis/10_region_maps.R`.
Figures: `fig12_region_exposure_maps`, `fig13_region_change_maps`, `fig14_region_change_ranking`,
`fig15_region_exposure_vs_change`, `fig16_region_patents_eventstudy`.
Tables: `output/tables/region_exposure_change_slopes.csv`, `region_patents_eventstudy.csv`;
data `data/clean/region_exposure.csv` (one row per region, every measure), `region_year_panel.csv`.

## 1. Data

**Rospatent register of granted inventions** (user's download, version 2 Nov 2026, 701 MB): 867,684 patents.
- Region from the 6-digit postal code of the correspondence address (P1). Postal blocks (first 3 digits) → region
  from the postal codes of 1,109 towns (arbaev/russia-cities, GitHub), 36 more blocks from the towns named in the
  addresses. Check: the block's region equals the region of the town named in the same address in **99.6%** of
  609,168 addresses. 96% of domestic patents get a region.
- Domestic = all holders Russian and no foreign priority (P2): 65% of grants filed since 2000.
- Patent-attorney addresses (P5): 13.5% of domestic patents. Dropping them hardly changes anything (correlation of
  regional changes with and without them 0.94).
- Mass filers (P6): Kvasenkov, Shchepochkina, Kochetov, Akhmedov dropped, as in D2.
- **Grant lags are short now**: domestic grants by filing year are ~15,000–16,800 for 2019–2024 and 15,200 for
  2025, so 2022–24 filings are close to complete. Comparison windows: 2019–21 vs 2022–24.

**Exposure to the West** (pre-2022; X1–X3):
- X1 science: coalition co-authored share of the region's small-team articles (OpenAlex, 2019–21).
- X2 invention: share of Russian-held patents filed 2012–21 with a coalition co-inventor or co-holder.
- X3 **trade: not built.** The only open source with region × partner country (RCSI/INID "Экспорт и импорт
  российских регионов 2016–2021", FCS data) is no longer publicly listed; the user could not get it for now.
  Regional Rosstat offices publish trade by country as PDFs per region (fallback, laborious).

Boundaries: GADM 4.1 level 1 (83 regions; Crimea and the annexed Ukrainian regions not shown or analysed).

## 2. Exposure maps (fig12)

- **Science exposure** is high in a few places with big-physics or foreign-partner institutes: Leningrad Oblast
  (PNPI Gatchina, 37%), Magadan (34%), Moscow Oblast (Dubna, Protvino, 30%), Karachay-Cherkessia (the SAO
  telescope, 27%), Kamchatka (23%), Tomsk (22%), Chelyabinsk (18%). Median region 6%.
- **Invention exposure** is low everywhere (median 0.1%; max 2.4%): Russian patents almost never have Western
  co-inventors. Highest: Karelia, Bryansk, Leningrad, Kaliningrad, Novgorod, Lipetsk (all near Europe or with
  Western-owned plants), Moscow 1.0%, Tomsk 0.9%.
- The two measures correlate 0.41 across regions.

**First stage (national):** Western-linked patents fell from 0.6% of Russian-held patents (2017–21) to 0.39%
(2022), 0.27% (2023), 0.20% (2024), 0.12% (2025 filings). Coalition co-authored small-team articles fell by a
third (2022–24 vs 2019–21: ×0.67) while China co-authored ones rose ×1.21.

## 3. What changed after 2022 (fig13, fig14)

National totals, 2022–24 vs 2019–21: domestic patents +2%; **university patents +19%**; firm patents +1%;
research-institute patents −5%; individuals −11%; small-team articles +3%. So the national shift is towards
university patenting (ministry targets), not firm inventing.

Regional changes relative to Russia (log points; regions with ≥ 30 patents in 2019–21):
- **Gained:** Vologda (+0.57; firms +0.76), Buryatia (+0.58, small base), Yamal-Nenets (+0.40),
  Kabardino-Balkaria (+0.39), Belgorod (+0.32), Perm (+0.21), Tyumen (+0.21), Sverdlovsk (+0.18), Krasnodar
  (+0.17), Tomsk (+0.17; firms +0.58), Tula (+0.16), Tatarstan (+0.10). Many are heavy-industry or oil-and-gas
  regions (Urals, West Siberia) and defence-industry regions (Tula, Perm, Sverdlovsk).
- **Lost:** Pskov, Jewish AO, North Ossetia, Lipetsk, Novgorod, Chechnya (all −0.4 or more, mostly small bases),
  Khabarovsk (−0.33), Chuvashia (−0.28), Nizhny Novgorod (−0.23), Ulyanovsk (−0.21), Altai Krai (−0.20),
  St Petersburg (−0.12), Moscow Oblast (−0.12). Moscow city +0.03.
- Moscow + St Petersburg + Moscow Oblast: 44.4% of domestic patents before, 43.4% after — a small shift away from
  the centre.
- Articles moved much less than patents (SD of regional changes 0.14 vs 0.23).

## 4. Exposure vs change (fig15, fig16)

- **Cross-section (fig15):** no relation between either exposure measure and the change in patents, firm patents
  or articles. All weighted slopes have intervals that include zero (table `region_exposure_change_slopes.csv`).
- **Event study (fig16; PPML, region and year FE, base 2021, per SD of exposure; 69–71 regions):**
  - Domestic patents: flat before 2022 for science exposure; after 2022 −0.01, **−0.035 (2023, −0.068 to −0.003)**,
    −0.01 (2024). One coefficient excludes zero; I would not read it as an effect. For invention exposure, a
    rising pre-trend (−0.09 in 2015 to 0) and nothing after.
  - Firm patents: wide intervals, nothing.
  - University patents: +0.06 to +0.09 after 2022 for both exposures, **2022 excludes zero for invention exposure
    (+0.074, 0.002 to 0.145)**; suggestive that exposed regions' universities raised patenting more.
  - Articles: strong pre-trend (exposed regions' relative output falling to 2021) that stops after 2022, as in note
    05. Not interpretable as an effect.

## 5. Reading

- Patents and papers did **not** fall in regions more tied to Western science or co-inventors. The tie itself was
  cut (first stage), output was not.
- Regional reshuffling after 2022 is real in size (regions moved ±20–60 log points) but is not explained by these
  exposure measures. The winners look like industrial, resource and defence regions, the losers like small or
  peripheral regions plus Nizhny Novgorod, Ulyanovsk, Chuvashia (machine building; aviation and car industry hit by
  component bans?) — a hypothesis for the trade and industry-mix measures, not a result.
- The measures in hand are knowledge-link measures. The substitution story is about **imported inputs and Western
  plants**, which these do not capture. That is why the trade measure (or an industry-mix shift-share) matters.

## 5a. The 2014 episode (same design; outputs suffixed `_2014`)

Windows: patents filed 2011–13 vs 2014–16; exposure from co-invention 2006–13 and co-authorship 2012–13 (the
OpenAlex region series starts in 2012). Event study 2008–2019, base 2013. Same 2022 coalition for exposure (the
2014 senders are a subset). Figures `fig12_..._2014` to `fig16_..._2014`.

- **National:** domestic patents −3% (2014–16 vs 2011–13); firms 0%, universities −3%. Moscow + St Petersburg +
  Moscow Oblast: 39.9% before and after.
- **Regions that gained:** Karelia, Tver, Vladimir, Arkhangelsk, Tyumen, Kursk, Belgorod, Krasnodar. **Lost:**
  Oryol, Mari El, Smolensk, Kurgan, Dagestan, Lipetsk, Murmansk, Krasnoyarsk, Chelyabinsk (firms −0.92),
  Ulyanovsk. The regional changes after 2014 and after 2022 are almost unrelated (correlation 0.13); the
  exposure measures are stable (science 0.85, co-invention 0.26).
- **Cross-section:** no relation between exposure and the change in patents or firm patents; articles grew less in
  exposed regions (both exposures; intervals exclude zero) — probably OpenAlex adding Russian journals, which
  helps regions with little international output, not a sanctions effect.
- **Event study, unlike 2022, points to a relative rise after 2014 in exposed regions:**
  - Invention exposure → domestic patents: +0.05 (2017, 0.01 to 0.08), +0.04 (2018), +0.06 (2019, 0.02 to 0.09);
    firm patents +0.08 (2015, 0.003 to 0.15) and +0.10 (2017, 0.03 to 0.17). Pre-period mostly flat 2009–11 but
    2008 −0.06 and 2012 +0.04, so part of it continues an earlier upward drift.
  - Science exposure → firm patents +0.12 to +0.15 in 2015–16 (intervals just include zero); university patents
    rise to +0.20 by 2019 (0.03 to 0.37). Pre-trend: 2008 −0.11 for all patents, −0.15 for firms.
  - Articles in invention-exposed regions fall steadily from 2014 (−0.06 to −0.16), same indexing caveat.
- **Reading (suggestive):** after 2014, regions with Western co-invention links (Karelia, Bryansk, Leningrad,
  Kaliningrad, Novgorod, Lipetsk, Moscow, Tomsk...) saw firm patenting rise a little relative to others, about 5–10%
  per SD. That fits the user's substitution idea for a mild shock with East Asian substitutes open; it is not
  visible in 2022. Part could be trend (2008 and 2012 leads). Next check: permutation inference and dropping Moscow.

## 6. Next steps

1. Trade exposure: (a) the user tries the RCSI/INID dataset again later; (b) fallback: Rosstat regional PDFs
   (exports/imports by country, 2019–21), or a shift-share from RFSD industry mix × national imports from the
   coalition by industry; (c) KSE "Leave Russia" plants located by region.
2. Defence-industry share by region as a control (2022 is also a military-spending shock).
3. IPC for post-2022 patents (search-platform API token, note 04 §4d) to test substitution in control-list fields.
4. Utility-model and software registers (same layout expected), where substitution should show first.
5. Capacity × exposure 2×2 on patents (decide the capacity measure first: fig12 D is one candidate).
