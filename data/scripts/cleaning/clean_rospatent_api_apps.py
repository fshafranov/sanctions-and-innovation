"""Parse the application publications (kind A, script 21c) into one row per application (20 Nov 2026).

Input : data/raw/rospatent_api/weeks_A/*.json.gz
Output: data/clean/rospatent_api_apps.parquet
  app_no, doc_no, filing_date, app_year, pub_date, pub_year, pct (national phase of a PCT application),
  ipc (list of full codes), applicants (list), applicant_cc, inventor_cc, prio_cc, domestic, holder_type, applicant1
Rule AP2 (as P2 for grants): domestic = all applicants RU (no applicants: all inventors RU) and no foreign priority.
Holder type = P4 regex (script 11) on the first applicant.
Checks printed: applications per filing year, domestic share, PCT share, publication lag.
"""
import gzip
import importlib.util
import json
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
WEEKS = ROOT / "data" / "raw" / "rospatent_api" / "weeks_A"
CLEAN = ROOT / "data" / "clean"
CC = re.compile(r"\(([A-Z]{2})\)\s*$")
sp = importlib.util.spec_from_file_location("s11", ROOT / "data" / "scripts" / "cleaning" / "clean_rospatent.py")
s11 = importlib.util.module_from_spec(sp)
sp.loader.exec_module(s11)


def cc(names):
    return [m.group(1) for n in names for m in [CC.search(n or "")] if m]


def row(h):
    c, b = h.get("common", {}), (h.get("biblio", {}) or {}).get("ru", {}) or {}
    ipc = [x.get("fullname", "").replace(" ", "") for x in (c.get("classification", {}) or {}).get("ipc", []) or []]
    appl = [p.get("name", "") for p in b.get("applicant", []) or []]
    inv = [p.get("name", "") for p in b.get("inventor", []) or []]
    fd, pdt = (c.get("application", {}) or {}).get("filing_date", "") or "", c.get("publication_date", "") or ""
    return {
        "app_no": str((c.get("application", {}) or {}).get("number", "")).strip(),
        "doc_no": str(c.get("document_number", "")), "filing_date": fd,
        "app_year": int(fd[:4]) if fd[:4].isdigit() else None, "pub_date": pdt,
        "pub_year": int(pdt[:4]) if pdt[:4].isdigit() else None,
        "pct": "intl_publication" in c or "intl_application" in c,
        "ipc": ipc, "applicants": appl, "applicant_cc": cc(appl), "inventor_cc": cc(inv),
        "prio_cc": [p.get("country") for p in c.get("priority", []) or [] if p.get("country")],
    }


def main():
    rows = []
    files = sorted(WEEKS.glob("*.json.gz"))
    for f in files:
        with gzip.open(f, "rt", encoding="utf-8") as g:
            rows += [row(h) for h in json.load(g)]
    d = pd.DataFrame(rows)
    n0 = len(d)
    d = d.drop_duplicates("app_no")
    hold_ru = d.applicant_cc.map(lambda l: len(l) > 0 and all(c == "RU" for c in l))
    no_hold = d.applicant_cc.map(len).eq(0)
    inv_ru = d.inventor_cc.map(lambda l: len(l) > 0 and all(c == "RU" for c in l))
    prio_foreign = d.prio_cc.map(lambda l: any(c != "RU" for c in l))
    d["domestic"] = (hold_ru | (no_hold & inv_ru)) & ~prio_foreign
    d["applicant1"] = d.applicants.map(lambda l: re.sub(r"\s*\([A-Z]{2}\)\s*$", "", l[0]).strip() if l else "")
    d["holder_type"] = d.applicants.map(lambda l: s11.holder_type(l[0]) if l else "none")
    d.to_parquet(CLEAN / "rospatent_api_apps.parquet", index=False)
    print(f"{len(d):,} applications ({n0 - len(d)} duplicate application numbers dropped) from {len(files)} weeks")
    print(f"with IPC {d.ipc.str.len().gt(0).mean():.3f}; with applicant country {d.applicant_cc.str.len().gt(0).mean():.3f}")
    d["lag"] = d.pub_year - d.app_year
    print(d.groupby("app_year").agg(n=("app_no", "size"), domestic=("domestic", "mean"), pct=("pct", "mean"),
                                    lag=("lag", "mean")).round(3).to_string())


if __name__ == "__main__":
    main()
