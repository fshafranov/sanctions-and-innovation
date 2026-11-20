"""Merge World Bank indicators, OpenAlex counts and GSDB sanction measures into one country-year panel.

Inputs:  data/raw/pwt/pwt110_rtfpna_fred.csv (TFP), data/raw/wb/wb_indicators.csv, data/raw/wb/wb_countries.csv, data/raw/openalex/openalex_country_year.csv,
         data/clean/gsdb/gsdb_country_year.csv
Output:  data/processed/country_panel/panel.csv  (ISO3 x year, 1985-2024; World Bank economies, aggregates dropped)

Decisions (notes/data_decisions.md, P1-P4):
  P1 unit = World Bank economy (ISO3); Taiwan has GSDB cases but no WB data and drops out here
  P2 WB missing stays missing (not 0): a missing patent count means "not reported"
  P3 OpenAlex: a country with no works in a year gets 0 (OpenAlex returns only years with works)
  P5 TFP = PWT 11.0 rtfpna via FRED (114 economies; none for Belarus, Syria, Myanmar, North Korea, Cuba)
  P4 pop_ge1m = median population 1995-2023 >= 1 million (base sample flag)
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "clean"

RENAME = {"IP.PAT.RESD": "pat_res", "IP.PAT.NRES": "pat_nres", "IP.JRN.ARTC.SC": "articles_wb",
          "GB.XPD.RSDV.GD.ZS": "rd_gdp", "SP.POP.SCIE.RD.P6": "researchers_pm", "TX.VAL.TECH.MF.ZS": "hitech_share",
          "TX.VAL.TECH.CD": "hitech_usd", "BM.GSR.ROYL.CD": "ip_pay", "BX.GSR.ROYL.CD": "ip_rec",
          "SP.POP.TOTL": "pop", "NY.GDP.PCAP.KD": "gdppc"}


def main():
    meta = pd.read_csv(RAW / "wb" / "wb_countries.csv", keep_default_na=False)
    meta = meta[meta.region != "Aggregates"][["iso3", "iso2", "name", "region", "income"]]
    wb = pd.read_csv(RAW / "wb" / "wb_indicators.csv")
    wb = wb.pivot_table(index=["iso3", "year"], columns="indicator", values="value").rename(columns=RENAME)
    grid = pd.MultiIndex.from_product([meta.iso3, range(1985, 2025)], names=["iso3", "year"]).to_frame(index=False)
    p = grid.merge(meta, on="iso3").merge(wb.reset_index(), on=["iso3", "year"], how="left")

    oa = pd.read_csv(RAW / "openalex" / "openalex_country_year.csv", keep_default_na=False)
    oa = oa[oa.year != ""].astype({"year": int})
    p = p.merge(oa.rename(columns={"works": "works_oa", "works_intl": "works_oa_intl"}),
                on=["iso2", "year"], how="left")
    has_oa = p.iso2.isin(set(oa.iso2) | set(pd.read_csv(RAW / "openalex" / "openalex_country_year.csv",
                                                        keep_default_na=False).iso2))
    for c in ["works_oa", "works_oa_intl"]:
        p.loc[has_oa & p[c].isna() & p.year.between(1990, 2024), c] = 0
    p["intl_share"] = p.works_oa_intl / p.works_oa.where(p.works_oa > 0)

    pwt = pd.read_csv(RAW / "pwt" / "pwt110_rtfpna_fred.csv").rename(columns={"rtfpna": "tfp"})
    p = p.merge(pwt, on=["iso3", "year"], how="left")  # P5: PWT 11.0 rtfpna (2021 = 1), missing stays missing

    gs = pd.read_csv(ROOT / "data" / "clean" / "gsdb" / "gsdb_country_year.csv")
    p = p.merge(gs, on=["iso3", "year"], how="left")
    sanc = [c for c in gs.columns if c not in ("iso3", "year")]
    in_gsdb_years = p.year <= 2023
    p.loc[in_gsdb_years, sanc] = p.loc[in_gsdb_years, sanc].fillna(0)  # no GSDB case = no sanction

    med = p[p.year.between(1995, 2023)].groupby("iso3").pop.median()
    p["pop_ge1m"] = p.iso3.map(med >= 1e6).fillna(False).astype(int)
    p = p.sort_values(["iso3", "year"])
    p.to_csv(ROOT / "data" / "processed" / "country_panel" / "panel.csv", index=False)

    s = p[p.year.between(1995, 2023) & (p.pop_ge1m == 1)]
    print(f"panel: {p.iso3.nunique()} economies, {len(p)} rows; base sample {s.iso3.nunique()} economies")
    print(s[["pat_res", "pat_nres", "articles_wb", "works_oa", "intl_share", "rd_gdp", "researchers_pm",
             "hitech_share", "ip_pay", "tfp"]].notna().sum().to_string())


if __name__ == "__main__":
    main()
