"""Parse the Rospatent API weeks (21b) into one row per invention patent (session 5).

Input : data/raw/rospatent_api/weeks/*.json.gz
Output: data/clean/rospatent_api/rospatent_api_biblio.parquet
  reg_no, kind, filing_date, app_year, pub_date, legal_status, dataset,
  ipc (list of full codes, e.g. 'A61K31/7068'), ipc_sub (distinct subclasses), ipc_first (first listed code),
  cpc (list), holders (list of names), holder_cc (list of country codes in parentheses), inventor_cc (list),
  prio_cc (list of priority countries), n_cit (parsed citations), cit_cc (list of cited documents' countries),
  title_ru, address
Checks printed: documents per filing year; share with IPC; agreement with Google IPC subclasses where both exist.
"""
import gzip
import json
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
WEEKS = ROOT / "data" / "raw" / "rospatent_api" / "weeks"
CLEAN = ROOT / "data" / "clean"
CC = re.compile(r"\(([A-Z]{2})\)\s*$")


def cc(names):
    return [m.group(1) for n in names for m in [CC.search(n or "")] if m]


def row(h):
    c, b = h.get("common", {}), h.get("biblio", {}).get("ru", {})
    ipc = [x.get("fullname", "").replace(" ", "") for x in c.get("classification", {}).get("ipc", [])]
    cpc = [x.get("fullname", "").replace(" ", "") for x in c.get("classification", {}).get("cpc", [])]
    holders = [p.get("name", "") for p in b.get("patentee", [])]
    inv = [p.get("name", "") for p in b.get("inventor", [])]
    cits = b.get("citations_parsed", []) or []
    cit_cc = []
    for x in cits:
        ident = (x.get("doc") or {}).get("identity", "") if isinstance(x, dict) else ""
        if re.match(r"[A-Z]{2}", ident or ""):
            cit_cc.append(ident[:2])
    fd = c.get("application", {}).get("filing_date", "")
    return {
        "reg_no": str(int(c.get("document_number", "0"))), "kind": c.get("kind"), "filing_date": fd,
        "app_year": int(fd[:4]) if fd[:4].isdigit() else None, "pub_date": c.get("publication_date"),
        "legal_status": c.get("legal_status"), "dataset": h.get("dataset"),
        "ipc": ipc, "ipc_sub": sorted({x[:4] for x in ipc if len(x) >= 4}), "ipc_first": ipc[0] if ipc else None,
        "cpc": cpc, "holders": holders, "holder_cc": cc(holders), "inventor_cc": cc(inv),
        "prio_cc": [p.get("country") for p in c.get("priority", []) or [] if p.get("country")],
        "n_cit": len(cits), "cit_cc": cit_cc, "title_ru": b.get("title"), "address": b.get("contact_data"),
    }


def main():
    rows = []
    for f in sorted(WEEKS.glob("*.json.gz")):
        with gzip.open(f, "rt", encoding="utf-8") as g:
            rows += [row(h) for h in json.load(g)]
    d = pd.DataFrame(rows).drop_duplicates("reg_no")
    d.to_parquet(ROOT / "data" / "clean" / "rospatent_api" / "rospatent_api_biblio.parquet", index=False)
    print(f"{len(d)} patents from {len(list(WEEKS.glob('*.json.gz')))} weeks")
    print(d.groupby("app_year").agg(n=("reg_no", "size"), with_ipc=("ipc_first", lambda s: s.notna().mean()),
                                    mean_cit=("n_cit", "mean")).round(3).to_string())
    # agreement with Google IPC subclasses (patents in both sources)
    g = pd.read_parquet(ROOT / "data" / "processed" / "title_subclasses" / "rospatent_subclass_top.parquet", columns=["reg_no", "subs", "sub_top"])
    m = d.merge(g, on="reg_no")
    both = m[m.subs.str.len() > 0]
    if len(both):
        same = both.apply(lambda r: bool(set(r.ipc_sub) & set(r.subs)), axis=1).mean()
        print(f"Google vs API IPC, {len(both)} patents in both: share sharing a subclass {same:.3f}")
    top_hit = m[m.ipc_sub.str.len() > 0].apply(lambda r: r.sub_top in r.ipc_sub, axis=1)
    print(f"title classifier top subclass among official API subclasses: {top_hit.mean():.3f} (n={len(top_hit)})")
    print(m.assign(hit=top_hit).groupby("app_year").hit.mean().round(3).to_string())


if __name__ == "__main__":
    main()
