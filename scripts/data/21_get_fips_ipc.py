"""Official IPC/CPC codes, legal status and fee status of Russian invention patents from the FIPS document pages
(session 5, 18 Nov 2026; user agreed to collect them, prioritising patents filed 2022+).

Why: the Rospatent open register has no IPC, and Google Patents' RU IPC stops around May 2022 (note 08). Each
register row has a `publication URL` to its FIPS page (www1.fips.ru), which shows field (51) IPC as assigned by
Rospatent's examiners, field (52) CPC, the legal status and the renewal-fee status.

Order (F1 in notes/data_decisions.md): tiers, random order within a tier, so a partial run is a random sample:
  1 domestic, filed 2022-2026, no Google IPC        3 domestic, filed 2015-2020, no Google IPC
  2 domestic, filed 2021, no Google IPC             4 validation: 1,000 random domestic patents WITH Google IPC,
                                                      filed 2018-2021 (FIPS vs Google agreement)
  5 non-domestic, filed 2015+, no Google IPC
Politeness (F2): one request at a time, 0.5 s pause after each, generic client name; on errors wait 30 s, 60 s,
120 s ...; stop after 25 consecutive failures. Resumable: patents already in the output file are skipped.
Raw HTML kept only for the first 200 pages (parser checks).

STATUS: blocked. On 18 Nov 2026 the site answered scripted requests with a DDoS-Guard browser check (HTTP 403);
nothing was collected. Do not work around it; use the Rospatent search platform API instead (token from the user).
Usage:  uv run python -I scripts/data/21_get_fips_ipc.py [--limit N]
Output: data/raw/fips/fips_ipc.csv  reg_no, tier, http, ipc, cpc, status, fee, fetched_at
        (ipc/cpc: codes separated by "; ", e.g. "A61B 5/296 (2021.01)")
        data/raw/fips/html_sample/<reg_no>.html
"""
import argparse
import csv
import html as htmlmod
import random
import re
import sys
import time
from datetime import datetime
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "raw" / "fips"
OUT = OUT_DIR / "fips_ipc.csv"
SAMPLE = OUT_DIR / "html_sample"
URL = "https://www1.fips.ru/fips_servl/fips_servlet?DB=RUPAT&DocNumber={}"
HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; patent-statistics-research)"}
PAUSE, MAX_FAIL, SEED = 0.5, 25, 20261118
FIELDS = ["reg_no", "tier", "http", "ipc", "cpc", "status", "fee", "fetched_at"]


def queue():
    r = pd.read_parquet(ROOT / "data" / "clean" / "rospatent_field_probs.parquet",
                        columns=["reg_no", "app_year", "domestic", "labelled"])
    r = r[r.app_year >= 2015]
    rng = random.Random(SEED)
    tiers = [
        (1, r[r.domestic & ~r.labelled & (r.app_year >= 2022)]),
        (2, r[r.domestic & ~r.labelled & (r.app_year == 2021)]),
        (3, r[r.domestic & ~r.labelled & (r.app_year <= 2020)]),
        (4, r[r.domestic & r.labelled & r.app_year.between(2018, 2021)].sample(1000, random_state=SEED)),
        (5, r[~r.domestic & ~r.labelled]),
    ]
    out = []
    for t, d in tiers:
        ids = d.reg_no.astype(str).tolist()
        rng.shuffle(ids)
        out += [(t, i) for i in ids]
        print(f"tier {t}: {len(ids)} patents")
    return out


def clean(s):
    return re.sub(r"\s+", " ", htmlmod.unescape(re.sub(r"<[^>]+>", " ", s))).strip()


def parse(text):
    ipc_block = re.search(r'<ul class="ipc">(.*?)</ul>', text, re.S)
    ipc = [clean(li) for li in re.findall(r"<li>(.*?)</li>", ipc_block.group(1), re.S)] if ipc_block else []
    spk = re.search(r'<td class="spk"[^>]*>(.*?)</td>', text, re.S)
    cpc = [clean(b) + " " + clean(rest) for b, rest in
           re.findall(r"<b>(.*?)</b>\s*([^<]*)", spk.group(1), re.S)] if spk else []
    cpc = [c.strip() for c in cpc if re.match(r"[A-HY]\d\d[A-Z]", c)]
    st = re.search(r'Статус:\s*</td>\s*<td class="StatusR">(.*?)</td>', text, re.S)
    fee = re.search(r'Пошлина:\s*</td>\s*<td class="StatusR">(.*?)</td>', text, re.S)
    return "; ".join(ipc), "; ".join(cpc), clean(st.group(1)) if st else "", clean(fee.group(1)) if fee else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    SAMPLE.mkdir(exist_ok=True)
    done = set(pd.read_csv(OUT, usecols=["reg_no"], dtype=str).reg_no) if OUT.exists() else set()
    todo = [(t, i) for t, i in queue() if i not in done]
    if a.limit:
        todo = todo[:a.limit]
    print(f"already done: {len(done)}; to fetch now: {len(todo)}", flush=True)
    new = not OUT.exists()
    f = open(OUT, "a", newline="", encoding="utf-8")
    w = csv.DictWriter(f, fieldnames=FIELDS)
    if new:
        w.writeheader()
    s = requests.Session()
    s.headers.update(HEADERS)
    fails, t0, n_ok, n_noipc = 0, time.time(), 0, 0
    n_sample = len(list(SAMPLE.glob("*.html")))
    for k, (tier, reg) in enumerate(todo, 1):
        try:
            resp = s.get(URL.format(reg), timeout=40)
            code = resp.status_code
            text = resp.content.decode("cp1251", errors="replace")
        except requests.RequestException as e:
            code, text = -1, str(e)
        if code == 200 and "IpcTitle" in text or code == 200 and "Документ с данным номером" in text:
            ipc, cpc, st, fee = parse(text)
            w.writerow({"reg_no": reg, "tier": tier, "http": code, "ipc": ipc, "cpc": cpc, "status": st, "fee": fee,
                        "fetched_at": datetime.now().isoformat(timespec="seconds")})
            fails = 0
            n_ok += 1
            n_noipc += ipc == ""
            if n_sample < 200:
                (SAMPLE / f"{reg}.html").write_text(text, encoding="utf-8")
                n_sample += 1
        else:
            fails += 1
            wait = min(30 * 2 ** (fails - 1), 1800)
            print(f"  fail {fails} on {reg}: http {code}; {text[:120]!r}; waiting {wait}s", flush=True)
            if fails >= MAX_FAIL:
                print("too many consecutive failures, stopping", flush=True)
                break
            time.sleep(wait)
            continue
        if k % 250 == 0:
            f.flush()
            el = time.time() - t0
            print(f"{datetime.now():%H:%M} {k}/{len(todo)} fetched, {n_ok} ok, {n_noipc} without IPC, "
                  f"{el / k:.2f} s/page, tier {tier}", flush=True)
        time.sleep(PAUSE)
    f.close()
    print(f"finished: {n_ok} pages in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    sys.exit(main())
