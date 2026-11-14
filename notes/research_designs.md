# Research designs: sanctions and innovation

Draft 2026-11-11. References marked † still need to be checked: the reference-lookup tool was
down when this was written.

---

## 0. Channels, and why the sign is open

| Channel | Direction | What we would see |
|---|---|---|
| Lost imported inputs and technology (machines, chips, software, licences) | − | falls in fields that depend on sender inputs |
| Smaller market (export bans, financial isolation) lowers the return to R&D | − | falls in export-oriented firms and fields |
| Cut knowledge flows (co-authors, conferences, journals, joint programmes) | − | fewer international collaborations; lower quality or citations |
| Finance (SWIFT exclusion, sanctioned banks, no foreign VC) | − | falls in young or R&D-heavy firms and startups |
| Emigration of inventors and scientists | − | inventors reappear abroad |
| Forced import substitution, protected home market, state push | + | patents rise in fields that replace blocked imports (maybe low quality) |

The interesting result is **which channel dominates where**. A pure "patents fall" result is less
interesting than "they fall in fields that depend on Western inputs and rise in fields that substitute for them".

---

## 1. Measuring innovation: more than patents

| Measure | Source (access) | Level | Notes |
|---|---|---|---|
| Patent applications: resident, at home and abroad | WIPO IP Statistics Data Center (free) | country × year × field | the basic macro outcome; many zeros, so use PPML |
| Patent micro-data (applicant, inventor, IPC, citations, families) | PATSTAT (paid; check LMU), Google Patents on BigQuery (free tier), Lens.org (free for research), PatentsView (USPTO, free) | patent | needed for firm, inventor and field designs |
| National office data | Rospatent open data, CNIPA via Google Patents | patent | domestic filings matter because foreign filings can drop for administrative reasons |
| Utility models, industrial designs, trademarks | WIPO (free) | country × year | trademarks also capture new products and services, not just technology |
| Scientific publications, co-authorship, topics, citations | **OpenAlex** (free, full snapshot) | paper / author / institution | probably the most usable micro-data for sanctioned countries |
| R&D spending, researchers | UNESCO UIS (free), OECD MSTI | country × year | thin coverage for sanctioned countries |
| New export products, upgrading, complexity | CEPII BACI HS6 (free), Atlas of Economic Complexity (free) | country × product × year | "new products exported" and unit values = innovation embodied in trade |
| Technology imports | BACI (capital goods, ICT, dual-use HS codes); IMF BoP "charges for the use of IP" (free) | country × year | measures the input side, i.e. the mechanism |
| Technology adoption | CHAT (Comin–Hobijn)†, ITU | country × technology × year | diffusion, not invention |
| Software activity | GitHub Innovation Graph (free, from 2020), GH Archive | economy × quarter / repo | sharp events (§3.4) |
| Firm innovation surveys | World Bank Enterprise Surveys (free with registration) | firm | product and process innovation, R&D, foreign licences; few waves per country |
| Firm accounts | Orbis (check LMU), **RFSD** Russian financial statements database† (open), SPARK-Interfax (paid) | firm × year | intangible assets; for Russia, capitalised R&D (balance-sheet line 1120) |
| Startups and VC | Crunchbase, Dealroom, PitchBook (paid; possibly an academic licence) | deal | finance channel |

**Measurement traps to keep in mind**

- *Mechanical drop in foreign filings.* Sanctions can block fee payments or stop cooperation between patent
  offices, so filings abroad fall without any change in inventing. Always look at domestic filings separately.
- *State push for patenting.* Import-substitution programmes can raise patent counts without raising quality.
  Use quality weights: citations received, family size, filings abroad, grant rates.
- *Zeros and small counts* in many sanctioned countries: PPML, not log(1+y).

---

## 2. Macro design: cross-country panel (first pass)

**Aim.** A transparent picture of whether anything shows up at all, and for which sanction types. Not the
main identification.

**Data.** GSDB (own download) for sanction onset and type × WIPO patents, OpenAlex publication counts,
BACI new export products and high-tech share, UIS R&D. Country × year, about 1990–2023.

**Estimator.** Event study with staggered timing and clean controls (LP-DiD, Dube–Girardi–Jordà–Taylor†;
or Callaway–Sant'Anna / de Chaisemartin–D'Haultfœuille), horizons −5…+10, PPML for counts:

  y_{c,t+h} − y_{c,t−1} = β_h · Onset_{ct} + δ_t + controls + ε,  with never- or not-yet-sanctioned countries as controls.

**Heterogeneity that carries the argument**

- *By type:* trade and financial sanctions vs arms and travel sanctions. Travel-only sanctions should do little
  to patenting, so they serve as a rough placebo.
- *By exposure:* the pre-sanction share of capital-goods or high-tech imports that came from the senders (BACI).
  The effect should rise with that share.
- *By country size and existing capacity:* sanctions should matter more where there is innovation to lose.

**Main weakness.** Sanctions follow wars, coups and crises that also hurt innovation (Russia 2022 = war +
sanctions at once). At this level the estimates are associations plus pre-trends, and should be described that way.
Also: few sanctioned countries patent much (Russia, Iran, China under export controls, Belarus, Venezuela...),
so the identifying variation comes from a handful of cases. Synthetic control for the big episodes
(Iran 2012, Russia 2014 and 2022) is a useful complement.

---

## 3. Micro and meso designs (main identification)

### 3.1 Country × technology field (recommended core design)

Bridges macro and micro, and uses public data only.

**Idea.** Within a sanctioned country, fields that rely on inputs from the senders should lose more than
fields that do not. Country-year fixed effects absorb the war, the recession and everything else that hits the
whole country.

  Patents_{c,k,t} = β · Sanctioned_{ct} × Dependence_{ck} + α_{ct} + γ_{kt} + μ_{ck} + ε

- k = WIPO's 35 technology fields (or IPC 4-digit).
- Dependence_{ck} = the pre-sanction share of field-k-relevant imports that came from the sender countries.
  Link HS products to IPC classes with the Lybbert–Zolas (2014) concordance†.
- Variant: dependence on **export-controlled** goods specifically (dual-use list / Wassenaar categories mapped to HS).
- Outcomes: patents (domestic and abroad), citation-weighted patents, publications by OpenAlex topic.
- The import-substitution channel predicts the *opposite* sign in fields where domestic producers replace blocked imports.

**Threats.** Dependence may proxy for how "frontier" or globally integrated a field is, and frontier fields may
trend differently. Add field-specific trends, and test the same specification in non-sanctioned countries
(placebo) and before the sanction (pre-trends).

### 3.2 Russia, firm level (2014 and 2022)

Two episodes, firm-level listing data, and open accounting data.

- **Treatment:** OFAC SDN and Sectoral Sanctions (SSI) listings, EU listings, with dates (OpenSanctions keeps
  the history). Under OFAC's 50% rule, firms majority-owned by listed entities are also covered, which gives extra
  variation. Ahn & Ludema (2020)† use this design for firm performance after 2014.
- **Second exposure:** the firm's pre-sanction reliance on imported inputs from sender countries (customs data if
  available, otherwise industry-level import shares).
- **Outcomes:** Rospatent patents matched by name or INN to firms; capitalised R&D and intangible assets (RFSD);
  employment of R&D staff if available.
- **Comparison:** listed firms vs matched unlisted firms in the same industry and region; staggered DiD by listing date.
- **Main threat for 2022:** listed firms are often defence-related, and defence firms got war demand at the same time.
  Use industry × year fixed effects, compare within industry, and run 2014 separately as the cleaner episode.

### 3.3 Science and knowledge flows (OpenAlex)

- **Russia 2022:** many Western institutions ended joint projects, Horizon Europe cooperation was suspended, CERN
  ended its cooperation agreement. Exposure = a researcher's (or institution's) pre-2022 share of co-authors in
  sanctioning countries. Outcomes: output, new co-authorships, citations, topic switching, and authors whose
  affiliation moves abroad (emigration).
- **Iran 2010–2012:** field-level contrast between dual-use fields (nuclear, aerospace, some chemistry) and other fields.
- **Historical benchmark:** Iaria, Schwarz & Waldinger (2018, QJE)† on the post-WWI boycott of Central Powers
  scientists. It is the closest well-identified precedent for the knowledge-flow channel and a good template.

Feasible alone, since all the data are free.

### 3.4 Sharp platform events: GitHub

- In July 2019 GitHub restricted accounts in Iran, Syria and Crimea (along with Cuba and North Korea); in January 2021
  it obtained a US licence to serve Iranian developers again (dates to be checked†).
- Restriction and reversal within two years make a clean before/after/after design: Iranian developer activity vs
  comparable countries (GitHub Innovation Graph from 2020 covers the reversal; GH Archive covers 2019).
- Small but very clean, and good for a short paper or a chapter on the "access to tools" channel.

### 3.5 US export controls on Chinese firms (Entity List)

- Firm-specific additions with exact dates (Huawei 2019, and many others since). Outcomes: Chinese patents (CNIPA) and
  R&D of listed firms and their domestic suppliers.
- Existing work: Crosignani et al. (NY Fed) on decoupling†, plus a growing literature on Chinese firms' innovation
  responses. Before choosing this design, check how crowded it is. It is the best-measured case but also the most studied.

### 3.6 Optional: the sender side

Firms in sender countries that lose the target's market may cut R&D (market-size channel). Much smaller literature;
probably a second paper.

---

## 4. Suggested order

1. **Macro first pass (§2), 2–3 weeks.** WIPO patents + OpenAlex counts + GSDB types. Mainly event-study plots.
   It shows where there is enough signal and which episodes drive it.
2. **Country × field (§3.1)** as the core design. Public data only, and the fixed effects deal with the big
   confounder of the macro panel.
3. **One deep micro case:** Russia firm-level (§3.2) or Russia/Iran science (§3.3). §3.3 is cheaper; §3.2 is closer
   to "firms' exposure to sanctions".
4. GitHub (§3.4) as a side project if time allows.

## 5. Decisions for you before any data work

1. Main micro case: Russian firms (§3.2), Russian/Iranian science (§3.3), or Chinese Entity List firms (§3.5)?
2. Patent micro-data: does LMU have PATSTAT or Orbis? Otherwise Google Patents (BigQuery) + Lens.
3. Sanction definition: all GSDB sanctions, or only trade, financial and technology measures (arms and travel kept
   as placebos)?
4. Period: 1990–2023 for the macro panel, or start in 2000 when OpenAlex and patent coverage of these countries is better?
5. Language and tools: R or Python? Git repository for this folder?

## 6. Reading list to start (all † until checked)

- Felbermayr, Kirilakha, Syropoulos, Yalcin, Yotov (2020): Global Sanctions Data Base.
- Ahn & Ludema (2020): targeted sanctions and Russian firms.
- Crozet, Hinz, Stammann, Wanner (2021): firms' exports to sanctioned countries.
- Moser & Voena (2012): compulsory licensing under the Trading with the Enemy Act; enemy patents and US invention.
- Iaria, Schwarz & Waldinger (2018): the collapse of international science after WWI.
- Bloom, Draca & Van Reenen (2016): trade-induced technical change (the induced-innovation side).
- Lybbert & Zolas (2014): HS–IPC concordance.
- Moghaddasi Kelishomi & Nisticò (2022): sanctions and Iranian manufacturing firms.
- Dube, Girardi, Jordà & Taylor: LP-DiD.
