"""Russian publications by region x year from OpenAlex, with co-authorship by partner group (Design D).

Source: OpenAlex API (anonymous). OpenAlex cannot group works by institution region, so:
  1. list all Russian institutions with geo.region and works_count (institutions?filter=country_code:RU);
  2. per region, take its institutions (largest first, at most 100 = OpenAlex's OR limit; regions with more than
     100 institutions, i.e. Moscow and St Petersburg, keep the top 100 by works_count; share of works covered is
     written to the manifest);
  3. per region and partner group, one query works?filter=authorships.institutions.lineage:<ids>,<base>[,partner]
     &group_by=publication_year.
     base    = type:article|review, publication_year:2012-2025 (O1 as in 02_get_openalex.py)
     partner = all (none) | coalition (authorships.institutions.country_code in the 2022 coalition) | china (CN);
               each also as *_small with authors_count <= 50 (drops mega-collaborations)
Counting: a work is counted once per region if any author is at one of the region's institutions (full counting
across regions). Lineage filter includes child institutions.
Coalition 2022 (design memo §6): EU27, US, GB, CA, JP, KR, TW, SG, AU, NZ, CH, NO, IS, LI.
Output: data/raw/openalex/regions/institutions_ru.csv, region_year.csv (region, partner, year, works),
        manifest.json. Resumable by (region, partner).
"""
import json
import time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "openalex" / "regions"
OUT.mkdir(parents=True, exist_ok=True)
API = "https://api.openalex.org"
BASE = "type:article|review,publication_year:2012-2025"
EU27 = "AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE".split()
COALITION = EU27 + "US GB CA JP KR TW SG AU NZ CH NO IS LI".split()
PARTNERS = {"all": "", "coalition": "authorships.institutions.country_code:" + "|".join(COALITION),
            "china": "authorships.institutions.country_code:CN"}
# small teams (<= 50 authors): drops mega-collaborations (CERN, JINR, large consortia) that drive co-authorship
PARTNERS.update({k + "_small": ",".join(x for x in (v, "authors_count:<51") if x) for k, v in list(PARTNERS.items())})


def get(path, params):
    for k in range(6):
        try:
            r = requests.get(f"{API}/{path}", params=params, timeout=90)
        except requests.exceptions.RequestException as e:
            print("  network error, retrying:", type(e).__name__)
            time.sleep(10 * (k + 1))
            continue
        if r.status_code == 200:
            return r.json()
        print("  status", r.status_code, r.text[:150])
        time.sleep(10 * (k + 1))
    r.raise_for_status()


def institutions():
    f = OUT / "institutions_ru.csv"
    if f.exists():
        return pd.read_csv(f)
    rows, page = [], 1
    while True:  # page-based paging (cursor paging needs an API key since 2026)
        d = get("institutions", {"filter": "country_code:RU", "per_page": 200, "page": page,
                                 "select": "id,display_name,type,works_count,geo"})
        for i in d["results"]:
            rows.append({"id": i["id"].rsplit("/", 1)[1], "name": i["display_name"], "type": i["type"],
                         "works_count": i["works_count"], "region": (i.get("geo") or {}).get("region"),
                         "city": (i.get("geo") or {}).get("city")})
        if not d["results"] or len(rows) >= d["meta"]["count"]:
            break
        page += 1
    df = pd.DataFrame(rows)
    df.to_csv(f, index=False)
    return df


def main():
    inst = institutions()
    print(f"{len(inst)} institutions, {inst.region.notna().sum()} with region")
    f = OUT / "region_year.csv"
    done = pd.read_csv(f) if f.exists() else pd.DataFrame(columns=["region", "partner", "year", "works"])
    seen = set(zip(done.region, done.partner))
    coverage = {}
    for region, g in inst.dropna(subset=["region"]).groupby("region"):
        g = g.sort_values("works_count", ascending=False)
        top = g.head(100)
        coverage[region] = round(top.works_count.sum() / max(g.works_count.sum(), 1), 4)
        ids = "|".join(top.id)
        for partner, pf in PARTNERS.items():
            if (region, partner) in seen:
                continue
            filt = f"authorships.institutions.lineage:{ids},{BASE}" + (f",{pf}" if pf else "")
            d = get("works", {"filter": filt, "group_by": "publication_year"})
            new = pd.DataFrame([{"region": region, "partner": partner, "year": int(x["key"]), "works": x["count"]}
                                for x in d["group_by"]])
            done = pd.concat([done, new], ignore_index=True)
            done.to_csv(f, index=False)
        print(f"{region}: {len(g)} institutions, top-100 coverage {coverage[region]}")
    json.dump({"downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"), "api": API,
               "base": BASE, "partners": PARTNERS, "top100_works_coverage": coverage,
               "n_regions": len(coverage), "n_rows": len(done)}, open(OUT / "manifest.json", "w"), indent=2)


if __name__ == "__main__":
    main()
