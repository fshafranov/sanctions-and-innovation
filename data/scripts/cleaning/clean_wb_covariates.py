"""Country-level covariates for synthetic DiD (World Bank WDI), separate from the outcome panel.

Source: World Bank WDI bulk file https://databankfiles.worldbank.org/public/ddpext_download/WDI_CSV.zip
        (283 MB, last modified 8 Oct 2026; downloaded 12 Nov 2026 because the WDI API returned HTTP 502 for every
        request that day). Kept in data/raw/wb/wdi_bulk/; only the indicators below are extracted.
        Download: curl -L -o data/raw/wb/wdi_bulk/WDI_CSV.zip <url above>
Output: data/clean/wb/covariates_country_year.csv (iso3, year, one column per covariate, 1990-2024)
GDP per capita, population, R&D % GDP and researchers come from the outcome panel (01_get_wb.py).
"""
import zipfile
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
ZIP = ROOT / "data" / "raw" / "wb" / "wdi_bulk" / "WDI_CSV.zip"
OUT = ROOT / "data" / "clean" / "wb" / "covariates_country_year.csv"

INDICATORS = {
    "NY.GDP.PETR.RT.ZS": "oil_rents",        # Oil rents (% of GDP)
    "NY.GDP.NGAS.RT.ZS": "gas_rents",        # Natural gas rents (% of GDP)
    "NY.GDP.TOTL.RT.ZS": "resource_rents",   # Total natural resources rents (% of GDP)
    "NE.TRD.GNFS.ZS": "trade_gdp",           # Trade (% of GDP)
    "BX.KLT.DINV.WD.GD.ZS": "fdi_in_gdp",    # FDI, net inflows (% of GDP)
    "TM.VAL.MANF.ZS.UN": "manuf_imp_share",  # Manufactures imports (% of merchandise imports)
    "NV.IND.MANF.ZS": "manuf_va_gdp",        # Manufacturing, value added (% of GDP)
    "SP.URB.TOTL.IN.ZS": "urban_share",      # Urban population (% of total)
    "SE.TER.ENRR": "tertiary_enrol",         # School enrollment, tertiary (% gross)
}


def main():
    with zipfile.ZipFile(ZIP) as z:
        name = next(n for n in z.namelist() if n.lower().endswith("csv.csv") and "series" not in n.lower()
                    and "country" not in n.lower() and "footnote" not in n.lower())
        print("reading", name)
        w = pd.read_csv(z.open(name))
    w = w[w["Indicator Code"].isin(INDICATORS)]
    years = [c for c in w.columns if c.isdigit() and 1990 <= int(c) <= 2024]
    long = w.melt(id_vars=["Country Code", "Indicator Code"], value_vars=years, var_name="year", value_name="value")
    long = long.dropna(subset=["value"]).assign(year=lambda d: d.year.astype(int))
    out = long.pivot_table(index=["Country Code", "year"], columns="Indicator Code", values="value")
    out = out.rename(columns=INDICATORS).reset_index().rename(columns={"Country Code": "iso3"})
    out.to_csv(OUT, index=False)
    print(out.groupby("year").count().loc[[2000, 2010, 2020]].T)
    assert set(INDICATORS.values()) <= set(out.columns), "indicator missing in the bulk file"


if __name__ == "__main__":
    main()
