"""Researcher mover rates from OpenAlex author affiliations (20 Nov 2026; note 17). Descriptive.

Pool in year y = authors with a Russian affiliation in y-3..y-1 (OA3). Moved in y = a foreign affiliation in y and
no Russian affiliation in y. Also "any foreign affiliation in y" (includes visiting/dual affiliations). By OpenAlex
domain and field of the author's top topic. Input: the trial sample (script 33) or the full file if present.
Output: empirics/results/tables/openalex_movers_year.csv, openalex_movers_field.csv
"""
import collections
import gzip
import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "raw" / "openalex" / "authors"
TAB = ROOT / "empirics" / "results" / "tables"
f = SRC / "all_ru_authors.json.gz"
f = f if f.exists() else SRC / "sample_10000_seed20261120.json.gz"
A = json.load(gzip.open(f, "rt"))
rows = []
for a in A:
    ru, ab = set(), collections.defaultdict(set)
    for x in a.get("affiliations") or []:
        cc = (x.get("institution") or {}).get("country_code")
        for y in x.get("years") or []:
            (ru.add(y) if cc == "RU" else ab[y].add(cc) if cc else None)
    t = (a.get("topics") or [None])[0] or {}
    rows.append({"ru": ru, "ab": ab, "domain": (t.get("domain") or {}).get("display_name"),
                 "field": (t.get("field") or {}).get("display_name")})


def in_pool(x, y):
    return any(y - 3 <= t <= y - 1 for t in x["ru"])


yr = []
for y in range(2013, 2026):
    pool = [x for x in rows if in_pool(x, y)]
    yr.append({"y": y, "pool": len(pool), "abroad_any": sum(y in x["ab"] for x in pool),
               "moved": sum(y in x["ab"] and y not in x["ru"] for x in pool)})
yr = pd.DataFrame(yr).assign(rate_any=lambda d: 100 * d.abroad_any / d.pool, rate_moved=lambda d: 100 * d.moved / d.pool)
yr.to_csv(TAB / "openalex_movers_year.csv", index=False)
print(f"source: {f.name}, {len(A)} authors")
print(yr.round(2).to_string(index=False))
out = []
for key in ("domain", "field"):
    g = collections.defaultdict(list)
    for x in rows:
        g[x[key]].append(x)
    for k, v in g.items():
        r = {"level": key, "name": k, "n_authors": len(v)}
        for lab, ys in (("pre", range(2017, 2022)), ("post", range(2022, 2026))):
            p = sum(in_pool(x, y) for y in ys for x in v)
            m = sum(in_pool(x, y) and y in x["ab"] and y not in x["ru"] for y in ys for x in v)
            r[f"{lab}_pool"], r[f"{lab}_rate"] = p, 100 * m / max(p, 1)
        out.append(r)
out = pd.DataFrame(out)
out.to_csv(TAB / "openalex_movers_field.csv", index=False)
print(out[out.n_authors >= 300].sort_values(["level", "post_rate"], ascending=[True, False]).round(2).to_string(index=False))
