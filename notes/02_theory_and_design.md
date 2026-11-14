# Where should sanctions affect innovation, and how do we compare like with like? (12 Nov 2026)

Status: proposal for discussion. Nothing here has been estimated. Data availability marked "(check)" is unverified.

## 1. Why the cross-country panel is mostly noise

1. **Treatment has almost no bite on average.** A GSDB case can be a travel ban on ten officials or an oil embargo.
   Most country-years coded "sanctioned" have tiny economic exposure, so the average effect is diluted towards zero.
2. **Few sanctioned countries innovate.** Zimbabwe, Mali or North Korea file a handful of patents. The power comes
   from Russia, Iran and China, so "cross-country" is really three case studies with a lot of noise added.
3. **Selection.** Sanctions follow wars, coups and crises, which hit innovation directly. Russia 2022 is war +
   sanctions + emigration at once.
4. **Aggregate outcomes carry big unrelated trends:** China's rise, catching-up countries, patent-subsidy reforms,
   journal indexing.
5. **Slow and mixed responses.** Innovation reacts over years, and channels with opposite signs (input loss vs
   import substitution) cancel out in a country total.

So the fix is not a better estimator. Move the comparison **inside the sanctioned country**, to units that differ in
how much the sanctions hit them. Then the country-wide shock (war, recession, ruble) is absorbed by fixed effects.

## 2. A simple framework

New inventions in field k of country c:

  I_ck = f( researchers, R&D funds, **imported inputs** M_ck, **access to frontier knowledge** K_ck,
            **expected market** D_ck, finance )

Sanctions from a coalition S cut M, K and D, but only to the extent that field k **depended on S** for them and
cannot substitute towards non-sender suppliers. Blocking imports also raises the domestic return to inventing
substitutes (directed technical change, Acemoglu 2002), which pushes the other way where there is capacity.

| Channel | Predicts a decline where… | Predicts no effect where… | Timing |
|---|---|---|---|
| Inputs (equipment, components, software) | fields whose inputs came from senders and are hard to source elsewhere (chips, machine tools, scientific instruments) | fields using domestic or non-sender inputs | 1–3 years: stocks run down |
| Knowledge (co-inventors, conferences, citations) | fields where the target's inventors relied on sender co-inventors or sender prior art; the frontier sits in sender countries | fields with a domestic or non-sender knowledge base | gradual |
| Market (exports, foreign firms' presence) | export-oriented fields; foreign (non-resident) filings from senders | domestic-market fields | fast |
| Finance | young, R&D-intensive firms | large state firms | fast |
| People (emigration) | fields with mobile, internationally employable inventors (ICT) | | 2022 Russia only |
| **Substitution (+)** | fields that produce substitutes for blocked imports, *if* there is domestic capacity (China) | | 2–5 years |

**Useful negative predictions (placebos)**
- No effect in fields with no sender dependence.
- No effect in the same fields in non-sanctioned comparison countries.
- No effect of sanctions without economic bite (travel bans on officials). This is better than "arms/travel as a
  placebo" at the country level, because it varies within the same country.

## 3. Better treatment and control groups

### Design A (main): country × technology field, triple difference

- **Unit:** target country c × technology field k (WIPO's 35 fields or IPC classes) × year.
- **Treatment intensity:** pre-sanction **dependence of field k on the senders**. Two public-data measures:
  - (a) *Knowledge frontier in senders*: share of world patenting in field k (pre-period) by inventors from the
    sender coalition. If the frontier of k is in the US/EU/Japan, being cut off from them matters more.
  - (b) *Input dependence*: target's pre-sanction imports of the products used in field k from senders, as a share
    of all such imports. Patent classes are linked to products with the Lybbert–Zolas concordance; the direction of
    this mapping needs care (check).
- **Comparisons**
  - Within the target and year: high- vs low-dependence fields. This absorbs the war, the recession, exchange rates
    and national policy.
  - Same field in comparable **non-sanctioned** countries. This absorbs global field trends (AI boom, battery boom).

  y_ckt = β · Post_ct × Dep_ck + α_ct + γ_kt + μ_ck + ε    (fixed effects: country×year, field×year, country×field)

- **Identifying assumption:** without sanctions, the gap between high- and low-dependence fields in Russia (or Iran)
  would have evolved like the same gap in comparison countries. This can be checked with leads.
- **Events with real bite:** Russia 2014 and 2022; Iran 2010–12 (escalation), 2016 (relief), 2018 (reimposition).
  The relief and reimposition pair gives a symmetric test, as in a switching design.
- **Outcome:** patents by inventors from the target country, by field. At home and abroad, separately.
- **Data:** WIPO patent statistics by origin × field × year (public; check the field detail). Imports from BACI or
  UN Comtrade (public).
- **Threat:** dependence may proxy for "frontier field", and frontier fields may trend differently. The comparison
  countries and pre-trends address this.

### Design B: who files where (dyadic office × origin × year)

- **Treated:** applicants from sender countries filing at the target's patent office, after sanctions.
- **Controls:** applicants from non-sender countries at the same office in the same year, and the same sender
  applicants at other offices.
- **Fixed effects:** office×year, origin×year, office×origin pair.
- **Identifies** the market and relationship channel: foreign firms withdrawing. The reverse direction (target
  inventors filing at sender vs non-sender offices) identifies a *reallocation* away from sender markets, not the
  level of the target's innovation, because origin×year effects absorb that level.
- **Relation to the literature:** Hovhannisyan & Miromanova (2025) do one office (Rospatent) with country and month
  effects only. Done across all targets with event-study leads, it is a clear improvement, but it answers a narrower
  question.

### Design C: industry productivity (how technology enters GDP)

- **Unit:** country × manufacturing industry × year. Outcome: value added per worker or industry TFP.
- **Treatment intensity:** industry's pre-sanction reliance on imported intermediate inputs from senders, from
  input-output tables. OECD ICIO covers Russia and China but not Iran (check); UNIDO INDSTAT for output and
  employment (check access).
- **Comparisons:** same as Design A (within country-year across industries; same industry in comparison countries).
- This is the cleaner version of the TFP question. Aggregate TFP mixes utilisation and terms of trade, while the
  industry contrast isolates the input-loss channel.

### What stays at the country level

- Synthetic control for single episodes (Russia 2014, Iran 2012) on TFP and patents, as transparent descriptive
  evidence.
- The cross-country panel, with an exposure-weighted measure, as context and as a replication of Wen et al.

## 4. Proposed order

1. **Design A for Russia and Iran with public WIPO + trade data.** First step: check that WIPO publishes counts by
   origin × field × year, and build the two dependence measures.
2. Design C if the input-output and industry data are accessible.
3. Design B across all targets, as a contained second result on foreign filers.

## 5. Decisions needed

1. Sender coalition per episode: GSDB senders of the episode, or a fixed Western coalition?
2. Dependence measure: knowledge frontier (a), input imports (b), or both?
3. Comparison countries for the triple difference: all non-sanctioned countries with enough patents, or a matched
   set (middle-income, resource exporters, similar patent volume)?

## 6. Addendum (12 Nov 2026): the effective coalition is wider than the list of senders

The West can cut off non-sanctioning countries' firms without those countries imposing sanctions:
- **Extraterritorial export controls:** the US foreign direct product rule for Russia (Feb 2022) covers goods made
  anywhere with US technology, e.g. TSMC or Samsung chips.
- **Secondary sanctions** on third-country suppliers: GSDB case 1480 (2023) targets firms in China, Turkey, the UAE,
  Korea, Singapore, Switzerland and others. EO 14114 (Dec 2023) extends this to foreign banks.
- **Over-compliance** by firms and banks that are not legally bound.

GSDB's 2022 senders against Russia also include Korea, Taiwan and Singapore, which were not senders in 2014.

**Consequences for Design A**
- Dependence measured by *inventor nationality* (the current `dep_frontier`) treats Chinese and Korean technology
  as freely available. For 2022 this probably gets the ranking backwards in ICT and semiconductors.
- **2014 vs 2022:** in 2014 US controls were narrow (oil exploration, defence end users) and East Asian substitutes
  were open. This may explain the null result for 2014.
- Measure exposure by **what is controlled, whatever the country of origin**:
  - (1) Russia's pre-2022 imports of goods on the control lists (e.g. the EU/US/UK/Japan Common High Priority List,
    about 50 HS codes; EU Annex VII), mapped to fields;
  - (2) substitutability through China: China's share of those imports before and after 2022 (circumvention
    literature, e.g. Chupilkin, Javorcik & Plekhanov);
  - (3) the share of each field's Rospatent filings held by applicants from the 2022 coalition (incl. KR, TW, SG).
- The main test should be **2022**. Bottleneck: post-2022 outcomes by field (WIPO 2022 is incomplete for Russia).
  Check Rospatent open data first.
