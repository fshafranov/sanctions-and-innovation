"""OpenAlex authors with a Russian affiliation (20 Nov 2026; emigration channel, note 17).

Each author record has affiliations with the years in which the author published there, and research topics.
Rules (OA1-OA2 in notes/data_decisions.md)
  OA1 filter: affiliations.institution.country_code:RU and works_count > 4 (655k authors on 20 Nov 2026);
      fields kept: id, works_count, affiliations, topics, last_known_institutions. Anonymous API, no key.
  OA2 trial: random sample of 10,000 (sample=10000, seed=20261120; 61 s). Full run: cursor paging over all
      matching authors (~3,300 requests, about an hour), --full.
Output: data/raw/openalex/authors/sample_10000_seed20261120.json.gz (trial) or all_ru_authors.json.gz (--full)
Usage: uv run python -I data/scripts/collection/acquire_openalex_authors.py [--full]
"""
import argparse
import gzip
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "openalex" / "authors"
FLT = "affiliations.institution.country_code:RU,works_count:>4"
SEL = "id,works_count,affiliations,topics,last_known_institutions"


def get(**p):
    u = "https://api.openalex.org/authors?" + urllib.parse.urlencode(p)
    for k in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "research-script"}),
                                        timeout=90) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001
            print("retry", k, e, flush=True)
            time.sleep(5 * (k + 1))
    raise SystemExit("failed: " + u)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--full", action="store_true")
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    t0, rows = time.time(), []
    print("authors matching:", get(filter=FLT, per_page=1)["meta"]["count"], flush=True)
    if a.full:
        cur, name = "*", "all_ru_authors.json.gz"
        while cur:
            d = get(filter=FLT, per_page=200, cursor=cur, select=SEL)
            rows += d["results"]
            cur = d["meta"].get("next_cursor")
            if len(rows) % 20000 < 200:
                print(f"{len(rows)} authors, {time.time() - t0:.0f}s", flush=True)
            time.sleep(0.1)
    else:
        name = "sample_10000_seed20261120.json.gz"
        for page in range(1, 51):
            rows += get(filter=FLT, sample=10000, seed=20261120, per_page=200, page=page, select=SEL)["results"]
            time.sleep(0.2)
    with gzip.open(OUT / name, "wt") as f:
        json.dump(rows, f)
    print(f"{len(rows)} authors in {time.time() - t0:.0f}s -> {name}")


if __name__ == "__main__":
    main()
