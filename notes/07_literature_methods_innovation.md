# What the industrial-policy / innovation literature teaches about measurement and identification

Source: the 19 papers in `industrial policy seminar/01_Technology_and_innovation_policies/`, plus the
Kantor & Whalley "Moonshot" NBER WP in `papers/downloads/w31471.pdf`. That WP is the 2023/24 version
of the AER 2025 paper, which is also in the seminar folder, and the design is the same in both.
I read each paper's abstract, introduction and identification/empirical-strategy passages, not every appendix.

---

## 1. How innovation is measured

| Measure | Who uses it | Lesson |
|---|---|---|
| **Patent counts** by filing year, assignee/inventor location, technology class | almost all (Andrews, Gross & Sampat, Kantor & Whalley, Myers & Lanahan, Dechezleprêtre et al., Romero, Hanlon & Jaworski, Gentile, Alfaro et al.) | Date patents by **application/filing year**, not grant year. Assign them by **inventor location** for place-based questions and by **assignee** for firm questions. |
| **Quality-weighted patents**: forward citations, family size (number of countries filed in), KPSS-style market value | Dechezleprêtre et al. (citations, family size), Azoulay et al. (patent value ranges) | Tests whether the policy only produced low-value or "relabelled" patents. Always report a quality-adjusted version. |
| **Government-funded / interest patents** (federal-interest statements, Fleming et al. 2019) | Gross & Sampat 2023, Kantor & Whalley | Gives a direct treatment measure (share of a cluster's patents that were publicly funded). |
| **Publications** mapped to a controlled vocabulary (MeSH) | Gross & Sampat WP (CMR), Akerman et al. (Embrapa articles) | Gives "research space" units. Science outputs move before patents do. |
| **Linking inputs to outputs**: grant → publication → patent citation | Azoulay et al. (NIH) | Captures spillovers into *other* disease areas and at any lag. About half the effect falls outside the funded area. |
| **Linking inputs to outputs by text similarity** (TF-IDF / cosine between grant topics and patent abstracts) | Myers & Lanahan, Kantor & Whalley (CIA reports on Soviet space tech vs pre-1958 US patents), Alfaro et al. (LLM classification of rare-earth patents) | Does not need a citation trail. Myers & Lanahan show that citation-based linking misses about half of the spillovers. |
| **Plant variety releases (UPOV), crop-specific patents** | Moscona & Sastry, Akerman et al. | Sector-specific innovation counts outside the patent system. |
| **R&D inputs**: R&D expenditure, R&D employment from tax returns or surveys | Dechezleprêtre et al. (HMRC), Arnarson et al. (R&D survey + registers), Moretti et al. (OECD ANBERD/BERD) | Separate *input* (R&D) from *output* (patents), and from *productivity* (TFP, value added). |
| **Downstream real outcomes**: value added, employment, TFP, exports, RCA | Kantor & Whalley, Moretti et al., Juhász et al. (plant TFP), Wu, Alfaro et al., de Souza (skill shares) | Innovation policy should be judged on productivity as well as patent counts. |
| **Technology transfer / licensing contracts** | de Souza (Brazilian licence/technical-assistance registry) | Directly measures *imported* technology, which is the channel sanctions cut. |
| **Inventor panels** (disambiguated inventors, moves) | Kantor & Whalley (migration), Andrews (college yearbooks linked to patentees) | Separates "more invention" from "invention relocated here". |

**General lessons**
- Use several outcomes: R&D input, then patents, then quality-weighted patents, then productivity or output.
- Patent counts are skewed and full of zeros, so use **PPML / Poisson with FE** (Gentile; standard in this literature) or `asinh`/`log(1+x)` with care.
- Measure spillovers explicitly: by geography (Myers & Lanahan: recipients, then the US, then the world), by technology distance (text similarity bins), along supply chains (Wu, Alfaro et al.) and through firm networks (Arnarson et al.).

---

## 2. Units of observation

| Unit | Papers |
|---|---|
| **Region × technology field × year** ("cluster") | Gross & Sampat 2023 (county × patent category), Kantor & Whalley (county × 2-digit SIC), Akerman et al. (municipality × topic) |
| **Region × year** | Andrews (county), Schweiger et al. (municipality), Akerman et al. (municipality × census round) |
| **Technology area × year** (no geography) | Myers & Lanahan (text-defined tech areas), Azoulay et al. (disease × science × year, "DST"), Gross & Sampat WP (MeSH subject × year), Romero (cotton vs other textile patents), Hanlon & Jaworski (airframes vs engines) |
| **Firm × year** | Dechezleprêtre et al., de Souza, Arnarson et al., Gentile, Moretti et al. (French firms) |
| **Plant × year** | Juhász et al. |
| **Product (HS) × year** | Wu (Chinese targeted products), Alfaro et al. (trade) |
| **Country × industry × year** | Moretti et al. (OECD), Alfaro et al. (sectoral TFP), Wu (German industries) |
| **Country-pair × crop** (origin × destination × crop) | Moscona & Sastry |
| **Inventor × year / origin–destination pairs** | Kantor & Whalley (migration) |

Main lesson: **go to the finest cell where treatment varies and then saturate with fixed effects.**
Azoulay et al. pick disease × science × year *so that* they can include disease×science, disease×year and
science×year FE together. The remaining variation is only within-area shifts in funding.

---

## 3. Regression types

1. **Generalised DiD / event study with continuous or binary exposure**
   `Y_it = Σ_k β_k · Exposure_i · 1{t = k} + α_i + γ_t (+ group×year FE)`. Used by Gross & Sampat, Andrews, Schweiger et al., Akerman et al., de Souza, Alfaro et al., Romero, Gentile (PPML version).
2. **Triple differences.** Kantor & Whalley: High-space-capability (pre-1958) × Space industry × Space-race period, with county, industry and year FE, pre-1958 patents × year, and MSA × year FE. SEs two-way clustered (MSA × industry).
3. **Staggered DiD with heterogeneity-robust estimators.** Wu uses Callaway–Sant'Anna with never-treated products in the same industry as controls. Kantor & Whalley report de Chaisemartin–D'Haultfœuille as a robustness check. Akerman et al. use staggered rollout of research centres.
4. **IV / 2SLS**
   - Azoulay et al.: "windfall" funding = actual minus expected funding of grants near the NIH payline, aggregated to DST.
   - Myers & Lanahan: state SBIR matching policies give windfall funds.
   - Moretti et al.: **shift-share** predicted defense R&D (national defense R&D × fixed industry shares). Placebo instruments: non-R&D defense procurement and the military wage bill.
   - Arnarson et al.: predicted Swedish R&D from the reform as an instrument for Danish partners (Kovak et al.-style).
   - Kantor & Whalley: IV as robustness (receipt of NASA funding instrumented by the design).
5. **Regression discontinuity / diff-in-discontinuities.** Dechezleprêtre et al.: SME asset threshold moved in 2008. They estimate RD, DiD and diff-in-disc (the threshold after vs before the change). Spillovers are estimated on technologically connected firms.
6. **Matching + DiD / synthetic-control-type matching.** Schweiger et al.: science cities matched to similar municipalities ≥50 km away, matched on pre-trends. de Souza runs matched DiD as a robustness check.
7. **Knowledge production function.** Myers & Lanahan and Azoulay et al.: patent flow on R&D stock (perpetual inventory) by technology area, estimated as an elasticity and as patents per $.
8. **Gravity / bilateral with full FE.** Moscona & Sastry: origin×crop and destination×crop FE, with the mismatch term identified across pairs.
9. **Reduced form plus structural model for aggregation and GE.** Kantor & Whalley (Donaldson–Hornbeck market access), Moscona & Sastry, Akerman et al., de Souza, Gentile, Alfaro et al. Local DiD estimates are fed into a model for national and welfare counterfactuals.

---

## 4. Treatment vs control groups, and why each paper argues the comparison is valid

| Paper | Treated | Control | Why they argue it's sufficient |
|---|---|---|---|
| **Kantor & Whalley (Moonshot)** | County-industries whose **pre-1958** patents are textually similar (above median) to Soviet space technology in **CIA estimates**, in space industries, after 1958 | Same counties' non-space industries, low-capability cells, pre-1958 years | (i) Exposure is defined from *Soviet* demand, not NASA's choices, so it is not driven by NASA targeting local trends. (ii) 1958 balance table: treated and control cells are similar (except navy patents). (iii) Flat pre-trends in the event study. (iv) Robust to MSA×year FE, industry trends, and defense scientists/IBM mainframes/schooling × year. (v) Directly tests for spillovers into the control (non-space) industries and finds little. (vi) Robust to using US NASA patents for similarity and to alternative median/text rules. |
| **Azoulay et al. (NIH)** | DSTs with more "windfall" funded grants near the payline | DSTs whose grants near the payline happened to fall just below it | Funding near the payline is as good as random. Balance on applicant quality; past/future windfalls do not predict outcomes; FE-OLS and IV agree. |
| **Myers & Lanahan (DoE SBIR)** | Technology areas receiving extra state-matched funding | Areas whose winners were in states without a match | Match policies are noncompetitive and automatic. Match states do not have systematically more or less productive firms or technologies (tested). The estimate is benchmarked against Howell's (2017) RD. |
| **Andrews (colleges)** | Counties that won a new college (1839–1954) | **Runner-up** counties that were seriously considered (narrative record) | Runner-ups are similar on observables with parallel pre-trends. Using all other counties in the state instead gives non-parallel pre-trends, which shows why runner-ups are needed. "Consolation prize" cases help separate the channels. |
| **Gross & Sampat 2023 (OSRD WWII)** | County × technology clusters with high OSRD-funded patent share 1941–48 (intensity quartiles) | Untreated or low-intensity clusters | Wartime priorities were driven by military need, not local commercial potential. Precisely estimated parallel trends to 1940. Controls for total wartime patenting (so treatment ≠ "inventive cluster") and nearby technology areas. Not driven by a single state/county/cluster. Postwar federal R&D is controlled for. |
| **Gross & Sampat WP (CMR medicine)** | MeSH subjects / firms targeted by CMR contracts | Non-targeted subjects/firms | Subject-year FE. Pre-trends checked (drug-related pre-trends found and discussed). **WWI placebo**: a similar war demand shock without directed funding. |
| **Schweiger, Stepanov & Zacchia (Soviet science cities)** | Municipalities that hosted science cities | Matched municipalities (similar pre-period characteristics and trends, ≥50 km away) | Locations chosen by a secrecy/control rule of thumb, not economic potential. The 1991 collapse is an exogenous end of support. Contaminated municipalities are dropped. They discuss what the counterfactual means (no extra scientists vs scientists spread out). |
| **Akerman et al. (Embrapa)** | Municipalities ecologically similar to new research centres, after staggered opening | Less exposed municipalities / not-yet-treated | No pre-trends. **Placebo expansions**: randomise timing and location of centres; the true estimate is in the right tail (p<0.01). Outcomes before 1973 do not correlate with later exposure. |
| **Moretti, Steinwender & Van Reenen** | Country-industries with predicted increases in defense R&D | Others, with FE | Defense R&D is driven by geopolitics, not industry productivity. Shift-share with **fixed initial shares**. Placebo instruments (non-R&D defense spending) do not predict R&D. |
| **Dechezleprêtre et al. (UK R&D tax)** | Firms just below the new SME asset threshold | Firms just above | The threshold is unique to the R&D scheme (not shared by other programmes). No manipulation or bunching. Placebo thresholds. Diff-in-disc removes any pre-existing discontinuity. DiD is a robustness check (pre-trends noted around the Great Recession). |
| **de Souza (Brazil tech-transfer tax)** | Firms that imported technology (licences etc.) before 2001 | All other firms | Parallel pre-trends. The reform was motivated by institutional concerns, not labour-market trends. Fake-date placebo; placebo on unexposed firms; firm trends; matched DiD; alternative exposure measures. |
| **Arnarson et al. (Swedish R&D payroll deduction 2014)** | Swedish firms expected to be **below** the deduction cap (marginal cost falls); Danish trade/MNE partners of those firms | Firms above the cap (no marginal change); partners of unaffected firms | Bøler et al.-style marginal vs inframarginal comparison. No pre-trends. IV for the cross-border elasticity. |
| **Hanlon & Jaworski (US aircraft IP 1926)** | US airframes (IP protection strengthened) | US aero-engines (no change), and airframes in UK/France/Japan/Germany/Italy | A within-country complementary good isolates the IP change. Cross-country comparisons check that it is not a global trend. They argue that comparing "similar goods" can mislead when the goods are complements. |
| **Romero (Spain 1891 colonial tariff)** | Cotton-textile patents in Spain | Wool/silk/linen textile patents (less affected) | Event study pre-trends; **randomisation inference** (10,000 placebo assignments); persistence after 1898 independence; cross-country counterfactual comparison. |
| **Juhász, Squicciarini & Voigtländer (French mechanised spinning)** | Cotton-spinning plants (new technology needs reorganisation) | Metallurgy and paper (already factory-organised) | DiD "in spirit". Placebo: 1800 productivity is unrelated to distance to good plants. |
| **Wu (China high-tech lists → Germany)** | Products listed in China's high-tech Guidance (staggered 1999–2011); German industries exposed via IO links | **Never-treated products in the same industry**; less exposed industries | Within-industry comparison removes industry shocks. CS-DiD avoids bad TWFE comparisons. Event-study pre-trends. 1998 baseline exposure is fixed pre-treatment. |
| **Alfaro et al. (China rare-earth export restrictions)** | Industries with high REE input intensity/sensitivity (continuous) | Low-intensity industries | Parallel trends in exports and patents before 2010. Exposure from a pre-period IO table. Substitution elasticities based on chemistry. |
| **Gentile (China solar subsidies)** | Non-Chinese solar firms with pre-policy market exposure to Chinese competition | Less exposed firms | Exposure is built from **pre-policy** market shares (avoids reverse causality). Firm and year FE, PPML. |
| **Moscona & Sastry (inappropriate tech)** | Country-crop pairs with high pest/pathogen mismatch with R&D leaders | Low-mismatch pairs | Ecological mismatch is plausibly unrelated to other determinants once origin×crop and destination×crop FE are in. Placebo with mechanical technologies (no ecology). Placebo randomising which countries are R&D leaders. |

**Recurring validity arguments**
1. **Pre-determined exposure**: exposure is measured *before* the shock (pre-1958 patents, pre-2001 licences, 1998 IO links, pre-policy market shares).
2. **Exposure defined by something outside the policymaker's targeting**: Soviet tech for NASA, secrecy for Soviet cities, war needs for OSRD, national defense budgets.
3. **Better control groups**: runner-ups, never-treated within the same industry, complementary goods, marginal vs inframarginal firms, near-threshold units.
4. **Event studies** showing flat pre-trends, plus balance tables in the base year.
5. **Placebos**: fake dates, fake thresholds, fake rollouts, randomisation inference, placebo instruments, placebo technologies, a placebo historical episode (WWI).
6. **Check for spillovers into the control group** (Kantor & Whalley, Myers & Lanahan, Dechezleprêtre et al.), because contaminated controls bias DiD.
7. **Local vs aggregate**: migration and GE effects, using inventor panels and spatial models.

---

## 5. Exogenous variation that could carry over to sanctions → Russian innovation

- **Kantor & Whalley-style text-similarity exposure.** Score each pre-2014 Rospatent / PATSTAT Russian patent's similarity to the **EU/US dual-use and export-control lists** (EU Reg. 2021/821 Annex I, the 2022 Annex XXIII/CHPL items, US CCL/ECCNs). Aggregate to region × field. Then estimate a triple difference: high-exposure × field × post-2014/post-2022. The list is written by the *sender*, so it is not targeted on Russian local trends. This matches the Soviet-CIA logic.
- **Pre-determined dependence shares (shift-share à la Moretti et al. / Wu / Alfaro et al.).** Fix pre-2014 shares of imported inputs, foreign co-inventors, or foreign-licensed technology (de Souza-type) by region/firm, and interact them with the timing of sender-side restrictions.
- **Marginal vs inframarginal firms (Arnarson et al.).** Firms directly on SDN/EU lists vs firms in the same industry not listed. Firms *proposed* but not listed could serve as runner-ups (Andrews logic).
- **Directed technical change (Alfaro et al., Romero, Hanlon & Jaworski).** Expect *more* patenting in fields that substitute for embargoed imports (import substitution) and less in complementary fields. Test for opposite signs by field, which separates a sanctions effect from general decline.
- **Never-treated within-industry controls (Wu).** Products/fields never on control lists but in the same 2-digit industry. Use CS-DiD for staggered 2014 → 2022 → later package additions.
- **Placebos.** Randomise list timing/field (Akerman, Romero). Use a placebo technology class with no trade dependence (Moscona's mechanical placebo). Check foreign-applicant filings in Russia separately from resident filings.
- **Mechanisms.** Inventor emigration and moves (Kantor & Whalley) and the collapse of foreign co-invention (Myers-type geographic spillovers) are both measurable with disambiguated inventor data.

---

## 6. Practical checklist for this project

- [ ] Measure patents by filing date and inventor region; add quality weights (family size, foreign filings, citations).
- [ ] Use PPML with region×field and field×year FE as the main count model; log/asinh as robustness.
- [ ] Define exposure only from pre-2014 data; show a 2013 balance table.
- [ ] Main estimator: staggered-robust DiD/event study (CS-DiD, Sun–Abraham, dCDH). Keep TWFE for comparison only, consistent with the project's no-LP-as-main rule.
- [ ] Placebos: fake dates, randomised exposure, unexposed fields.
- [ ] Test for spillovers into control fields/regions before calling them controls.
- [ ] Separate resident vs foreign applicants, and import-substituting vs complementary fields.
