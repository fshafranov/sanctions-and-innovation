"""Rospatent open register of inventions -> one row per granted patent with region, origin, holder type (Design D).

Input : data/raw/rospatent/data-20261102-structure-20180828.csv (downloaded by the user from rospatent.gov.ru/opendata,
        dataset 7730176088-iz, version of 2 Nov 2026; UTF-8 with BOM, 48 columns, granted patents only).
        data/raw/rucities/russia-cities.json, russia-regions.json (github.com/arbaev/russia-cities, 1,109 towns
        with region, one postal code each; 83 regions with ISO 3166-2 codes) for postal code -> region.
        (GeoNames postal codes were the first choice but download.geonames.org did not answer, 12 Nov 2026.)
Output: data/clean/rospatent_inventions.parquet

Rules (notes/data_decisions.md, P1-P7):
  P1 region = 6-digit Russian postal code at the start of the correspondence address. Its first 3 digits (the
     postal "region block") -> region: (a) from the towns' own postal codes; (b) prefixes not covered: the modal
     region of the towns named in the addresses with that prefix (>= 70% agreement, >= 5 addresses). Prefixes
     295-299 (Crimea, Sevastopol) -> "Crimea"; other annexed Ukrainian regions do not use Russian codes here.
  P2 holder country codes "(XX)" after each holder; domestic = all holders RU (no holders: all authors RU);
     foreign priority (Paris convention country other than RU) also makes a patent non-domestic.
  P3 Western co-invention = at least one author with a 2022-coalition country code and at least one RU author.
  P4 holder type from the holder name: university, research institute / state science, firm, individual.
  P5 attorney address = correspondence address mentions a patent attorney ("пат. пов", "патентн").
  P6 individual mass filers: individuals holding >= 1,000 patents filed 2005-17 (as D2) are flagged.
"""
import re
import sys
import json
from collections import Counter, defaultdict
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw" / "rospatent" / "data-20261102-structure-20180828.csv"
CITIES = ROOT / "data" / "raw" / "rucities"
OUT = ROOT / "data" / "clean" / "rospatent_inventions.parquet"

EU27 = "AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE".split()
COALITION = set(EU27 + "US GB CA JP KR TW SG AU NZ CH NO IS LI".split())
COLS = {"registration number": "reg_no", "registration date": "reg_date", "application number": "app_no",
        "application date": "app_date", "authors": "authors", "patent holders": "holders",
        "correspondence address": "address", "paris convention priority country code": "prio_cc",
        "PCT application number": "pct_no", "EA application number": "ea_no", "actual": "actual"}
CC = re.compile(r"\(([A-Z]{2})\)")


def town_index():
    c = json.load(open(CITIES / "russia-cities.json", encoding="utf-8"))
    p3 = defaultdict(Counter)
    name = defaultdict(set)
    for x in c:
        iso = x["region"]["iso_3166-2"]
        if x.get("zip"):
            p3[str(x["zip"]).zfill(6)[:3]][iso] += 1
        for n in {x["name"], x.get("name_alt") or x["name"]}:
            name[n.lower().replace("ё", "е")].add(iso)
    name["москва"] = {"RU-MOW"}
    name["санкт-петербург"] = {"RU-SPE"}
    pref = {k: v.most_common(1)[0][0] for k, v in p3.items()}
    uniq = {k: next(iter(v)) for k, v in name.items() if len(v) == 1}
    return pref, uniq


TOWN = re.compile(r"(?:\bг\.|\bгор\.|\bгород)\s*([А-ЯЁ][а-яё]+(?:[- ][А-ЯЁ]?[а-яё]+)?)")


def town_of(addr, uniq):
    a = addr.replace("ё", "е").replace("Ё", "Е")
    for m in TOWN.finditer(a):
        t = m.group(1).lower()
        for cand in (t, t.split()[0], t.split("-")[0]):
            if cand in uniq:
                return uniq[cand]
    low = a.lower()
    if "москва" in low and "область" not in low and "обл." not in low:
        return "RU-MOW"
    if "санкт-петербург" in low:
        return "RU-SPE"
    return None


def holder_type(h):
    if not isinstance(h, str) or not h.strip():
        return "none"
    s = h.lower()
    if re.search(r"университет|академи[яи] .*образован|образовательное учреждение высшего|институт.*образован|"
                 r"высш[а-я]+ школ", s):
        return "university"
    if re.search(r"научн|институт|российской академии|\bран\b|исследовательск|академи[яи] наук|федеральный центр|"
                 r"государственн[а-я]+ (научн|учрежд)|федеральное государственное бюджетное учреждение", s):
        return "research"
    if re.search(r"общество|акционерн|\bооо\b|\bао\b|\bпао\b|\bзао\b|\bоао\b|предприяти|компани|корпораци|"
                 r"товарищество|завод|фирма|холдинг|limited|ltd|gmbh|inc\.|corp|s\.a\.|\bag\b|\bab\b|\bllc\b|"
                 r"кооператив|унитарн|концерн|группа", s):
        return "firm"
    return "individual"


def main():
    usecols = list(COLS)
    df = pd.read_csv(RAW, usecols=usecols, dtype=str, encoding="utf-8-sig", encoding_errors="replace", keep_default_na=False)
    df = df.rename(columns=COLS)
    n0 = len(df)
    for c in ("reg_date", "app_date"):
        df[c] = pd.to_datetime(df[c].str[:8], format="%Y%m%d", errors="coerce")
    df["app_year"] = df.app_date.dt.year
    df["reg_year"] = df.reg_date.dt.year
    df = df[df.app_date.notna()].copy()
    print(f"rows {n0:,}; with application date {len(df):,}")

    # P2 origin
    df["holder_cc"] = df.holders.map(lambda s: sorted(set(CC.findall(s))))
    df["author_cc"] = df.authors.map(lambda s: CC.findall(s))
    prio_foreign = df.prio_cc.str.strip().ne("") & df.prio_cc.str.strip().ne("RU")
    hold_ru = df.holder_cc.map(lambda l: len(l) > 0 and all(c == "RU" for c in l))
    no_hold = df.holder_cc.map(len).eq(0)
    auth_ru = df.author_cc.map(lambda l: len(l) > 0 and all(c == "RU" for c in l))
    df["domestic"] = (hold_ru | (no_hold & auth_ru)) & ~prio_foreign
    # P3 Western co-invention
    df["n_auth_ru"] = df.author_cc.map(lambda l: sum(c == "RU" for c in l))
    df["n_auth_west"] = df.author_cc.map(lambda l: sum(c in COALITION for c in l))
    df["west_coinvent"] = (df.n_auth_ru > 0) & (df.n_auth_west > 0)
    df["west_holder"] = df.holder_cc.map(lambda l: any(c in COALITION for c in l))
    df["ru_holder"] = df.holder_cc.map(lambda l: "RU" in l)

    # P1 region
    pref, uniq = town_index()
    df["postcode"] = df.address.str.extract(r"^\s*(\d{6})\b", expand=False)
    df["p3"] = df.postcode.str[:3]
    df["town_region"] = df.address.map(lambda a: town_of(a, uniq) if a else None)
    # (b) extend the prefix map from towns named in the addresses
    t = df[df.p3.notna() & df.town_region.notna() & ~df.p3.isin(list(pref))]
    ext = {}
    for k, g in t.groupby("p3").town_region:
        vc = g.value_counts()
        if len(g) >= 5 and vc.iloc[0] / len(g) >= 0.7:
            ext[k] = vc.index[0]
    for k in ("295", "296", "297", "298", "299"):
        ext[k] = "UA-43"  # Crimea and Sevastopol (Natural Earth codes them as Ukraine)
    print(f"prefix map: {len(pref)} from town postal codes, {len(ext)} added from addresses")
    allp = {**ext, **pref}
    df["region"] = df.p3.map(allp)
    df["region_src"] = df.p3.map(lambda k: "town_zip" if k in pref else ("address" if k in ext else "none"))
    # agreement of prefix region with the town named in the same address (validation)
    chk = df[df.region.notna() & df.town_region.notna()]
    print(f"prefix region = town-name region in {(chk.region == chk.town_region).mean():.1%} of {len(chk):,} addresses")

    # P4, P5
    df["holder_type"] = df.holders.map(holder_type)
    df["attorney"] = df.address.str.contains(r"пат\.?\s*пов|патентн|патентный поверенный|patent", case=False,
                                             regex=True)
    # P6 individual mass filers
    first = df.holders.str.split("\n").str[0].str.replace(r"\s*\([A-Z]{2}\)\s*$", "", regex=True).str.strip()
    df["holder1"] = first
    win = df.app_year.between(2005, 2017) & df.holder_type.eq("individual")
    big = df[win].holder1.value_counts()
    mass = set(big[big >= 1000].index)
    print("mass filers (>=1000 grants filed 2005-17):", {m: int(big[m]) for m in mass})
    df["mass_filer"] = df.holder1.isin(mass)

    keep = ["reg_no", "reg_date", "reg_year", "app_no", "app_date", "app_year", "domestic", "west_coinvent",
            "west_holder", "ru_holder", "n_auth_ru", "n_auth_west", "prio_cc", "pct_no", "ea_no", "postcode", "p3",
            "region", "town_region", "region_src", "holder_type", "holder1", "attorney", "mass_filer", "actual"]
    out = df[keep].copy()
    out["holder_cc"] = df.holder_cc.str.join(" ")
    out.to_parquet(OUT, index=False)

    d = out[out.app_year.between(2000, 2026)]
    print(f"filed 2000-26: {len(d):,}; domestic {d.domestic.mean():.1%}; with postcode {d.postcode.notna().mean():.1%}; "
          f"region assigned {d.region.notna().mean():.1%}")
    dd = d[d.domestic]
    print(f"domestic: region assigned {dd.region.notna().mean():.1%}; attorney address {dd.attorney.mean():.1%}; "
          f"west co-invention {dd.west_coinvent.mean():.2%}")
    print(dd.holder_type.value_counts(normalize=True).round(3).to_dict())
    print(pd.crosstab(d.app_year, d.domestic).tail(16))
    print("unassigned domestic prefixes:", dd[dd.region.isna()].p3.value_counts().head(15).to_dict())


if __name__ == "__main__":
    sys.exit(main())
