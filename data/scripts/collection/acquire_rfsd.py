"""Russian Financial Statements Database (RFSD; Bondarkov, Ledenev & Skougarevskiy 2025), selected columns only
(session 5, 19 Nov 2026; firm-level design, note 12 §4 and AI_CONTEXT §3a).

Source: Hugging Face dataset irlspbru/RFSD (v3.1.0, 2026-09-02; CC BY 4.0), one Parquet file per year 2011-2025,
~7.7 GB in all. The disk had 13 GB free, so the full files are not kept: each year's file (~0.55 GB) is downloaded
to a temporary file, the chosen columns are written out, and the temporary file is deleted before the next year.
(--schema reads only the footer over HTTP Range requests. Reading columns by range was tried and dropped: ~1,900
row groups per file would mean tens of thousands of small requests per year.)

Columns (RF1 in notes/data_decisions.md): identifiers and descriptors (all non-'line_' columns: inn, region,
okved, flags, ...) plus balance-sheet / P&L lines: 1110 intangible assets, 1120 R&D results, 1150 fixed assets,
1600 total assets, 1300 equity, 2110 revenue, 2120 cost of sales, 2200 sales profit, 2400 net profit.
Line meanings follow the Russian statement forms (Form 1 balance sheet, Form 2 P&L); check against the
dataset's descriptive_names_dict.csv before use.

Usage : uv run python -I data/scripts/collection/acquire_rfsd.py [--schema] [--years 2021 2022]
Output: data/raw/rfsd/rfsd_<year>_selected.parquet
"""
import argparse
import sys
import time
from pathlib import Path

import pyarrow.parquet as pq
import requests

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "data" / "raw" / "rfsd"
BASE = "https://huggingface.co/datasets/irlspbru/RFSD/resolve/main/RFSD/year={y}/part-0.parquet"
LINES = ["line_1110", "line_1120", "line_1150", "line_1600", "line_1300",
         "line_2110", "line_2120", "line_2200", "line_2400"]


class RangeFile:
    """Read-only, seekable file over HTTP Range requests (enough for pyarrow's Parquet reader)."""

    def __init__(self, url):
        self.s = requests.Session()
        r = self.s.head(url, allow_redirects=True, timeout=60)
        r.raise_for_status()
        self.url, self.size, self.pos, self.fetched = r.url, int(r.headers["Content-Length"]), 0, 0

    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else self.pos + off if whence == 1 else self.size + off
        return self.pos

    def tell(self):
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        for k in range(5):
            try:
                r = self.s.get(self.url, headers={"Range": f"bytes={self.pos}-{end}"}, timeout=300)
                if r.status_code == 206:
                    break
            except requests.RequestException:
                pass
            time.sleep(10 * (k + 1))
        else:
            raise IOError(f"range request failed at {self.pos}")
        self.pos += len(r.content)
        self.fetched += len(r.content)
        return r.content

    def readable(self):
        return True

    def seekable(self):
        return True

    @property
    def closed(self):
        return False

    def close(self):
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", action="store_true")
    ap.add_argument("--years", type=int, nargs="*", default=list(range(2011, 2026)))
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for y in a.years:
        out = OUT / f"rfsd_{y}_selected.parquet"
        if out.exists() and not a.schema:
            continue
        f = RangeFile(BASE.format(y=y))
        pf = pq.ParquetFile(f)
        names = pf.schema_arrow.names
        if a.schema:
            print(f"{y}: {pf.metadata.num_rows} rows, {pf.metadata.num_row_groups} row groups, {len(names)} columns")
            print("non-line columns:", [c for c in names if not c.startswith("line_")])
            print("wanted lines present:", [c for c in LINES if c in names])
            return
        cols = [c for c in names if not c.startswith("line_")] + [c for c in LINES if c in names]
        t = time.time()
        tmp = OUT / f".tmp_{y}.parquet"
        with requests.get(f.url, stream=True, timeout=600) as r:
            r.raise_for_status()
            with open(tmp, "wb") as g:
                for chunk in r.iter_content(chunk_size=8 << 20):
                    g.write(chunk)
        assert tmp.stat().st_size == f.size, f"{y}: size mismatch"
        tab = pq.read_table(tmp, columns=cols)
        pq.write_table(tab, out, compression="zstd")
        tmp.unlink()
        print(f"{y}: {tab.num_rows} firms, {len(cols)} columns, {f.size / 1e6:.0f} MB downloaded in "
              f"{time.time() - t:.0f}s -> {out.stat().st_size / 1e6:.0f} MB kept", flush=True)


if __name__ == "__main__":
    sys.exit(main())
