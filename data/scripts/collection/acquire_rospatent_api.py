"""Russian invention patents (kind C1/C2) with official IPC/CPC, holders, inventors, citations and legal status,
from the Rospatent search platform API (session 5, 19 Nov 2026; replaces the blocked FIPS route, script 21).

API: POST https://searchplatform.rospatent.gov.ru/patsearch/v0.2/search (docs: patent_search_api.docx, "ИС Поисковая
платформа. Описание методов API", 2022). Key: the user's own, from «Разработчикам» → key generation, read from the
environment variable ROSPATENT_TOKEN (set in the user's ~/.zshrc; never stored in the repo or printed).
Test (19 Nov 2026): filings 1-7 Mar 2023 -> 355 documents, all 355 matched to the register; limit 500 works.

Rules (A1-A3 in notes/data_decisions.md)
  A1 query: q="*", filter country=RU, kind in {C1, C2}, application.filing_date in one calendar week (Mon-Sun),
     sort filing_date:asc, limit 500, offset paging if a week has more than 500.
  A2 order: weeks of 2022-01-03 .. 2026-11-15 first (user's priority), then 2021 back to 1994 (extended at the
     user's question, 19 Nov 2026; dataset "ru_since_1994").
  A3 politeness: one request at a time, 1 s pause; on errors wait 30 s, 60 s, ... (max 30 min); stop after 10
     consecutive failures. Resumable: weeks already saved are skipped.
Raw output: data/raw/rospatent_api/weeks/<monday YYYYMMDD>.json.gz  (list of full hit records, as returned)
Usage: zsh -ic 'uv run python -I data/scripts/collection/acquire_rospatent_api.py [--weeks N]'
"""
import argparse
import gzip
import json
import os
import sys
import time
from datetime import date, timedelta
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "raw" / "rospatent_api" / "weeks"
URL = "https://searchplatform.rospatent.gov.ru/patsearch/v0.2/search"
LIMIT, PAUSE, MAX_FAIL = 500, 1.0, 10


def weeks():
    def span(a, b):
        d = a - timedelta(days=a.weekday())
        while d <= b:
            yield d
            d += timedelta(days=7)
    first = list(span(date(2022, 1, 3), date(2026, 11, 15)))
    later = list(span(date(1994, 1, 1), date(2021, 12, 31)))[::-1]  # 2021 back to 1994 (dataset ru_since_1994)
    seen, out = set(), []
    for d in first + later:
        if d not in seen:
            seen.add(d)
            out.append(d)
    return out


def post(s, body):
    fails = 0
    while True:
        try:
            r = s.post(URL, json=body, timeout=180)
            if r.status_code == 200:
                return r.json()
            msg = f"http {r.status_code}: {r.text[:150]!r}"
            if r.status_code in (400, 401, 403):
                raise SystemExit(f"stopping: {msg}")  # bad query or key; do not retry
        except requests.RequestException as e:
            msg = repr(e)[:150]
        fails += 1
        wait = min(30 * 2 ** (fails - 1), 1800)
        print(f"  fail {fails}: {msg}; waiting {wait}s", flush=True)
        if fails >= MAX_FAIL:
            raise SystemExit("stopping: too many consecutive failures")
        time.sleep(wait)


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
               "country": {"values": ["RU"]}, "kind": {"values": ["C1", "C2"]}}
        hits, off, total = [], 0, None
        while True:
            j = post(s, {"q": "*", "limit": LIMIT, "offset": off, "filter": flt, "sort": "filing_date:asc"})
            total = j.get("total", 0) if total is None else total
            if j.get("available", total) < total:
                print(f"  week {w}: available {j.get('available')} < total {total}", flush=True)
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
        if k % 10 == 0 or k == len(todo):
            print(f"{time.strftime('%H:%M')} {k}/{len(todo)} weeks, {ndocs} documents, last week {w}, "
                  f"{(time.time() - t0) / k:.1f} s/week", flush=True)
    print(f"done: {ndocs} documents in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    sys.exit(main())
