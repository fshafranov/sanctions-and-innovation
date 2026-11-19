# How the literature links trade shocks to patents, and where our ban-coverage measure fits

Session 5, 18 Nov 2026. References checked against OpenAlex/arXiv (research-desk lookup) unless marked.
Egorov et al. read from the PDF the user added (`papers/downloads/ssrn-5404040.pdf`, July 2026 version).

## 1. Egorov, Korovkin, Makarin & Nigmatulina (2026): what exactly they measure

"Export Sanctions: Rerouting, Disruption, and the Reach of Economic Warfare" (July 2026; earlier "Trade
Sanctions", BOFIT DP 11/2025).

- **Sanctions data:** export sanctions of 9 partners (Australia, Canada, EU, Japan, South Korea, Switzerland,
  Taiwan, UK, US; 35 countries), started from Alta.ru records and cross-checked against the legal texts. Unit:
  **country × 10-digit product** ("variety"), about 72,000 sanctioned varieties with 50 imposition dates. Where a
  ban is written as a text description (like our Annex VII), Alta.ru experts chose the matching 10-digit codes.
  Conditional bans (price thresholds) are treated as fully sanctioned.
- **Trade data:** transaction-level Russian customs records (with importer tax ID, INN), not public.
- **Firm data:** balance sheets of all Russian firms (~2.2 million per year), merged on INN.
- **Firm exposure (main):** Exposed_f = 1 if the firm imported at least one later-sanctioned country-product
  variety in Jan 2019 – Feb 2022 (2.4% of firms). Event study with firm and year FE, base 2021, plus year ×
  pre-war characteristics (importer/exporter status, 2-digit OKVED, targeted/financial/import sanctions,
  foreign-bank exit). SEs clustered by firm. A continuous version uses the share of the firm's pre-war imports in
  later-sanctioned varieties.
- **Industry exposure (their Fig. 6):** the revenue-weighted average, across an industry's firms, of the pre-war
  **share of imports in later-sanctioned varieties**, z-scored; 5-digit industry FE and **2-digit × year FE**;
  SEs clustered by 5-digit industry; 1,957 industries, 2017–2024. No pre-trend; 1 SD → about −10% sales and costs.

**Comparison with ours**

| | Egorov et al. industry version | Ours (notes 10–11) |
|---|---|---|
| Exposure | share of pre-war imports in later-sanctioned products | share of 2019–21 Western imports in banned products |
| Sanctioning side | 9 partners, country-specific | EU only, applied to all Western imports |
| Product level | HS10, from customs | HS6 (CN codes converted), from BACI |
| Weights | firms' own imports, revenue-weighted to industry | field's import composition (via product → field map) |
| Unit | 5-digit OKVED industry (~1,950) | WIPO field (35) |
| FE | industry + 2-digit × year | field + year (main); field + sector × year (16e) |
| Outcome | sales, costs (no patents) | domestic patents |

So **the construction is the same** (pre-war import share in later-banned products, z-scored, event study with
broad-group × year FE). Our differences: EU list only, public data, and technology fields instead of industries.
Their design has about 55 times as many treatment units; that is the main lesson for us.

## 2. Our measure is a shift-share exposure

Ban_f = Σ_p s_fp · b_p, with s_fp = field f's share of 2019–21 Western imports in product p, and b_p = 1 if p is
banned by end-2023. Shares × shocks = shift-share (Bartik). Two ways to justify it:

- **Identification from the shocks** (Borusyak, Hull & Jaravel 2022, *REStud*; arXiv 1806.01221): valid if the
  product bans are as good as random with respect to unobserved field trends, and there are many products with
  small shares. Fits our case: about 5,000 HS6 products, bans set in Brussels on military/dual-use grounds.
  Tests they recommend: balance of shocks on pre-war product characteristics; product-level ("shock-level")
  regressions; Herfindahl of shares (effective number of shocks).
- **Identification from the shares** (Goldsmith-Pinkham, Sorkin & Swift 2020, *AER*): requires the import shares
  themselves to be exogenous. Not our argument.
- **Inference** (Adão, Kolesár & Morales 2019, *QJE*): fields with similar import compositions have correlated
  errors; their SEs correct this. Our randomization inference permutes Ban_f across fields, which is a cruder
  version. Better: permute the product-level bans (b_p) and rebuild Ban_f.
- **Non-random exposure** (Borusyak & Hull 2023, *Econometrica* 91(6), doi 10.3982/ECTA19367; OpenAlex lists the
  authors wrongly, DOI checked): recentre the exposure by its expected value over counterfactual ban lists. Egorov
  et al. cite this for their network-exposure measures.

## 3. How trade-and-innovation papers link products to patents

| Paper | Shock | How patents are linked to the shock | Unit |
|---|---|---|---|
| Bloom, Draca & Van Reenen (2016, *REStud* 83(1); online 2015) | Chinese import competition, quota removal | patents → firms (EPO applicant names), firms → 4-digit industry; shock is industry-level import share | firm, industry |
| Autor, Dorn, Hanson, Pisano & Shu (2020, *AER: Insights* 2(3)) | China shock | US patents → firms (Compustat), firm industry exposure | firm |
| Lybbert & Zolas (2014, *Research Policy* 43(3); online 2013) | (concordance) | ALP: IPC ↔ HS/ISIC probabilities from keyword matching of patent text to product descriptions | concordance |
| Dorner & Harhoff (2018, *Research Policy*) [not re-checked] | (concordance) | IPC fields ↔ NACE industries, from German inventor-employer links | concordance |
| Liu, Liu, Makarin & Wen (HBS WP 25-004) [not re-checked] | 2007 US catch-all rule on China | controlled vs excluded products → technologies | product/technology |

**Two standard routes:**
1. **Through firms** (BDV, ADHPS): link each patent to its owner, the owner to its industry, and put the trade
   shock at the industry or firm level. No product→technology map is needed. This is the most standard route,
   and it is our planned firm-level design (holders → RFSD → OKVED).
2. **Through a concordance** (ALP or Dorner–Harhoff): map products to technologies. This is what we do now; our
   industry map is HS → ISIC → Dorner–Harhoff, and ALP (HS ↔ IPC directly) is the standard alternative.

## 4. Consequences for the paper

1. Present Ban_f as a shift-share exposure "following Egorov et al. (2026)", not Kantor & Whalley. Kantor &
   Whalley give only the logic (exposure defined by the other side's decision).
2. Add the shift-share checks: shock balance, effective number of products, permutation of product-level bans.
3. Get more treatment units: IPC subclasses via ALP (note 13) and firms via RFSD (route 1).
4. Firm vs university heterogeneity: Egorov et al. cover only firms; universities and research institutes are
   ours alone.

## 5. Literature on the 2014 sanctions and Russian innovation (web search 20 Nov 2026; abstracts only unless noted)
No study found that estimates the effect of the 2014 sanctions on Russian domestic patenting by technology. Closest:
- Duong, Ongena, Vu & Huynh (2025), "Sanctions and Knowledge Spillovers", Swiss Finance Institute RP 25-01: Russian
  patent filings ABROAD are processed more slowly in sanctioning countries and get fewer forward citations; Russia's
  counter-sanctions work the other way. Outcome = Russian patents in foreign offices, not domestic invention.
- Makkonen & Mitze (2023), The World Economy 46(10), doi 10.1111/twec.13421 (arXiv 2112.00564): EU-Russia
  co-publications fell about 15% after 2014 (15-70% in the preprint, by control group); channels include dual-use.
- Ahn & Ludema, "The sword and the shield" (CESifo WP 7620, 2019): firms targeted by the 2014 US/EU sanctions lose about
  a quarter of revenue; government-designated "strategic" firms are shielded. Firm finance, not innovation.
- Nigmatulina, "Sanctions and misallocation" (NBER conference paper): staggered US firm-level sanctions 2014-2020,
  600k firms, aggregate TFP effects. Not innovation.
- Import substitution after 2014: Simachev & Fedyunina (HSE chapter): results ambiguous, positive mainly in agriculture
  and food. Counter-sanctions (food embargo): Kuznetsova & Volchkova (2019, FREE policy brief / JNEA): consumer losses
  about 445bn roubles a year, few industries show positive import-substitution effects.
- Russian-language regional studies (e.g. Equilibrium 2018, doi 10.24136/eq.2018.023): no rise in regional innovation
  indicators 2013-2015. Low quality for identification.
Gap for this project: field-level domestic patents, 2014 (dual-use, partial) vs 2022 (broad) as two episodes with
opposite signs. Not yet checked with the reference-lookup tool; verify before citing.
