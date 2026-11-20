"""OECD patent counts by inventor country x WIPO technology field (35) x priority year: PCT, EPO, USPTO filings.

Source: OECD Data Explorer SDMX API, dataflow OECD.STI.PIE / DSD_PATENTS@DF_PATENTS_WIPO ("Patents by WIPO
technology domains"). Query key (dimension order PATENT_AUTHORITIES.FREQ.MEASURE.UNIT_MEASURE.DATE_TYPE.REF_AREA.
PARTNER_AREA.AGENT_ROLE.COOPERATION_TYPE.WIPO.OECD_TECHNOLOGY_PATENT):
  9P50_1+6F0+US50 . A . AP . PATN . PRIORITY . (all countries) . _Z . INVENTOR . _Z . (all fields) . _Z
  = patent applications at WIPO-PCT (9P50_1), EPO (6F0) and USPTO (US50), counted by inventor's country,
    dated by priority year (closest to invention date), all 35 WIPO fields + total, 2000-2024.
Use: (1) the "frontier in senders" dependence measure (pre-2014 world PCT shares by field),
     (2) Russian inventors' international filings by field (secondary outcome, to 2022).
Output: data/raw/oecd/oecd_patents_wipo_fields.csv (as delivered, CSV), manifest.json
"""
import json
from datetime import datetime, timezone
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "raw" / "oecd"
OUT.mkdir(parents=True, exist_ok=True)
URL = ("https://sdmx.oecd.org/public/rest/data/OECD.STI.PIE,DSD_PATENTS@DF_PATENTS_WIPO,/"
       "9P50_1+6F0+US50.A.AP.PATN.PRIORITY.._Z.INVENTOR._Z.._Z")


def main():
    r = requests.get(URL, params={"startPeriod": 2000}, timeout=600,
                     headers={"Accept": "application/vnd.sdmx.data+csv; charset=utf-8"})
    r.raise_for_status()
    (OUT / "oecd_patents_wipo_fields.csv").write_text(r.text)
    n = r.text.count("\n") - 1
    json.dump({"downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"), "url": URL,
               "params": {"startPeriod": 2000}, "rows": n}, open(OUT / "manifest.json", "w"), indent=2)
    print(f"{n} rows")


if __name__ == "__main__":
    main()
