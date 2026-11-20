"""Inventor-year panel of domestic Russian inventors from the Rospatent API records (20 Nov 2026).

Sources: grants (21b, data/raw/rospatent_api/weeks) and application publications (21c, weeks_A), one record per
application (A record if published, else the grant; matched on application number as 23b).
Rules (IV1-IV4 in notes/data_decisions.md)
  IV1 sample: domestic applications (P2/AP2: all holders/applicants RU, else all inventors RU; no foreign priority);
      mass filers dropped (AP4: the four individuals, as holder or inventor); filing years 2010-2025.
  IV2 inventor id = full Cyrillic name with patronymic as printed, country code RU ("Фамилия Имя Отчество (RU)").
      Names without a patronymic (3rd token ending -вич/-вна/-ич/-кызы/-оглы) are dropped (share printed).
      Homonyms are merged; robustness flag `common` = surname among the 300 most frequent surnames.
  IV3 field shares: an application's weight is split equally over its distinct WIPO fields (Schmoch, D1); an
      inventor-year's field profile = sum over that year's applications.
  IV4 holder type of the application (P4 regex on first holder/applicant).
Output: data/clean/inventor_year_field.parquet and .csv.gz (name, year, field, w, n_apps_year, holder_type_mode, common)
        data/clean/inventor_applications.parquet (app key, year, fields, holder_type, n_inventors)
        data/clean/inventor_app_field_year.csv (field x year applications, fractional, same sample; for R)
"""
import gzip
import importlib.util
import json
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW, CLEAN = ROOT / "data" / "raw" / "rospatent_api", ROOT / "data" / "clean"


def load(name, file):
    sp = importlib.util.spec_from_file_location(name, ROOT / file)
    m = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(m)
    return m


s11, s23 = load("s11", "data/scripts/cleaning/clean_rospatent.py"), load("s23", "data/scripts/processing/process_official_ipc_panels.py")
CC = re.compile(r"\(([A-Z]{2})\)\s*$")
PATRON = re.compile(r"^[А-ЯЁ][а-яё\-]+ [А-ЯЁ][а-яё\-]+ [А-ЯЁ][а-яё]+(вич|вна|ич|кызы|оглы)$")
MASS = {"Щепочкина Юлия Алексеевна", "Квасенков Олег Иванович", "Кочетов Олег Савельевич", "Ахмедов Магомед Эминович"}


def split(names):
    out = []
    for n in names:
        m = CC.search(n or "")
        out.append((CC.sub("", n or "").strip(), m.group(1) if m else ""))
    return out


def records():
    for sub, kind, hkey in (("weeks_A", "A", "applicant"), ("weeks", "C", "patentee")):
        for f in sorted((RAW / sub).glob("*.json.gz")):
            with gzip.open(f, "rt", encoding="utf-8") as g:
                for h in json.load(g):
                    c, b = h.get("common", {}), (h.get("biblio", {}) or {}).get("ru", {}) or {}
                    app = c.get("application", {}) or {}
                    fd = app.get("filing_date", "") or ""
                    if not fd[:4].isdigit():
                        continue
                    yield {
                        "key": str(app.get("number", "")).split("/")[0].lstrip("0"), "kind": kind, "year": int(fd[:4]),
                        "ipc": [x.get("fullname", "").replace(" ", "") for x in
                                (c.get("classification", {}) or {}).get("ipc", []) or []],
                        "holders": split([p.get("name", "") for p in b.get(hkey, []) or []]),
                        "inventors": split([p.get("name", "") for p in b.get("inventor", []) or []]),
                        "prio_foreign": any(p.get("country") not in (None, "RU") for p in c.get("priority", []) or []),
                    }


def main():
    d = pd.DataFrame(records())
    d = d[d.year.between(2010, 2025)].sort_values("kind").drop_duplicates("key")  # A before C
    hcc = d.holders.map(lambda l: [cc for _, cc in l if cc])
    icc = d.inventors.map(lambda l: [cc for _, cc in l if cc])
    dom = (hcc.map(lambda l: len(l) > 0 and all(c == "RU" for c in l)) |
           (hcc.map(len).eq(0) & icc.map(lambda l: len(l) > 0 and all(c == "RU" for c in l)))) & ~d.prio_foreign
    d = d[dom].copy()
    h1 = d.holders.map(lambda l: l[0][0] if l else "")
    mass = h1.isin(MASS) | d.inventors.map(lambda l: any(n in MASS for n, _ in l))
    print(f"domestic applications 2010-25: {len(d):,}; mass filers dropped: {mass.sum():,}")
    d = d[~mass].copy()
    d["holder_type"] = d.holders.map(lambda l: s11.holder_type(l[0][0] + f" ({l[0][1]})") if l else "none")
    d["fields"] = d.ipc.apply(lambda cs: sorted({f for f in map(s23.field_of, cs) if f}))
    d = d[d.fields.str.len() > 0]
    inv = d[["key", "year", "holder_type", "fields", "inventors"]].explode("inventors").dropna(subset=["inventors"])
    inv["name"], inv["cc"] = inv.inventors.str[0], inv.inventors.str[1]
    n_ru = (inv.cc == "RU").sum()
    inv = inv[inv.cc == "RU"]
    ok = inv.name.str.match(PATRON)
    print(f"RU inventor-application rows: {n_ru:,}; with patronymic format: {ok.mean():.3f}")
    inv = inv[ok].drop_duplicates(["key", "name"])
    d["n_inventors"] = d.key.map(inv.groupby("key").size()).fillna(0).astype(int)
    d[["key", "year", "fields", "holder_type", "n_inventors"]].to_parquet(CLEAN / "inventor_applications.parquet", index=False)
    fa = d[["year", "fields"]].explode("fields")
    fa["w"] = 1 / d.fields.str.len().reindex(fa.index)
    fa.groupby(["fields", "year"]).w.sum().rename("applications").reset_index().rename(columns={"fields": "field"}) \
        .to_csv(CLEAN / "inventor_app_field_year.csv", index=False)

    x = inv[["name", "year", "key", "holder_type", "fields"]].explode("fields")
    x["w"] = 1 / x.groupby(["key", "name"]).fields.transform("size")
    iy = x.groupby(["name", "year", "fields"]).w.sum().rename("w").reset_index().rename(columns={"fields": "field"})
    napp = inv.groupby(["name", "year"]).key.nunique().rename("n_apps_year")
    htm = inv.groupby(["name", "year"]).holder_type.agg(lambda s: s.mode().iloc[0]).rename("holder_type_mode")
    iy = iy.merge(napp.reset_index(), on=["name", "year"]).merge(htm.reset_index(), on=["name", "year"])
    sur = inv.drop_duplicates("name").name.str.split().str[0].value_counts()
    top = set(sur.head(300).index)
    iy["common"] = iy.name.str.split().str[0].isin(top)
    iy.to_parquet(CLEAN / "inventor_year_field.parquet", index=False)
    iy.to_csv(CLEAN / "inventor_year_field.csv.gz", index=False)
    a = iy.drop_duplicates(["name", "year"])
    print(f"inventors: {a.name.nunique():,}; inventor-years: {len(a):,}; common-surname share {a.common.mean():.3f}")
    first = a.groupby("name").year.min()
    print(pd.DataFrame({"active": a.groupby("year").size(), "new": first.value_counts().sort_index()}).loc[2012:].to_string())


if __name__ == "__main__":
    main()
