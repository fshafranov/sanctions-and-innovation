"""Filings panel: every published invention application by filing year, field and origin (20 Nov 2026).

Filings = application publications (kind A, 22b) UNION grants (register, script 11) whose application number has no
A publication (fast grants skip A since 2014). Matched on the application number.
Rules (AP3-AP5 in notes/data_decisions.md)
  AP3 attributes: from the A record (applicant at filing) where one exists, else from the grant (patentee; P2/P4).
      IPC: A record, else the grant's API record (22), else Google (as O1). Field = Schmoch table (rule D1),
      fractional over distinct fields (n_frac).
  AP4 mass filers: only the four Russian individuals of P6/D2 (Shchepochkina, Kvasenkov, Kochetov, Akhmedov).
      P6 as coded also flags foreign firms whose names the holder-type regex reads as individuals (Philips,
      Qualcomm, Samsung, Siemens, Ford, Safran); they are KEPT here because they are part of the foreign series.
  AP5 date = application filing date as published. For PCT national-phase entries this is the INTERNATIONAL filing
      date (entry into Russia is ~30 months later); WIPO office statistics count them in the year of entry, so the
      benchmark against WIPO totals is approximate for foreign filings.
Output: data/clean/ru_filings_year_totals.csv (year x origin x source x pct counts, for the benchmark),
        data/clean/ru_filings_field_year_origin.csv (field x year x origin [x holder_type], n_frac)
"""
import importlib.util
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "clean"
sp = importlib.util.spec_from_file_location("s23", ROOT / "scripts" / "data" / "23_build_official_ipc_panels.py")
s23 = importlib.util.module_from_spec(sp)
sp.loader.exec_module(s23)
MASS_RU = ["Щепочкина Юлия Алексеевна", "Квасенков Олег Иванович", "Кочетов Олег Савельевич", "Ахмедов Магомед Эминович"]


def norm_no(s):
    return s.astype(str).str.replace(r"\D", "", regex=True).str.lstrip("0")


def main():
    a = pd.read_parquet(CLEAN / "rospatent_api_apps.parquet")
    a["key"] = norm_no(a.app_no)
    reg = pd.read_parquet(CLEAN / "rospatent_inventions.parquet",
                          columns=["reg_no", "app_no", "app_year", "domestic", "holder_type", "holder1", "pct_no"])
    reg["reg_no"], reg["key"] = reg.reg_no.astype(str), norm_no(reg.app_no)
    api = pd.read_parquet(CLEAN / "rospatent_api_biblio.parquet", columns=["reg_no", "ipc"])
    g = pd.read_parquet(RAW / "bigquery" / "ru_publications.parquet", columns=["publication_number", "ipc"])
    g = g[g.publication_number.str.match(r"RU-\d+-C")].copy()
    g["reg_no"] = g.publication_number.str.split("-").str[1].astype(int).astype(str)
    g["ipc"] = g.ipc.apply(lambda x: [c.replace(" ", "") for c in x] if x is not None else [])
    g = g[g.ipc.str.len() > 0].drop_duplicates("reg_no")[["reg_no", "ipc"]]
    codes = pd.concat([api, g[~g.reg_no.isin(api.reg_no)]]).drop_duplicates("reg_no")

    granted = set(reg.key)
    a["granted"] = a.key.isin(granted)
    a = a.assign(source="A", pct=a.pct, holder1=a.applicant1)[
        ["key", "app_year", "domestic", "holder_type", "holder1", "pct", "ipc", "source", "granted"]]
    gr = reg[~reg.key.isin(set(a.key))].merge(codes, on="reg_no", how="left")
    gr = gr.assign(source="grant_only", pct=gr.pct_no.fillna("").str.strip().ne(""), granted=True)[
        ["key", "app_year", "domestic", "holder_type", "holder1", "pct", "ipc", "source", "granted"]]
    d = pd.concat([a, gr], ignore_index=True)
    d = d[d.app_year.notna() & (d.app_year >= 2010)].copy()
    d["app_year"] = d.app_year.astype(int)
    print(f"A records whose application number is in the register: {a.granted.mean():.3f}")
    print(f"mass filers dropped (AP4): {d.holder1.isin(MASS_RU).sum():,}")
    d = d[~d.holder1.isin(MASS_RU)]
    d["origin"] = d.domestic.map({True: "domestic", False: "foreign"})

    tot = d.groupby(["app_year", "origin", "source", "pct"]).size().rename("n").reset_index() \
        .rename(columns={"app_year": "year"})
    tot.to_csv(CLEAN / "ru_filings_year_totals.csv", index=False)
    print(tot.pivot_table(index="year", columns=["origin", "source"], values="n", aggfunc="sum").fillna(0)
          .astype(int).loc[2014:].to_string())

    d["ipc"] = d.ipc.apply(lambda x: list(x) if x is not None and not isinstance(x, float) else [])
    print("share with IPC by year:", d.assign(h=d.ipc.str.len() > 0).groupby("app_year").h.mean().loc[2014:].round(3).to_dict())
    d["fields"] = d.ipc.apply(lambda cs: sorted({f for f in map(s23.field_of, cs) if f}))
    d = d[d.fields.str.len() > 0]
    x = d[["app_year", "origin", "holder_type", "source", "fields"]].explode("fields")
    x["w"] = 1 / d.fields.str.len().reindex(x.index)
    p = x.groupby(["fields", "app_year", "origin", "holder_type", "source"]).w.sum().rename("n_frac").reset_index() \
        .rename(columns={"fields": "field", "app_year": "year"})
    p.to_csv(CLEAN / "ru_filings_field_year_origin.csv", index=False)
    print(p.groupby(["year", "origin"]).n_frac.sum().unstack().loc[2014:].round(0).to_string())


if __name__ == "__main__":
    main()
