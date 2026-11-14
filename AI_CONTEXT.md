# AI context: sanctions and innovation (handoff for the next session)

Last updated **12 Nov 2026**, end of session 4. Read this first, then `notes/11_patents_ban_test.md` (current
main result), `notes/02_theory_and_design.md` (design) and `notes/data_decisions.md` (every data choice). Per-session change record: `SESSION_LOG.md`.

## 1. Project in one paragraph

The user's **own** project; it keeps its own pipeline, separate from other work. Question: do
sanctions reduce innovation in target countries, and through which channels (imported inputs, frontier knowledge,
markets, finance, emigration), versus induced import substitution? **Current direction:** within-country designs
for Russia (and Iran if data allow), because the cross-country panel is dominated by a few countries.
**Main design (Design A):** country × technology field × year triple difference, with dependence of the field on the
sanctioning coalition as treatment intensity.

## 2. Where things stand

| Piece | Status | Note |
|---|---|---|
| Cross-country panel (WB, OpenAlex, PWT TFP, GSDB) | done | **main: staggered DiD (C–S, Sun–Abraham; script 11, note 01 §A): resident patents rise vs never-treated (mostly rich countries), vanishes vs not-yet-treated. Synthetic DiD (script 12, note 01 §A2): non-resident patents −0.6 after Russia 2022 and Iran 2012; residents no effect; Python synthdid package gives identical SDID estimates (12c). With covariates (12d): Russia 2022 foreign-filing drop robust; synthetic controls are richer, more open, not resource exporters.** Robustness: onset LP (panel LP on case onset), 5-yr-clean LP-DiD, intensity; spec grid; leave-one-out. Pooled patent effects come from China/Iran; the arms/travel "placebo" behaves like the treatment; TFP null. `notes/01_cross_country_results.md` |
| Literature | done (first pass) | `notes/literature_sanctions.md`; full read of Hovhannisyan & Miromanova (2025): `notes/lit_hovhannisyan_miromanova_2025.md` |
| Theory and designs A/B/C | written | `notes/02_theory_and_design.md` incl. addendum §6 (2022 coalition, extraterritorial controls) |
| Design A, Russia 2014 | done, **null** | pre-trends; Russia not unusual in the permutation test. `notes/03_design_a_results.md` |
| Designs B (who files where), C (industry productivity) | not started | user finds them interesting |
| Fields for post-2018 RU patents (title classifier) | **done (session 4)** | TF-IDF + logit on titles, local; out-of-time top-1 81%, within-field changes corr 0.91 / slope 0.93 vs IPC; field × year and region × field × year 2000–2026. Unblocks the import-substitution / Western-withdrawal event study. `notes/08_title_classifier.md` |
| Import exposure by field (BACI + two product→field maps) | **done, first stage (session 4)** | pre-2022 Western import share does NOT predict the 2022 loss (sign reversed: pharma/medical high share but exempt); loss concentrated in electronics/telecom/semis/transport/engines; China replaced engines/transport, not electronics. Next: legal ban coverage (EU Annex XXI/XXIII, CHPL) as treatment. `notes/09_import_exposure.md` |
| **Main test: patents on ban coverage (pre-registered)** | **done (session 4)** | β = −0.092 [−0.114, −0.069], RI p = 0.0065; pre-trend (banned fields drifting down ~1%/SD/yr); trend-adjusted −0.02 to −0.06; **no substitution (upper bound ≈ +3%/SD)**, likely modest relative decline, clearest for research institutes/universities. `notes/11_patents_ban_test.md` |
| EU ban coverage by field (treatment) | **done, strong first stage (session 4)** | 35 versions of Reg. 833/2014 parsed (CELLAR API); bans cover 49% of 2019–21 Western manuf. imports by end-2023; 1 SD coverage → Western imports −0.31/−0.48 (2023), −0.38/−0.61 (2024); China does not replace more in banned fields. Next: reduced form on domestic patents. `notes/10_ban_coverage.md` |
| Literature methods (seminar papers + Moonshot) | done (session 4) | `notes/07_literature_methods_innovation.md` |
| Design D: regions of Russia (exposure × capacity; substitution vs decline) | designed; register parsed; maps | `notes/04_regional_design.md`, results `notes/05_design_d_first_results.md`, maps and post-2022 changes `notes/06_regional_maps_results.md` (session 3) |

## 3. Start here next session

**Where the evidence stands (end of session 4).** The project now has one main design and result:
- **Treatment:** EU export-ban coverage by technology field (35 WIPO fields): share of 2019–21 Western imports
  banned, parsed from 35 versions of Reg. 833/2014 (note 10). Strong first stage (Western imports −0.31/−0.48
  log points per SD by 2023; correlation with realised drop −0.9); China did not replace more in banned fields.
- **Outcome:** domestic invention patents by field, fields imputed from titles for post-2018 patents (note 08).
- **Main test (pre-registered, note 11):** β = −0.092 [−0.114, −0.069], RI p = 0.0065; robust across 6
  pre-specified checks. **But pre-trend:** banned fields drift down ~1%/SD/yr before 2022 (2017–18 exclude 0).
  Trend-adjusted −0.02 to −0.06; 2019–25 window −0.07/−0.08. Staggered (Sun–Abraham, C–S) −6% to −15%, same
  pre-drift. 2014: oil list tiny, mild decline, confounded by oil price; later-banned fields did not react to 2014.
- **Reading:** no import substitution in invention (upper bound ≈ +3%/SD); probably a modest relative decline in
  banned fields, size uncertain. Plus earlier: total domestic patents flat, foreign filings −50% after 2022.
- **Literature position:** Egorov, Korovkin, Makarin & Nigmatulina (2026; same product-level treatment, firm
  output −12%, no patents); Liu, Liu, Makarin & Wen (China 2007 rule: controls raised patents). Notes in
  `notes/literature_sanctions.md` (session 4 additions).

**The user's standard: pre-period event-study coefficients should be insignificant.** The main test fails it.

**Draft report:** `reports/report.tex` → `reports/report.pdf` (12 pages, figs 25, 29–33, tables 1–3; LaTeX with
`latexmk -pdf`). Bibliography typed from memory, not yet verified. Update it after the sector × year FE step.
**Reports are LaTeX in `reports/`, never Claude Docs (user, 12 Nov 2026).**

**Next steps (agreed direction, in order):**
1. **Sector × year fixed effects** (compare fields within broad sector: electronics, instruments, chemistry,
   process engineering, mechanical engineering, others = WIPO's 5 sectors) to remove the machinery → life-science
   drift that drives the pre-trend. Aim: flat pre-period by design.
2. **HonestDiD (Rambachan–Roth) bounds** on the main event study: does "no substitution" survive M = 1–2?
3. Make the 2019–25 short-window event study the main figure if 1 does not fix the pre-trend.
4. Then: region × field × year with region × year FE (equation discussed: P_rft = exp(β Ban_f·Post + α_rf + γ_rt));
   Annex IV military end-users (~970 entities, dated, in the downloaded regulation files) matched to patent holders
   as a firm-level design (control: not-yet-listed firms); check whether Egorov et al. publish their sanctions data.
5. Write-up: "large sender-defined supply shock, no substitution, modest decline, foreign exit".

**Older threads (session 3 and before), still open:**
**Regional trade exposure (user's wish):** no open region × partner-country data. Checked (note 04 §4e): RCSI
dataset 201 (2016–21, login, page gone), Rosstat regional publications and FCS archived files/open data (2011–22;
far abroad vs CIS only, plus product groups). Leads: authors of Sokolova, Davidson & Mariev (2024, 84 regions ×
204 countries, 2013–20), Kaukin & Idrisov (2011), Izotov (2021, Far East); user was offered draft request emails.
Fallback: 2011–13 far-abroad (machinery) imports from archived FCS files, or RFSD industry-mix shift-share.

**Other open threads**
- Cross-country: drop Western/OECD targets (open decision 1) and rerun `11_staggered_did.R`; not-yet-treated or
  non-high-income never-treated as controls; balanced event time; HonestDiD bounds.
- SDID: wider donor pool with resource exporters (offered, not done); Iran's donors include Georgia/Moldova.
- Regions: defence-industry control; utility-model register; capacity × exposure 2×2.
- Side ideas saved or discussed: elections and Western exposure (in `LMU_Life/Possible Research Ideas/research_ideas.md`
  §2.7); faculty change in top Russian universities (5-100 winners vs near-misses; post-2022 departures via OpenAlex
  author histories) — offered to save, not saved; citation-based knowledge flows (OpenAlex references).

## 4. Open decisions (ask the user)

- Western targets inside the cross-country measure (France 1995/98/2003, USA 2003, India 1998, ...): keep or drop?
- GSDB SU → RUS and CS → CZE+SVK (only 1995–96 clean windows); OpenAlex article/review filter.
- Sanction measure for the cross-country work: trade-weighted intensity (Bernstein et al.) recommended, not built.
- Arms/travel "placebo": relabel as "other sanction types"; replace with fake dates and permutation (not built).
- Whether to narrow the project to Western technology withdrawal (section 3).
- Request regional trade data from the authors listed in section 3 (user sends; drafts offered).

## 5. Layout and how to run

```
data/raw/{gsdb,wb,openalex,pwt,oecd,wipo}   raw downloads (git-ignored); GSDB V4 obtained via the request form;
                                            WIPO zip downloaded by hand from wipo.int
data/clean/                                 panel.csv (country-year), field_panel_*.csv, field_dependence.csv
scripts/data/01-07                          Python (uv): downloads, cleaning, panels
scripts/analysis/                           R (fixest): 00_setup, specifications, lp_functions, 01-07
output/figures, output/tables               fig0a-c descriptives, fig1-5 cross-country, fig6-8 Design A
notes/                                      designs, results, literature, data decisions
papers/                                     PDFs + README (index)
```

`./run_all.sh` rebuilds everything (downloads take several minutes).
Session 3 additions: `data/raw/rospatent` (user download), `data/raw/gadm` (boundaries), `data/raw/rucities`
(towns/regions), `data/raw/wb/wdi_bulk/WDI_CSV.zip` (WDI API was down). R packages added: `did`, `quadprog`.
Python `synthdid` cross-check (12c) runs in a separate env (pins clash with the project; see script header).

## 6. Working notes for the AI

- **User preferences:** public data first; ask before non-mechanical data choices; document every download and
  cleaning step; figures follow Healy (facets, intervals, zero line); name which intervals exclude zero and call
  thin patterns suggestive; no Claude co-author lines in commits; theory and design discussion before estimation;
  **main method = TWFE DiD and event studies**; for staggered adoption heterogeneity-robust DiD
  (Callaway–Sant'Anna, Sun–Abraham) next to plain TWFE. **Local projections only as a robustness check** (user,
  12 Nov 2026: does not fully understand them). The cross-country LP results (scripts 02/03, `lp_functions.R`,
  note 01) stay as robustness; the staggered-DiD main version is `11_staggered_did.R` (note 01 §A).
- **Blocked sites** (do not try to get around them): SSRN (Cloudflare check; the user downloads PDFs by hand) and
  dataverse.nl (bot protection; PWT TFP taken from FRED instead).
- `setFixest_nthreads(1)` in `00_setup.R`: multithreaded fixest segfaulted in long loops.
- Downloaded files are untrusted: run Python on them with `.venv/bin/python -I`.
- Local git only, no remote. Data files are git-ignored.
