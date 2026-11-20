"""Map traded products (HS 2007, 6-digit) to the 35 WIPO technology fields, two ways (notes/09_import_exposure.md).

(A) text: the title classifier of 14_title_field_classifier.py applied to Russian product names from the EAEU tariff
    nomenclature (TN VED, 10-digit codes; the names of all 10-digit lines of an HS6 are joined into one text).
    TN VED is HS 2022 based -> HS 2007 via concord_hs22_hs07.csv (a HS22 code split equally over its HS07 matches).
(B) industry chain: HS07 -> ISIC Rev.4 (R package `concordance`, equal weights) -> NACE Rev.2 group (3-digit; = ISIC4
    group) -> 35 fields via the Dorner & Harhoff (2018, Research Policy) vertical table from IAB FDZ Methodenreport
    07/2017 (data/raw/concordances/iab_dorner_harhoff/, downloaded 12 Nov 2026 from doku.iab.de). The Eurostat
    IPC-NACE2 table was the first choice but its only online copy (EPO forum) is offline.

Input : data/raw/tnved/tnved_tws.xlsx (tws.by, list of current TN VED codes and names, downloaded 12 Nov 2026)
        data/clean/title_field_model.joblib (14), concord_*.csv (16a_export_concordances.R)
Output: data/clean/hs07_field_text.csv, hs07_field_industry.csv  (hs07, field, w; w sums to 1 per hs07)
"""
import __main__
import importlib.util
import re
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "clean"

spec = importlib.util.spec_from_file_location("s14", ROOT / "data" / "scripts" / "processing" / "process_title_fields.py")
s14 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s14)
__main__.Model = s14.Model  # the model was pickled from 14 run as __main__


def text_map():
    t = pd.read_excel(RAW / "tnved" / "tnved_tws.xlsx", sheet_name="ТНВЭД", dtype=str)
    t.columns = ["code", "name", "tariff", "more"]
    t = t[t.code.str.fullmatch(r"\d{10}", na=False)].copy()
    t["hs22"] = t.code.str[:6]
    parts = t.name.str.split("🠺")

    def join(ps):  # unique phrase fragments of all 10-digit lines of a HS6, generic "прочие" dropped
        seen = []
        for p in ps:
            for x in p:
                x = re.sub(r"[:;]\s*$", "", x.strip()).strip()
                if x and x.lower() not in ("прочие", "прочий", "прочая", "прочее") and x not in seen:
                    seen.append(x)
        return " ".join(seen)

    desc = t.assign(parts=parts).groupby("hs22").parts.apply(join)
    desc = desc.str.lower().str.replace("ё", "е")
    print(f"TN VED: {len(t)} 10-digit codes, {len(desc)} HS6 (HS 2022)")
    m = joblib.load(CLEAN / "title_field_model.joblib")
    P = m.proba(desc.values)
    cls = [int(c) for c in m.clf.classes_]
    p = pd.DataFrame(P, index=desc.index, columns=cls)
    for code in ["845710", "300490", "854231", "870323", "880240"]:
        if code in p.index:
            top = p.loc[code].sort_values(ascending=False).head(2)
            print(f"  {code} {desc[code][:70]!r} -> {dict(top.round(2))}")

    c = pd.read_csv(CLEAN / "concord_hs22_hs07.csv", dtype=str).rename(columns={"HS6_6d": "hs22", "HS3_6d": "hs07"})
    c["k"] = 1 / c.groupby("hs22").hs07.transform("size")
    long = p.stack().rename("p").reset_index().rename(columns={"level_1": "field"})
    x = long.merge(c, on="hs22")
    x["w"] = x.p * x.k
    x = x.groupby(["hs07", "field"]).w.sum().reset_index()
    x["w"] /= x.groupby("hs07").w.transform("sum")
    print(f"text map: {x.hs07.nunique()} HS07 codes")
    x.to_csv(CLEAN / "hs07_field_text.csv", index=False)
    return x


def industry_map():
    """HS07 -> ISIC4 (equal weights) -> NACE Rev.2 group (3-digit; ISIC4 and NACE Rev.2 coincide at this level)
    -> 35 fields with the Dorner-Harhoff (2018) vertical table: share of each industry's patents in each field,
    estimated from German inventors linked to their employers (EPO patents 1999-2011)."""
    def dh(level):
        v = pd.read_stata(RAW / "concordances" / "iab_dorner_harhoff" / "vertical tables" /
                          f"corrtab_w08_{level}_area35_ano.dta")
        key = v.columns[0]
        v["nace"] = v[key].astype(str).str.extract(r"^(\d+)")[0].astype(int)
        v = v.drop(columns=key).melt(id_vars="nace", var_name="f", value_name="w_nf")
        v["field"] = v.f.str.split("_").str[1].astype(int)
        return v[v.w_nf > 0][["nace", "field", "w_nf"]]
    v3, v2 = dh(3), dh(2)

    c = pd.read_csv(CLEAN / "concord_hs_isic4.csv", dtype=str).rename(columns={"HS_6d": "hs07", "ISIC4_4d": "isic4"})
    c = c[c.isic4.str.fullmatch(r"\d{4}", na=False)].drop_duplicates()
    c["k"] = 1 / c.groupby("hs07").isic4.transform("size")
    # M3 (session 5 fix): ISIC4 groups do not always exist in NACE Rev.2 (ISIC 2100 pharma = NACE 21.1 + 21.2;
    # ISIC 1701/1702/1709 paper = NACE 17.1/17.2). Use the NACE 3-digit row where it exists, otherwise the
    # 2-digit division row. Before this fix such links were dropped and the HS code's remaining links renormalised
    # (e.g. medicaments 3004 went 2/3 to medical technology via ISIC 3250).
    c["nace"] = c.isic4.str[:3].astype(int)
    has3 = c.nace.isin(set(v3.nace))
    c.loc[~has3, "nace"] = c.loc[~has3, "isic4"].str[:2].astype(int)
    print(f"industry map: {(~has3).sum()} HS-ISIC links use the NACE 2-digit table (ISIC group not in NACE 3-digit)")
    x = pd.concat([c[has3].merge(v3, on="nace"), c[~has3].merge(v2, on="nace")])
    x["w"] = x.k * x.w_nf
    x = x.groupby(["hs07", "field"]).w.sum().reset_index()
    x["w"] /= x.groupby("hs07").w.transform("sum")  # products whose industries file no patents drop out
    print(f"industry map: {x.hs07.nunique()} HS codes (of {c.hs07.nunique()} in the HS-ISIC4 table)")
    x.to_csv(CLEAN / "hs07_field_industry.csv", index=False)
    return x


def compare(a, b):
    m = a.merge(b, on=["hs07", "field"], how="outer", suffixes=("_t", "_i")).fillna(0)
    m = m[m.hs07.isin(set(a.hs07) & set(b.hs07))]
    top_t = a.loc[a.groupby("hs07").w.idxmax()].set_index("hs07").field
    top_i = b.loc[b.groupby("hs07").w.idxmax()].set_index("hs07").field
    both = top_t.index.intersection(top_i.index)
    print(f"text vs industry map, {len(both)} common HS codes: same top field {np.mean(top_t[both] == top_i[both]):.3f}, "
          f"corr of weights {np.corrcoef(m.w_t, m.w_i)[0, 1]:.3f}")


def main():
    a = text_map()
    b = industry_map()
    compare(a, b)


if __name__ == "__main__":
    main()
