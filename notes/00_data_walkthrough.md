# Data walkthrough: how the main panel is built, step by step

Session 5, 18 Nov 2026. A slow, plain explanation of every merge. Details and decisions: `data_decisions.md`.
Example numbers below are from the current data (after the M3 fix).

---

## 0. The backbone: what the final dataset looks like

The regression runs on a **grid of technology field × year**:

| field | year | patents | Ban_f | Post |
|---|---|---|---|---|
| 3 Telecommunications | 2021 | 241 | +1.22 SD (coverage 0.67) | 0 |
| 3 Telecommunications | 2022 | 213 | +1.22 SD | 1 |
| 16 Pharmaceuticals | 2022 | 652 | −2.77 SD (coverage 0.08) | 1 |

(Industry map. One SD of coverage = 0.147.)

35 fields × 11 years (2015–2025) = **385 rows**. Everything else exists to fill two columns:
- **patents** (the outcome): changes by field *and* year;
- **Ban_f** (the treatment): one number per field, the same in every year.

The two columns are built separately (Side A and Side B), then joined on **field** (step 9).

---

## Four raw files

| # | File | Where from | One row is |
|---|---|---|---|
| 1 | Rospatent register CSV | rospatent.gov.ru/opendata (you downloaded it, version 2 Nov 2026) | one granted Russian invention patent |
| 2 | Google Patents | BigQuery | one patent publication with its IPC codes |
| 3 | CEPII BACI | cepii.fr | exporter × importer × HS6 product × year, trade value |
| 4 | EU Regulation 833/2014 | EU Publications Office (CELLAR), 35 consolidated versions | the law text; its annexes list banned customs codes |

---

## Side A: the outcome, from patents to "patents per field per year"

**Step 1. Start from the register (file 1).** One row per granted patent: registration number, filing date,
title, holder names with country codes, address. All years up to 2026.
- Keep **domestic** patents (all holders Russian).
- Drop the four **mass filers** (Kvasenkov etc.; none after 2018).
- Date each patent by its **filing year**.

**Step 2. Attach IPC codes where they exist (file 2).** Merge on **registration number**. Patents filed before
2018 almost all get codes; 2021 only 39%; 2022+ none (Google's Russian coverage stops).

**Step 3. Train the title classifier.** The patents that have codes teach a model which titles go with which
technology. Example: "антенная решетка …" → telecom.

**Step 4. Predict a field for every patent from its title.** All patents get a predicted field, including the old
ones, which get out-of-fold predictions, so the whole series is measured the same way.

**Step 5. Count.** Number of patents in each field in each filing year.
→ `data/clean/ru_domestic_field_year_imputed.csv` (column `n_top`). Example, telecom: 268 (2019), 247, 241, 213
(2022), 212, 233 (2024).

---

## Side B: the treatment, from bans to "share of a field's Western imports that was banned"

**Step 6. Which products were banned (file 4).**
- Read every ban annex in every version of the regulation. Each line has a customs code (CN, the EU's 8-digit
  version of HS) and the version date tells us when it was listed.
- Convert CN codes to HS 2007 6-digit codes, the classification BACI uses.

→ `eu_ban_hs07.csv`: for each HS6 product and date, the share banned (1 = fully, 0.5 = half of its sub-codes).
Example: **851762** (machines for transmitting voice/data: routers, base stations) is banned from 16 March 2022.

**Step 7. How much each product mattered before the war (file 3).** From BACI, Russia's imports from the West
(the 2022 coalition) by HS6 product, averaged over 2019–21.
→ `ru_imports_hs6.parquet`. Example: 851762 = $486m a year.

**Step 8. The bridge: which field does each product belong to?** Trade data speak in products (HS codes),
patents speak in technology fields, and no official table links them. So each product is **split over fields
with weights that sum to 1**, in two ways:

| | 851762 (routers etc.) | 
|---|---|
| **Product-name map**: the Russian customs name of the product goes through the same title classifier | telecom 0.47, digital communication 0.34, … |
| **Industry map**: HS 851762 → ISIC industries 2610 / 2620 / 2817 / 3320 (published concordance, equal split) → each industry's patents by field (Dorner–Harhoff table from German firms) | telecom 0.09, digital comm., computers, electrical machinery, mechanical elements … (spread thin) |

The product-name map is sharper. The industry map is independent of our classifier, but it spreads products
widely because one industry patents in many fields.

**Step 9. Collapse to one number per field.**

Ban_f = Σ over products ( weight of product in field × pre-war Western imports × banned share )
      / Σ over products ( weight of product in field × pre-war Western imports )

**Worked example, telecom, product-name map** (end-2023 bans):

| HS6 | product | weight to telecom | Western imports, $m/yr | banned share | weight × imports |
|---|---|---|---|---|---|
| 851762 | voice/data transmission machines | 0.47 | 486 | 1 | 227 |
| 851761 | base stations | 0.41 | 262 | 1 | 109 |
| 851770 | parts of telephones/network gear | 0.53 | 109 | 1 | 57 |
| 852910 | antennas | 0.72 | 34 | 1 | 24 |
| … about 4,000 more products with small weights | | | | | |

Sum of "weight × imports" = $814m; the banned part = 83% → **Ban_telecom = 0.83** (product-name map). The
industry map gives 0.67 for telecom: its top contributors are computers and parts (HS 8471), because the industry
map puts some computer-industry imports into telecom.

Finally Ban_f is **z-scored** across the 35 fields (mean 0, SD 1).
→ `field_ban_coverage.csv`.

---

## Join and estimate

**Step 10.** Attach Ban_f (35 numbers) to the field × year patent counts **by field**. Post = 1 from 2022.
PPML: patents on Ban_f × Post with field and year fixed effects. β < 0 means fields with more of their Western
imports banned lost patents relative to other fields after 2022.

---

## Why N is 385, and what changes it

The treatment is one number per field, so there are **35 independent treatment units**, however finely the
patents are split. More rows from splitting by **region** (32,340) or **holder type** add precision for the
outcome but no new treatment variation.

More treatment units need either finer technology classes (**IPC subclasses**, about 450: same steps 3–9 with
subclass instead of field; note 13) or a different unit (**firms**: holder name → tax ID → industry; needs a
name→INN table, see note 12).
