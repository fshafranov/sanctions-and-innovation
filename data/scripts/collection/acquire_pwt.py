"""Penn World Table 11.0 TFP at constant national prices (rtfpna, 2021 = 1), via FRED.

Why FRED: the PWT bulk files on dataverse.nl are behind bot protection that blocks this network (12 Nov 2026).
FRED republishes PWT 11.0 series one country at a time (release "Penn World Table 11.0", vintage 2025-10-28).
Series id: RTFPNA<ISO2>A632NRUG, CSV via https://fred.stlouisfed.org/graph/fredgraph.csv?id=<id> (no API key).
rtfpna is the PWT measure meant for comparisons over time within a country (ctfp is for cross-country levels).
Countries: World Bank economies (aggregates dropped); countries without a FRED series are listed in the manifest.
Output: data/raw/pwt/pwt110_rtfpna_fred.csv (iso3, year, rtfpna), manifest.json
"""
import io
import json
import time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "raw" / "pwt"
OUT.mkdir(parents=True, exist_ok=True)


def main():
    meta = pd.read_csv(ROOT / "data" / "raw" / "wb" / "wb_countries.csv", keep_default_na=False)
    meta = meta[(meta.region != "Aggregates") & (meta.iso2.str.len() == 2)]
    rows, missing = [], []
    for iso2, iso3 in zip(meta.iso2, meta.iso3):
        sid = f"RTFPNA{iso2}A632NRUG"
        r = requests.get("https://fred.stlouisfed.org/graph/fredgraph.csv", params={"id": sid}, timeout=60)
        if r.status_code != 200 or not r.text.startswith("observation_date"):
            missing.append(iso3)
            continue
        d = pd.read_csv(io.StringIO(r.text))
        d.columns = ["date", "rtfpna"]
        d = d[pd.to_numeric(d.rtfpna, errors="coerce").notna()]
        rows.append(pd.DataFrame({"iso3": iso3, "year": pd.to_datetime(d.date).dt.year, "rtfpna": d.rtfpna.astype(float)}))
        time.sleep(0.2)
    out = pd.concat(rows)
    out.to_csv(OUT / "pwt110_rtfpna_fred.csv", index=False)
    json.dump({"downloaded_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
               "source": "FRED, release Penn World Table 11.0 (Feenstra, Inklaar & Timmer)",
               "series_pattern": "RTFPNA<ISO2>A632NRUG", "n_countries": int(out.iso3.nunique()),
               "years": [int(out.year.min()), int(out.year.max())], "no_series": missing},
              open(OUT / "manifest.json", "w"), indent=2)
    print(f"{out.iso3.nunique()} countries, {out.year.min()}-{out.year.max()}; no series for {len(missing)}")
    for c in ["RUS", "IRN", "VEN", "BLR", "SYR", "MMR", "CHN", "PRK", "CUB"]:
        x = out[out.iso3 == c]
        print(c, (x.year.min(), x.year.max()) if len(x) else "none")


if __name__ == "__main__":
    main()
