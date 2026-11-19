"""Pre-war characteristics of the 35 WIPO fields, used as controls (x year) in 18m_prewar_controls.R (session 5).
Fixed before estimation (rule PC1 in notes/data_decisions.md):
  univ_share     share of the field's domestic patents (fractional, filed 2015-19) held by universities
  foreign_share  share of all granted patents in the field (filed 2015-19) whose holder is not Russian (register flag)
  size           log mean domestic patents per year in the field, 2015-19
  west_share     Western (coalition) share of the field's total imports 2019-21, by product->field map (industry, text)
Input : data/clean/ru_domestic_field_year_holder_official.csv, rospatent_inventions.parquet, rospatent_api_biblio.parquet,
        ru_imports_hs6.parquet, hs07_field_{industry,text}.csv
Output: data/clean/field_prewar_characteristics.csv  (field, map, univ_share, foreign_share, size, west_share)
"""
import importlib.util
import re
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
CLEAN = ROOT / "data" / "clean"
sp = importlib.util.spec_from_file_location("s10", ROOT / "scripts" / "data" / "10_build_ru_patent_fields.py")
s10 = importlib.util.module_from_spec(sp)
sp.loader.exec_module(s10)
BY_GROUP, BY_SUB, _ = s10.concordance()


def field_of(code):
    m = re.match(r"([A-H]\d\d[A-Z])\s*(\d+)/", code)
    if not m:
        return None
    return BY_GROUP.get((m.group(1), m.group(2))) or BY_SUB.get(m.group(1))


def main():
    h = pd.read_csv(CLEAN / "ru_domestic_field_year_holder_official.csv")
    h = h[h.year.between(2015, 2019)]
    tot = h.groupby("field").n_frac.sum()
    univ = h[h.holder_type == "university"].groupby("field").n_frac.sum().reindex(tot.index, fill_value=0) / tot
    size = np.log(tot / 5)

    reg = pd.read_parquet(CLEAN / "rospatent_inventions.parquet", columns=["reg_no", "app_year", "domestic"])
    reg["reg_no"] = reg.reg_no.astype(str)
    api = pd.read_parquet(CLEAN / "rospatent_api_biblio.parquet", columns=["reg_no", "ipc"])
    a = reg[reg.app_year.between(2015, 2019)].merge(api, on="reg_no")
    a["fields"] = a.ipc.apply(lambda cs: sorted({f for f in map(field_of, cs) if f}))
    a = a[a.fields.str.len() > 0]
    x = a[["domestic", "fields"]].explode("fields")
    x["w"] = 1 / a.fields.str.len().reindex(x.index)
    g = x.groupby(["fields", "domestic"]).w.sum().unstack(fill_value=0)
    foreign = (g[False] / g.sum(axis=1)).rename_axis("field")
    print(f"foreign share computed from {len(a)} granted patents filed 2015-19")

    imp = pd.read_parquet(CLEAN / "ru_imports_hs6.parquet").rename(columns={"hs6": "hs07"})
    imp = imp[imp.year.between(2019, 2021) & imp.hs07.str[:2].astype(int).between(28, 97)]
    v = imp.groupby(["hs07", "group"]).v.mean().unstack(fill_value=0)
    out = []
    for mp in ["industry", "text"]:
        w = pd.read_csv(CLEAN / f"hs07_field_{mp}.csv", dtype={"hs07": str})
        m = w.merge(v.reset_index(), on="hs07")
        m["west_w"] = m.w * m.west
        m["all_w"] = m.w * (m.west + m.china + m.other)
        s = m.groupby("field")[["west_w", "all_w"]].sum()
        out.append(pd.DataFrame({"field": s.index, "map": mp, "west_share": (s.west_w / s.all_w).values}))
    ws = pd.concat(out)
    c = pd.DataFrame({"field": tot.index, "univ_share": univ.values, "size": size.values})
    c["foreign_share"] = c.field.map(foreign)
    c = ws.merge(c, on="field")
    c.to_csv(CLEAN / "field_prewar_characteristics.csv", index=False)
    print(c[c["map"] == "industry"].drop(columns="map").describe().round(3).to_string())


if __name__ == "__main__":
    main()
