"""Russian invention APPLICATION publications (kind A) from the Rospatent search platform API (20 Nov 2026).

Why: grants (21b) are dated by filing year but arrive with a lag that is longer for foreign applicants, so recent
filing years are truncated, and more so for foreigners. Filings = published applications (A) plus grants that were
never published as applications (fast grants skip A since 2014); the union is built in 23b.

API and key as in 21b (env ROSPATENT_TOKEN, the user's own key; never stored or printed).
Rules (AP1 in notes/data_decisions.md)
  AP1 query: q="*", filter country=RU, kind A, application.filing_date in one calendar week (Mon-Sun),
      sort filing_date:asc, limit 500, offset paging; weeks 2010-01-04 .. 2026-11-15, newest first;
      one request at a time, 1 s pause, back-off as 21b; resumable (weeks already saved are skipped).
Raw output: data/raw/rospatent_api/weeks_A/<monday YYYYMMDD>.json.gz (full hit records, as returned)
Usage: zsh -ic 'uv run python -I data/scripts/collection/acquire_rospatent_api_apps.py [--weeks N]'
"""
import argparse
import gzip
import importlib.util
import json
import os
import sys
import time
from datetime import date, timedelta
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "rospatent_api" / "weeks_A"
sp = importlib.util.spec_from_file_location("s21b", ROOT / "data" / "scripts" / "collection" / "acquire_rospatent_api.py")
s21b = importlib.util.module_from_spec(sp)
sp.loader.exec_module(s21b)
LIMIT, PAUSE = s21b.LIMIT, s21b.PAUSE


def weeks():
    d, out = date(2026, 11, 15), []
    d -= timedelta(days=d.weekday())
    while d >= date(2010, 1, 4):
        out.append(d)
        d -= timedelta(days=7)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--weeks", type=int, default=0, help="fetch at most N new weeks (0 = all)")
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    s = requests.Session()
    s.headers.update({"Authorization": "Bearer " + os.environ["ROSPATENT_TOKEN"],
                      "Content-Type": "application/json"})
    todo = [w for w in weeks() if not (OUT / f"{w:%Y%m%d}.json.gz").exists()]
    if a.weeks:
        todo = todo[:a.weeks]
    print(f"{len(todo)} weeks to fetch", flush=True)
    t0, ndocs = time.time(), 0
    for k, w in enumerate(todo, 1):
        flt = {"application.filing_date": {"range": {"gte": f"{w:%Y%m%d}", "lte": f"{w + timedelta(days=6):%Y%m%d}"}},
               "country": {"values": ["RU"]}, "kind": {"values": ["A"]}}
        hits, off, total = [], 0, None
        while True:
            j = s21b.post(s, {"q": "*", "limit": LIMIT, "offset": off, "filter": flt, "sort": "filing_date:asc"})
            total = j.get("total", 0) if total is None else total
            hits += j.get("hits", [])
            off += LIMIT
            time.sleep(PAUSE)
            if off >= total or not j.get("hits"):
                break
        if len(hits) != total:
            print(f"  week {w}: got {len(hits)} of {total}", flush=True)
        tmp = OUT / f"{w:%Y%m%d}.json.gz.tmp"
        with gzip.open(tmp, "wt", encoding="utf-8") as f:
            json.dump(hits, f, ensure_ascii=False)
        tmp.rename(OUT / f"{w:%Y%m%d}.json.gz")
        ndocs += len(hits)
        if k % 25 == 0 or k == len(todo):
            print(f"{time.strftime('%H:%M')} {k}/{len(todo)} weeks, {ndocs} documents, last week {w}, "
                  f"{(time.time() - t0) / k:.1f} s/week", flush=True)
    print(f"done: {ndocs} documents in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    sys.exit(main())
