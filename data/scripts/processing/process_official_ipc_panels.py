"""Field and subclass panels from OFFICIAL IPC codes (session 5): Rospatent API (21b/22) where available, else
Google Patents (08). Replaces title-predicted fields/subclasses wherever official codes exist (O1-O2 in
notes/data_decisions.md).

  O1 codes: API IPC if the patent is in the API extract, else Google IPC; patents with neither are dropped from
     these panels (their share by year is printed).
  O2 counts: field = WIPO 35 fields via the Schmoch table (script 10 rule D1), fractional over a patent's distinct
     fields (n_frac, WIPO convention) and whole count in the field of the first-listed IPC code (n_first);
     subclass = distinct subclasses, fractional (n_frac) and first-listed (n_first).
Same population as the predicted panels: domestic, mass filers dropped, by filing year (register).
Output: data/clean/ru_domestic_field_year_official.csv, ru_domestic_subclass_year_official.csv,
        ru_domestic_field_year_holder_official.csv, ru_domestic_subclass_holder_year_official.csv
"""
import importlib.util
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "clean"
sp = importlib.util.spec_from_file_location("s10", ROOT / "data" / "scripts" / "processing" / "process_ru_patents_google.py")
s10 = importlib.util.module_from_spec(sp)
sp.loader.exec_module(s10)
BY_GROUP, BY_SUB, NAMES = s10.concordance()


def field_of(code):
    m = re.match(r"([A-H]\d\d[A-Z])\s*(\d+)/", code)
    if not m:
        return None
    return BY_GROUP.get((m.group(1), m.group(2))) or BY_SUB.get(m.group(1))


def main():
    reg = pd.read_parquet(CLEAN / "rospatent_inventions.parquet",
                          columns=["reg_no", "app_year", "domestic", "mass_filer", "holder_type"])
    reg["reg_no"] = reg.reg_no.astype(str)
    api = pd.read_parquet(CLEAN / "rospatent_api_biblio.parquet", columns=["reg_no", "ipc"])
    g = pd.read_parquet(RAW / "bigquery" / "ru_publications.parquet", columns=["publication_number", "ipc"])
    g = g[g.publication_number.str.match(r"RU-\d+-C")].copy()
    g["reg_no"] = g.publication_number.str.split("-").str[1].astype(int).astype(str)
    g["ipc"] = g.ipc.apply(lambda x: [c.replace(" ", "") for c in x] if x is not None else [])
    g = g[g.ipc.str.len() > 0].drop_duplicates("reg_no")[["reg_no", "ipc"]]
    codes = pd.concat([api.assign(src="api"), g[~g.reg_no.isin(api.reg_no)].assign(src="google")])
    d = reg[reg.domestic & ~reg.mass_filer & (reg.app_year >= 2000)].merge(codes, on="reg_no", how="left")
    d["app_year"] = d.app_year.astype(int)
    cov = d.assign(has=d.ipc.notna()).groupby("app_year").agg(share_coded=("has", "mean"),
                                                               share_api=("src", lambda s: (s == "api").mean()))
    print(cov.loc[2010:].round(3).to_string())
    d = d[d.ipc.notna()].copy()
    d["fields"] = d.ipc.apply(lambda cs: sorted({f for f in map(field_of, cs) if f}))
    d["f_first"] = d.ipc.apply(lambda cs: next((f for f in map(field_of, cs) if f), None))
    d["subs"] = d.ipc.apply(lambda cs: sorted({c[:4] for c in cs if len(c) >= 4}))
    d["s_first"] = d.ipc.apply(lambda cs: cs[0][:4] if len(cs) else None)

    def panel(unit_list, unit_first, keys, name):
        x = d[["app_year", "holder_type", unit_list]].explode(unit_list).dropna(subset=[unit_list])
        x["w"] = 1 / d[unit_list].str.len().reindex(x.index)
        frac = x.groupby([unit_list, "app_year"] + keys).w.sum().rename("n_frac")
        first = d.dropna(subset=[unit_first]).groupby([unit_first, "app_year"] + keys).size().rename("n_first")
        first.index.names = [unit_list, "app_year"] + keys
        out = pd.concat([frac, first], axis=1).fillna(0).reset_index().rename(columns={"app_year": "year"})
        out.to_csv(CLEAN / name, index=False)
        return out

    f = panel("fields", "f_first", [], "ru_domestic_field_year_official.csv").rename(columns={"fields": "field"})
    f.rename(columns={"fields": "field"}).to_csv(CLEAN / "ru_domestic_field_year_official.csv", index=False)
    s = panel("subs", "s_first", [], "ru_domestic_subclass_year_official.csv")
    s.rename(columns={"subs": "subclass"}).to_csv(CLEAN / "ru_domestic_subclass_year_official.csv", index=False)
    fh = panel("fields", "f_first", ["holder_type"], "ru_domestic_field_year_holder_official.csv")
    fh.rename(columns={"fields": "field"}).to_csv(CLEAN / "ru_domestic_field_year_holder_official.csv", index=False)
    sh = panel("subs", "s_first", ["holder_type"], "ru_domestic_subclass_holder_year_official.csv")
    sh.rename(columns={"subs": "subclass"}).to_csv(CLEAN / "ru_domestic_subclass_holder_year_official.csv", index=False)
    print(f.groupby("year")[["n_frac", "n_first"]].sum().loc[2010:].round(0).to_string())


if __name__ == "__main__":
    main()
