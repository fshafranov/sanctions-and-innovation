# Sanctions research: a map, and where innovation fits (12 Nov 2026)

Reference status:
- **[V]** = verified against OpenAlex (title, first author and year agree).
- **[W]** = found via web search, abstract or summary only; full text not read.
- Effect sizes and designs marked [W] come from abstracts and need to be checked in the papers.

## 1. What sanctions research looks like

**Two traditions.**
- Political science asks whether sanctions *work*: do they change the target's policy? It uses case datasets with
  threats and outcomes.
- Economics asks what sanctions *cost*: trade, GDP, firms, banks, health. It mostly uses gravity models, event
  studies and firm-level difference-in-differences.
- Best overview: Felbermayr, Morgan, Syropoulos & Yotov (2025), *Economic Sanctions: Stylized Facts and
  Quantitative Evidence*, Annual Review of Economics 17, 175–195 **[V]**. It focuses on trade.

**Datasets**

| Dataset | Unit | Notes |
|---|---|---|
| GSDB (Felbermayr et al. 2020, EER **[V]**; Release 4: Yalçın et al. 2025, World Economy **[V]**) | case, type (trade, financial, arms, military, travel, other), sender, objective, 1950–2023 | the standard source in economics; no threats; **counts cases, not their economic weight** |
| TIES (Morgan, Bapat & Kobayashi 2014, CMPS **[V]**) | case incl. threats, 1945–2005 | political-science workhorse; about 40% of episodes end at the threat stage [W] |
| HSE (Hufbauer, Schott, Elliott & Oegg) | about 200 major episodes, with cost estimates | older; costs as % of target GNP |
| EUSANCT (Weber & Schneider 2020, EER **[V]**), Targeted Sanctions Consortium | EU/US/UN cases in detail | fewer cases, richer coding |
| China TIES (Zhang & Shanks 2025, CMPS [W]) | Chinese sanctions | over 70% of its cases are missing from TIES/GSDB [W]: coverage depends on the sender |

**Outcomes and methods**

| Outcome | Typical design | Examples |
|---|---|---|
| Trade | structural gravity, PPML, pair and country-year FE | GSDB papers; Crozet, Hinz, Stammann & Wanner (2021, EER) **[V]**: firms stop exporting to sanctioned markets, and lifting sanctions does not restore trade symmetrically |
| GDP and its components | event study / panel DiD around sanction onsets | Gutmann, Neuenkirch & Neumeier (2023, JCE) **[V]**: GDP growth falls, mostly from US unilateral and financial sanctions [W] |
| Single episodes | synthetic control, VAR with an intensity index | Iran: Gharehgozli (SCM, about −17% GDP 2012–14 [W]); Laudati & Pesaran (2023, JAE) **[V]**: newspaper-based sanctions-intensity index for Iran |
| Firms and banks | DiD on dated listings (SDN, sectoral lists) | Ahn & Ludema (2020, EER) **[V]**: targeted Russian firms after 2014 |
| Severity | trade-weighted intensity | Bernstein, Meyer, O'Rourke & Schularick (2025, DIW DP 2148) [W]: sanctioned trade from bilateral data; only drastic sanctions do real damage on average; import sanctions bite more [W] |

So **local projections are not standard** in this literature. The common tools are:
- event studies or panel DiD around onsets (cross-country);
- gravity models (trade);
- synthetic control (single countries);
- DiD on listing dates (firms).

## 2. Sanctions and innovation: what already exists

| Paper | Design | Finding (from abstract) |
|---|---|---|
| Wen, Zhao & Chang, *Economics & Politics* 36(1), 2024 (online 2022) **[V]** | cross-country DiD, 91 countries, 1988–2016; matching, system GMM | sanctions reduce innovation, only in open, globalized, democratic targets; non-economic sanctions have no effect [W] |
| Wang, Wen, Zhao & Zhou, *Economic Analysis and Policy* 85, 2025 [W] | 119 countries, 2000–2018 | **sender** countries' patent and trademark applications fall [W] |
| Miromanova & Hovhannisyan, SSRN 5177287, 2025 [W]; Sept 2024 abstract page in `papers/` | Rospatent data × GSDB, "three waves" of Russia sanctions 2008–2024, inside Russia and at the USPTO; **read**: origin-country × month PPML DiD at Rospatent (sender vs non-sender author countries), country + month FE; Russian authors only via interrupted time series. See `lit_hovhannisyan_miromanova_2025.md` | patents fall for foreign and domestic applicants; US sanctions hurt more than EU; travel and financial sanctions reduce patenting, arms embargoes raise it; joint patents with sender-country inventors fall [W] |
| Same authors, *Do Sanctions Inhibit Innovation? The Case of the U.S.* (July 2025; abstract page in `papers/`) | USPTO patents by inventors from sanctioned countries, **monthly**, 2000–2023; GSDB + EUSANCT | US sanctions reduce sanctioned countries' patenting in the US; joint patents especially sensitive (Villanova seminar listing) |
| Cao, de Nicola, Mattoo & Timmis, World Bank PRWP 10950, 2024 [W] | Entity List × PATSTAT | US collaborations fall; patents fall at Chinese firms with prior US co-inventors, and at their US partners |
| Liu, Liu, Makarin & Wen, CEPR DP 20690, 2025 [W] | 2007 US "China Rule" (dual-use export controls) | exposed firms' patents **rise**: +65% in controlled technologies, +42% in others; inventors +30% |
| Chen, Ding, He, Wang, Xia & Yao, SSRN 7118620 [W] | 122 sanctioned Chinese tech firms | patent counts unchanged, quality and novelty fall |
| Further China-firm studies (Entity List, R&D) [W] | listed firms | mixed: R&D inputs rise, outputs flat or down |
| Iaria, Schwarz & Waldinger (2018, QJE) **[V]** | post-WWI boycott of Central Powers scientists | losing access to frontier knowledge lowers scientific output; the historical benchmark |
| Kokabisaghi et al. (2019, BMJ Global Health) **[V]** | Iran bibliometrics | international co-authorship **rose** under sanctions; quantity and quality metrics diverge; more Iranian journals indexed |
| Russia 2022 science: Science\|Business reports, CISRUS, Zhang, Cao, Sivertsen & Kochetkov (THE blog) [W] | Scopus/WoS counts | Scopus output −~20% in 2022 and collaborations with US/DE/UK/JP down, but **disputed**: isolation is strong in security-related fields; the rest is domestic policy and emigration |

**What this means for us**
1. **The cross-country question is already published.** Wen et al. (2024) find a negative effect with DiD on a GSDB-type
   panel. Our first pass, done more carefully, shows the pooled effect rests on one or two countries. That is a
   useful *critique*, but not a paper on its own.
2. **Russia patents × GSDB is taken.** Miromanova & Hovhannisyan (2025) already find that both resident and
   non-resident patenting fall. Any Russia work needs a different angle:
   - who files (origin of non-resident applicants);
   - quality;
   - technology fields by import dependence.
3. **Iran is much less studied** on the innovation side: patents and science under sanctions. The JCPOA gives a relief
   and reimposition cycle (2016 → 2018), and the newspaper intensity index (Laudati–Pesaran) is a ready-made measure.
4. The **sign is genuinely contested**. Western sanctions on Russia: negative. Chinese export-control episodes: often
   positive (induced innovation). This contrast is a question in itself: when do sanctions cause substitution, and
   when stagnation?

## 3. How to measure sanctions: options

| Option | What it captures | Used by | Pro / con |
|---|---|---|---|
| A. GSDB case onset/presence (current) | that a case exists | Wen et al.; Gutmann et al.; most GSDB papers | comparable to the literature; but a targeted asset freeze on 10 officials counts the same as an oil embargo (China problem) |
| B. Broad vs targeted | drop multi-target designation lists; split complete vs partial trade measures (GSDB `descr_trade`); UN/EU regimes | partly in GSDB papers by type | simple; still case-based |
| C. Trade-weighted intensity | pre-sanction share of the target's imports (or exports) from the sending countries, × sanction in force | Bernstein, Meyer, O'Rourke & Schularick (2025) [W]; our exposure idea | measures **bite**; matches the input-loss channel; needs bilateral trade (IMF DOTS/IMTS, public) |
| D. Newspaper intensity index | sanction pressure over time for one country | Laudati & Pesaran (Iran) | captures escalation and relief within a country; single-country only |
| E. Dated listings (SDN, EU lists, Entity List) | firm- or entity-level treatment | Ahn & Ludema; Cao et al. | micro designs; needs firm-level outcomes |

My suggestion: **C as the main cross-country measure, with A kept as the literature benchmark.** For Iran and Russia
use D-style timing (escalation and relief) with technology-field or origin-level outcomes.

## 4. What WIPO is

- **WIPO** is the World Intellectual Property Organization, a UN agency in Geneva. It runs the international patent
  filing system (PCT) and collects statistics from national patent offices.
- The World Bank patent series we use (`IP.PAT.RESD`, `IP.PAT.NRES`) are WIPO data, re-published by the World Bank.
- WIPO's own **IP Statistics Data Center** has more detail, free of charge:
  - applications by **office × applicant's country of origin** (e.g. German applicants at Rospatent);
  - filings by each country's residents **abroad**;
  - technology fields.
- That makes it possible to separate "foreign firms stop filing in Russia" from "Russian inventors stop inventing".

## Additions, session 4 (12 Nov 2026): papers closest to the field-level ban design (notes 10–11)

| Paper | Design | Finding | Status |
|---|---|---|---|
| Egorov, Korovkin, Makarin & Nigmatulina, "Export Sanctions: Rerouting, Disruption, and the Reach of Economic Warfare" (July 2026; earlier "Trade Sanctions", BOFIT DP 11/2025) | hand-collected Western sanctions records by country × product; Russian customs data, firm balance sheets, railway shipments, procurement; DiD | Bans covered 36% of Russia's pre-war imports. Directly targeted imports fell sharply, and rerouting (mostly of goods produced in sanctioning countries) offset about two-thirds. Firms reliant on soon-to-be-sanctioned imports lost about 12% of output (14% in the BOFIT version), with no offsetting entry. **No patent or innovation outcomes** (the PDF text has no matches for patent/innovation/R&D). | abstract and full-text search read, PDF |
| Liu, Liu, Makarin & Wen, "Export Controls and Innovation in Sanctioned Countries" (HBS WP 25-004, rev. Sept 2025; CEPR DP 20690) | 2007 US China Military Catch-All Rule; controlled vs excluded products; Chinese imports, R&D, patents | Imports of controlled goods fell; patents in controlled technologies **rose** (+65%; +42% in others): export controls accelerated innovation in the target | listing [W]; already noted above |
| Liu, Ruan & Zheng, "Export Controls and Technological Redirection" (SSRN 7042518) | patent-text "technology redirection score"; US suppliers and Chinese Entity List firms | both shift innovation away from the US-supplier-led route toward alternative routes | snippet only [W] |
| "Intellectual Property Rights and Innovation Incentives: Evidence from U.S. Sanctions" (CUHK Business School page; authors not confirmed) | US suppliers whose customers were sanctioned | suppliers cut R&D about 20% and patents about 19%, and rely more on trade secrets (the sender side) | snippet only [W] |
| Hovhannisyan & Miromanova (SSRN 5177287, 2025) | GSDB sanctions × Rospatent counts, 2008–23 | sanctions reduce patenting by domestic and foreign authors in Russia; US sanctions bite more than EU; arms embargoes raise patenting | read in full (note lit_hovhannisyan_miromanova_2025.md) |

**Positioning of notes 10–11.** Egorov et al. are the closest on the treatment side: product-level dated sanctions
against Russia and a strong import first stage, but outcomes are firm output, not invention. Liu et al. are the
closest on the outcome side (technology-level patents after export controls), but for China in 2007, where a
narrow control **raised** innovation. Our result for Russia 2022 (broad bans, no substitution, modest relative
decline in banned fields) is the opposite sign to the China Rule. This is the comparison to make explicit: narrow
controls with substitutes available (China 2007, Russia 2014) vs broad coalition bans (Russia 2022).
