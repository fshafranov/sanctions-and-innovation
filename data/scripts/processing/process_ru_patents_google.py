"""Russian patent documents by WIPO technology field x filing year x document type (Design D, patents part).

Input
  data/raw/bigquery/ru_publications.parquet   (08_get_bigquery_ru.py; Google Patents, RU, filed 2000+,
                                                coverage ends May 2022 -> see notes/04_regional_design.md §4c)
  data/raw/wipo/ipc_technology.xlsx           WIPO IPC-technology concordance (35 fields)

Document types (one row per publication; deduplicated to one per application_number and type):
  inv_ru       granted inventions (kind C1/C2) whose harmonised assignees are all RU, or with no assignee and all
               inventor countries RU                                         -> domestic inventions
  inv_foreign  granted inventions with any non-RU assignee (or non-RU inventors and no assignee)
  um           utility models (U1); Google has no holder or inventor country for them, so domestic and foreign
               are not separable (Rospatent reports foreign applicants at a few % of utility models)
  app          published invention applications (A, A3 kinds); no holder data, all origins
Mass filers (D2, notes/data_decisions.md): individuals with >= 1,000 invention grants filed 2005-2017 are dropped (Kvasenkov O.I.
  ~29,000, mostly canning recipes in A23 = ~14% of domestic grants; Shchepochkina Yu.A. ~4,400, building
  materials; Kochetov O.S. ~1,600; Akhmedov M.E. ~1,100). Utility models carry no holder in Google's data, so
  they cannot be filtered.
Field assignment (D1): every IPC code of the document mapped to a field: main group first (concordance codes
  like 'H04N   5/%'), otherwise subclass ('F21H%'); fractional counting over the distinct fields of a document
  (as WIPO does). Documents without IPC are dropped (0% of grants/UMs, 11% of applications).
Output: data/processed/ru_patents_google/ru_patents_field_year.csv  (field, field_en, year, type, n)
        data/processed/ru_patents_google/ru_patents_e21b_year.csv   (year, type, n_e21b): documents with any E21B code (oil and gas
        drilling, the target of the 2014 US/EU oil-technology export controls), whole counts
"""
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "clean"


def concordance():
    x = pd.read_excel(RAW / "wipo" / "ipc_technology.xlsx", header=6).dropna(subset=["Field_number"])
    by_group, by_sub, names = {}, {}, {}
    for _, r in x.iterrows():
        code, f = str(r.IPC_code).rstrip("%"), int(r.Field_number)
        names[f] = r.Field_en
        if "/" in code:  # 'H04N   5/' -> ('H04N', '5')
            by_group[(code[:4], code[4:].strip(" /"))] = f
        else:
            by_sub[code[:4]] = f
    return by_group, by_sub, names


def doc_type(kind, assignees, inv_cc):
    if kind in ("C1", "C2"):
        acc = [a["country_code"] for a in assignees if a["country_code"]]
        if acc:
            return "inv_ru" if all(c == "RU" for c in acc) else "inv_foreign"
        icc = [c for c in inv_cc if c]
        if icc:
            return "inv_ru" if all(c == "RU" for c in icc) else "inv_foreign"
        return "inv_ru"  # no origin information: 1.3% of grants; Rospatent grants are mostly domestic
    if kind == "U1":
        return "um"
    if kind in ("A", "A3"):
        return "app"
    return None


MASS_FILERS = ("KVASENKOV", "SHCHEPOCHKINA", "KOCHETOV OLEG", "AKHMEDOV MAGOMED")


def mass_filer(assignees):
    return any(a["name"] and a["name"].upper().startswith(MASS_FILERS) for a in assignees)


def main():
    by_group, by_sub, names = concordance()
    d = pd.read_parquet(RAW / "bigquery" / "ru_publications.parquet")
    d["type"] = [doc_type(k, a, i) for k, a, i in zip(d.kind_code, d.assignees, d.inventor_countries)]
    d = d[d.type.notna()].copy()
    mf = d.assignees.apply(mass_filer)
    print(f"dropped {mf.sum()} documents of mass filers (D2)")
    d = d[~mf]
    d["year"] = d.filing_date // 10000
    d = d.sort_values("publication_date").drop_duplicates(["application_number", "type"], keep="last")

    def fields(codes):
        out = set()
        for c in codes:
            m = re.match(r"([A-H]\d\d[A-Z])(\d+)/", c)
            if not m:
                continue
            f = by_group.get((m.group(1), m.group(2))) or by_sub.get(m.group(1))
            if f:
                out.add(f)
        return sorted(out)

    d["fields"] = d.ipc.apply(fields)
    d["e21b"] = d.ipc.apply(lambda cs: any(c.startswith("E21B") for c in cs))
    e = d.groupby(["year", "type"]).e21b.sum().rename("n_e21b").reset_index()
    e.to_csv(ROOT / "data" / "processed" / "ru_patents_google" / "ru_patents_e21b_year.csv", index=False)

    d = d[d.fields.str.len() > 0]
    d["w"] = 1 / d.fields.str.len()
    long = d[["year", "type", "fields", "w"]].explode("fields").rename(columns={"fields": "field"})
    p = long.groupby(["field", "year", "type"]).w.sum().rename("n").reset_index()
    full = pd.MultiIndex.from_product([sorted(names), sorted(d.year.unique()), sorted(d.type.unique())],
                                      names=["field", "year", "type"])
    p = p.set_index(["field", "year", "type"]).reindex(full, fill_value=0).reset_index()
    p["field_en"] = p.field.map(names)
    p.to_csv(ROOT / "data" / "processed" / "ru_patents_google" / "ru_patents_field_year.csv", index=False)
    print(p.groupby(["type"]).n.sum().round(0).to_dict())
    print(p[p.year.between(2010, 2021)].pivot_table(index="year", columns="type", values="n", aggfunc="sum").round(0))


if __name__ == "__main__":
    main()
