"""EU export bans on Russia by product and date, from every consolidated version of Council Regulation (EU)
No 833/2014 (notes/10_ban_coverage.md).

Input : data/raw/eu_sanctions/02014R0833-YYYYMMDD.xhtml  35 consolidated versions (2014-09-12 ... 2026-07-24), from the
        EU Publications Office CELLAR API (publications.europa.eu/resource/celex/<CELEX>, Accept:
        application/xhtml+xml), list of versions from its SPARQL endpoint; downloaded 12 Nov 2026. (The EUR-Lex web
        pages answer scripted requests with a bot check, so they were not used.)
        data/clean/concord_hsvintage_hs07.csv (16a_export_concordances.R)
Output: data/clean/eu_ban_codes.csv     version, annex, subtitle, code (as printed), ex (partial "ex" code)
        data/clean/eu_ban_hs07.csv      version date, list, hs07, share (share of the HS07 code's source codes banned),
                                        ex_only (banned only through "ex" codes)

Rules (B1-B4 in notes/data_decisions.md)
  B1 export-ban annexes, identified by the article their title refers to: Art. 3 (Annex II, oil-industry goods;
     an authorisation requirement since 2014), 3b (X, oil refining/LNG), 3c (XI aviation/space; XX jet fuel),
     3h (XVIII luxury), 3k (XXIII and its lettered parts, industrial capacity), 2aa (XXXV firearms), Articles 2/2a
     (XL, the G7 Common High Priority List). Annex VII (advanced technology) has no CN codes and cannot be mapped.
     Import bans, entity lists, port access and anti-circumvention annexes are excluded.
  B2 a code is the first cell of a table row in the annex (or "ex" + the second cell, Annexes X and XVIII): 2-, 4-, 6- or 8-digit CN codes, optionally "ex" (only part
     of the code is banned). It covers every 6-digit code starting with its first min(length, 6) digits.
  B3 HS vintage of the CN codes by version date: HS2012 before 2017, HS2017 2017-2021, HS2022 from 2022; converted to
     HS07 with the R package `concordance`; share = banned source codes / all source codes of the HS07 code.
  B4 lists: "oil2014" = Annex II in versions before 2022; "eu2022" = all B1 annexes from 2022 on.
  B5 Annex XL (G7 Common High Priority List) counted from its first appearance (Dec 2023, then "referred to in
     Article 12g"): its items were mostly export-banned already via Annex VII, which has no CN codes, so XL is the
     best available CN-coded proxy for Annex VII electronics; their ban date is therefore too late (Dec 2023).
"""
import html
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RAW, CLEAN = ROOT / "data" / "raw" / "eu_sanctions", ROOT / "data" / "clean"

ART = re.compile(r"referred to in (?:[Aa]rticles? )(2aa|3b|3c|3h|3k|2, 2a|3)\b(?![a-z])")
CODE = re.compile(r"^(ex\s*)?(\d{2}(?:\s?\d{2}){0,3})$", re.I)


def clean(s):
    s = re.sub(r"<[^>]+>", " ", s)
    return re.sub(r"\s+", " ", html.unescape(s)).strip()


def parse(path):
    t = path.read_text(encoding="utf-8")
    heads = [(m.start(), m.group(1).strip()) for m in
             re.finditer(r'<p class="title-annex-1"[^>]*>\s*ANNEX\s*([IVXL]+[A-Z]?)\s*</p>', t)]
    rows = []
    for k, (pos, annex) in enumerate(heads):
        end = heads[k + 1][0] if k + 1 < len(heads) else len(t)
        seg = t[pos:end]
        sub = clean(seg[:4000])[:300]
        m = ART.search(sub)
        if m:
            art = m.group(1)
        elif annex == "XL" and "Article 12g" in sub:
            art = "12g"  # B5: Common High Priority List before it was tied to Articles 2/2a (Dec 2023 - mid 2025)
        else:
            continue
        for tr in re.finditer(r"<tr\b.*?</tr>", seg, re.S):
            tds = re.findall(r"<td\b.*?</td>", tr.group(0), re.S)
            if not tds:
                continue
            cell = clean(tds[0])
            if cell.lower() in ("", "ex") and len(tds) > 1:  # Annexes X, XVIII: "ex" in its own cell, code next
                cell = (cell + " " + clean(tds[1])).strip()
            cm = CODE.match(cell.replace("\u00a0", " ").replace(".", ""))  # "8542.31" in the Dec 2023 Annex XL
            if cm:
                rows.append({"annex": annex, "article": art, "subtitle": sub[:160],
                             "code": cm.group(2).replace(" ", ""), "ex": bool(cm.group(1))})
        if annex == "XL":  # Dec 2023 layout: list items "8542.31 Electronic integrated circuits ..."
            for li in re.finditer(r'<div class="list">\s*(\d{4}\.\d{2})\s', seg):
                rows.append({"annex": annex, "article": art, "subtitle": sub[:160],
                             "code": li.group(1).replace(".", ""), "ex": False})
    return rows


def vintage(date):
    return "HS2012" if date < "20170101" else ("HS2017" if date < "20220101" else "HS2022")


def main():
    conc = pd.read_csv(CLEAN / "concord_hsvintage_hs07.csv", dtype=str)
    conc["n_src"] = conc.groupby(["vintage", "hs07"]).src.transform("size")
    out = []
    for p in sorted(RAW.glob("02014R0833-*.xhtml")):
        date = p.stem.split("-")[1]
        r = pd.DataFrame(parse(p))
        if r.empty:
            continue
        r.insert(0, "version", date)
        out.append(r)
    codes = pd.concat(out)
    codes = codes[~((codes.article == "3") & (codes.version >= "20220101"))]  # Annex II oil list only pre-2022 (B4)
    codes["list"] = (codes.version < "20220101").map({True: "oil2014", False: "eu2022"})
    codes.to_csv(CLEAN / "eu_ban_codes.csv", index=False)
    print(codes.groupby(["version", "list"]).size().unstack(fill_value=0).to_string())
    print(codes[codes.version == codes.version.max()].groupby(["annex", "article"]).agg(
        n=("code", "size"), ex=("ex", "mean")).round(2).to_string())

    res = []
    for (ver, lst), g in codes.groupby(["version", "list"]):
        c = conc[conc.vintage == vintage(ver)]
        g = g.assign(pre=g.code.str[:6])
        hits = []
        for pre, ex in g.groupby("pre").ex.all().items():  # a prefix is "ex only" if all its entries are ex codes
            s = c[c.src.str.startswith(pre)][["src"]].assign(ex=ex)
            hits.append(s)
        h = pd.concat(hits).groupby("src").ex.all().reset_index()
        m = c.merge(h, on="src")
        agg = m.groupby("hs07").agg(n_ban=("src", "nunique"), n_src=("n_src", "first"), ex_only=("ex", "all"))
        agg["share"] = agg.n_ban / agg.n_src
        agg = agg.reset_index().assign(version=ver, list=lst)
        res.append(agg[["version", "list", "hs07", "share", "ex_only"]])
    r = pd.concat(res)
    r.to_csv(CLEAN / "eu_ban_hs07.csv", index=False)
    print(r.groupby(["version", "list"]).agg(hs07=("hs07", "size"), share_sum=("share", "sum")).round(0).to_string())


if __name__ == "__main__":
    main()
