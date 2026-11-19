"""EU ban coverage and Western imports by IPC subclass (session 5; the subclass version of scripts 16 + 17 + 19).

Two product -> subclass maps, as for fields (M1):
  text     : the subclass title classifier (14b) on Russian TN VED product names (HS22 -> HS07 as in 16).
  industry : HS07 -> ISIC4 (equal weights) -> NACE Rev.2 group -> IPC subclasses via the Dorner-Harhoff (2018)
             vertical table at the IPC4 level, fractional version (corrtab_w08_3_ipc4_frac_ano.dta); NACE groups
             missing from the 3-digit table use the 2-digit table (M3).
Coverage (C1 at subclass level): share of 2019-21 Western manufactured imports (HS 28-97) mapped to the subclass
that is banned at the end of year y (eu2022 list), y = 2022..2026. Plus Western/Chinese imports by subclass x year.

Input : data/clean/eu_ban_hs07.csv, ru_imports_hs6.parquet, concord_hs_isic4.csv, concord_hs22_hs07.csv,
        title_subclass_model.joblib (14b), data/raw/tnved/tnved_tws.xlsx, Dorner-Harhoff ipc4 tables
Output: data/clean/hs07_subclass_{text,industry}.csv  (hs07, subclass, w; w sums to 1 per hs07)
        data/clean/subclass_ban_coverage.csv          map, year, subclass, coverage, coverage_noex, west_pre
        data/clean/subclass_imports_year.csv          map, subclass, year, west, china
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
DH = RAW / "concordances" / "iab_dorner_harhoff" / "vertical tables"

spec = importlib.util.spec_from_file_location("s14b", ROOT / "scripts" / "data" / "14b_title_subclass_classifier.py")
s14b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s14b)
__main__.Model = s14b.Model  # pickled from 14b run as __main__


def tnved_names():
    t = pd.read_excel(RAW / "tnved" / "tnved_tws.xlsx", sheet_name="ТНВЭД", dtype=str)
    t.columns = ["code", "name", "tariff", "more"]
    t = t[t.code.str.fullmatch(r"\d{10}", na=False)].copy()
    t["hs22"] = t.code.str[:6]
    parts = t.name.str.split("🠺")

    def join(ps):
        seen = []
        for p in ps:
            for x in p:
                x = re.sub(r"[:;]\s*$", "", x.strip()).strip()
                if x and x.lower() not in ("прочие", "прочий", "прочая", "прочее") and x not in seen:
                    seen.append(x)
        return " ".join(seen)

    return t.assign(parts=parts).groupby("hs22").parts.apply(join).str.lower().str.replace("ё", "е")


def text_map(top=10):
    desc = tnved_names()
    m = joblib.load(CLEAN / "title_subclass_model.joblib")
    P = m.proba(desc.values)
    cls = m.clf.classes_
    idx = np.argsort(-P, axis=1)[:, :top]  # keep the 10 most likely subclasses per product, renormalised
    rows = [(h, cls[j], P[i, j]) for i, h in enumerate(desc.index) for j in idx[i]]
    p = pd.DataFrame(rows, columns=["hs22", "subclass", "p"])
    for code in ["851762", "300490", "854231", "870323", "845710"]:
        print("  text", code, p[p.hs22 == code].nlargest(3, "p")[["subclass", "p"]].round(2).values.tolist())
    c = pd.read_csv(CLEAN / "concord_hs22_hs07.csv", dtype=str).rename(columns={"HS6_6d": "hs22", "HS3_6d": "hs07"})
    c["k"] = 1 / c.groupby("hs22").hs07.transform("size")
    x = p.merge(c, on="hs22")
    x["w"] = x.p * x.k
    x = x.groupby(["hs07", "subclass"]).w.sum().reset_index()
    x["w"] /= x.groupby("hs07").w.transform("sum")
    return x


def industry_map():
    def dh(level):
        v = pd.read_stata(DH / f"corrtab_w08_{level}_ipc4_frac_ano.dta")
        key = v.columns[0]
        v["nace"] = v[key].astype(str).str.extract(r"^(\d+)")[0].astype(int)
        v = v.drop(columns=key).melt(id_vars="nace", var_name="f", value_name="w_nf")
        v["subclass"] = v.f.str.replace("ipc4_", "", regex=False)
        return v[v.w_nf > 0][["nace", "subclass", "w_nf"]]
    v3, v2 = dh(3), dh(2)
    c = pd.read_csv(CLEAN / "concord_hs_isic4.csv", dtype=str).rename(columns={"HS_6d": "hs07", "ISIC4_4d": "isic4"})
    c = c[c.isic4.str.fullmatch(r"\d{4}", na=False)].drop_duplicates()
    c["k"] = 1 / c.groupby("hs07").isic4.transform("size")
    c["nace"] = c.isic4.str[:3].astype(int)
    has3 = c.nace.isin(set(v3.nace))
    c.loc[~has3, "nace"] = c.loc[~has3, "isic4"].str[:2].astype(int)
    x = pd.concat([c[has3].merge(v3, on="nace"), c[~has3].merge(v2, on="nace")])
    x["w"] = x.k * x.w_nf
    x = x.groupby(["hs07", "subclass"]).w.sum().reset_index()
    x["w"] /= x.groupby("hs07").w.transform("sum")
    for code in ["851762", "300490", "854231", "870323"]:
        print("  industry", code, x[x.hs07 == code].nlargest(3, "w")[["subclass", "w"]].round(2).values.tolist())
    return x


def main():
    maps = {"text": text_map(), "industry": industry_map()}
    for k, v in maps.items():
        print(f"{k} map: {v.hs07.nunique()} HS07 codes, {v.subclass.nunique()} subclasses")
        v.to_csv(CLEAN / f"hs07_subclass_{k}.csv", index=False)

    ban = pd.read_csv(CLEAN / "eu_ban_hs07.csv", dtype={"hs07": str, "version": str})
    ban = ban[ban.list == "eu2022"]
    imp = pd.read_parquet(CLEAN / "ru_imports_hs6.parquet").rename(columns={"hs6": "hs07"})
    imp = imp[imp.hs07.str[:2].astype(int).between(28, 97)]
    W = imp[(imp.group == "west") & imp.year.between(2019, 2021)].groupby("hs07").v.mean().rename("W").reset_index()

    cov, flows = [], []
    for k, mp in maps.items():
        for y in range(2022, 2027):
            vers = ban.version[ban.version <= f"{y}1231"].max()
            bv = ban[ban.version == vers][["hs07", "share", "ex_only"]]
            x = W.merge(mp, on="hs07").merge(bv, on="hs07", how="left")
            x["share"] = x.share.fillna(0)
            x["share_noex"] = x.share.where(~x.ex_only.fillna(False).astype(bool), 0)
            x["den"] = x.w * x.W
            g = x.assign(num=x.den * x.share, num2=x.den * x.share_noex).groupby("subclass")[["num", "num2", "den"]].sum()
            cov.append(pd.DataFrame({"map": k, "year": y, "subclass": g.index, "coverage": (g.num / g.den).values,
                                     "coverage_noex": (g.num2 / g.den).values, "west_pre": g.den.values}))
        f = imp[imp.group.isin(["west", "china"])].merge(mp, on="hs07")
        f["v"] = f.v * f.w
        flows.append(f.groupby(["subclass", "year", "group"]).v.sum().unstack("group").fillna(0)
                     .reset_index().assign(map=k))
    cov = pd.concat(cov)
    # subclass -> WIPO field (Schmoch 2008 table): the subclass entry, else the field most of its groups map to
    sp = importlib.util.spec_from_file_location("s10", ROOT / "scripts" / "data" / "10_build_ru_patent_fields.py")
    s10 = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(s10)
    by_group, by_sub, _ = s10.concordance()
    grp = pd.DataFrame([(s, f) for (s, _), f in by_group.items()], columns=["subclass", "field"])
    modal = grp.groupby("subclass").field.agg(lambda z: z.value_counts().index[0])
    cov["field"] = cov.subclass.map(by_sub).fillna(cov.subclass.map(modal))
    print("subclasses without a WIPO field:", cov[cov.field.isna()].subclass.nunique())
    cov.to_csv(CLEAN / "subclass_ban_coverage.csv", index=False)
    pd.concat(flows).to_csv(CLEAN / "subclass_imports_year.csv", index=False)
    s = cov[cov.year == 2023].pivot(index="subclass", columns="map", values="coverage")
    print(s.describe().round(3))
    print("corr text vs industry (2023):", round(s.text.corr(s.industry), 2))
    print("highest (industry):", s.industry.nlargest(8).round(2).to_dict())
    print("lowest (industry):", s.industry.nsmallest(8).round(2).to_dict())


if __name__ == "__main__":
    main()
