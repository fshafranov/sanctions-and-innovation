"""Design A data: country x technology field x year panels and the field dependence measure (Russia 2014).

Inputs
  data/raw/wipo/unzipped/dc_indicator_patent_4_publication_by_technology.csv
      WIPO "publications by technology": office x origin x field (tec_id 1-35, WIPO IPC-technology concordance)
      x publication year, 2000-2022. Domestic = office == origin (residents at their own office).
  data/raw/oecd/oecd_patents_wipo_fields.csv
      OECD: PCT / EPO / USPTO applications by inventor country x field x priority year, 2000-2022.
  data/raw/wb/wb_countries.csv (ISO2 <-> ISO3)

Outputs (data/clean/)
  field_dependence.csv    field k: dep_frontier = share of world PCT applications 2008-13 in field k with inventors
                          from the 2014 Russia senders (GSDB cases 1004-1011); z-scored across the 35 fields
  field_panel_domestic.csv  iso3 x field x publication year 2000-2021, residents' publications at own office
  field_panel_pct.csv     iso3 x field x priority year 2000-2022, PCT applications by inventor country

Decisions (notes/data_decisions.md, F1-F7)
  F1 senders = GSDB 2014 Russia senders: US, EU28 (incl. UK, HR), Japan, Canada, Australia, New Zealand,
     Switzerland, Norway, Iceland, Liechtenstein, Montenegro, Albania, Ukraine (user: GSDB senders)
  F2 dependence = frontier share from PCT 2008-13 (user); co-invention by field is not in public OECD/WIPO aggregates
  F3 domestic panel ends 2021: WIPO 2022 publications for Russia are incomplete (6,192 vs ~23,000 a year)
  F4 controls: countries with mean >= 500 resident publications a year at their own office in 2008-13
     (domestic panel), or mean >= 100 PCT applications a year in 2008-13 (PCT panel); Ukraine excluded (war from
     2014); aggregates (W, EU27_2020, OECD) dropped (user: all with enough data)
  F6 WIPO codes '**' (not a country office) and 'YU' (Yugoslavia, pre-2003) are dropped
  F5 years with no row in WIPO/OECD for a country-field are set to 0 within the country's observed year range
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "clean"

EU28 = ["AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL", "ITA",
        "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE", "GBR"]
SENDERS_2014 = EU28 + ["USA", "CAN", "JPN", "AUS", "NZL", "CHE", "NOR", "ISL", "LIE", "MNE", "ALB", "UKR"]
AGGREGATES = {"W", "EU27_2020", "OECD", "YUG_F"}


def complete(df, unit, years):
    """Balanced grid of unit x field x year inside each unit's observed year range; missing count -> 0."""
    rng = df.groupby(unit).year.agg(["min", "max"])
    grid = pd.concat([pd.MultiIndex.from_product([[u], range(1, 36), range(max(a, years[0]), min(b, years[1]) + 1)],
                                                 names=[unit, "field", "year"]).to_frame(index=False)
                      for u, (a, b) in rng.iterrows()])
    out = grid.merge(df, on=[unit, "field", "year"], how="left")
    out["count"] = out["count"].fillna(0)
    return out


def main():
    meta = pd.read_csv(RAW / "wb" / "wb_countries.csv", keep_default_na=False)
    iso2_to_3 = dict(zip(meta.iso2, meta.iso3)) | {"TW": "TWN"}

    # --- dependence: frontier share of senders in world PCT 2008-13 -------------------------------------
    o = pd.read_csv(RAW / "oecd" / "oecd_patents_wipo_fields.csv")
    o = o[(o.WIPO != "_T") & o.WIPO.str.startswith("WIPO_")].copy()
    o["field"] = o.WIPO.str[5:].astype(int)
    pct = o[o.PATENT_AUTHORITIES == "9P50_1"].rename(columns={"REF_AREA": "iso3", "TIME_PERIOD": "year",
                                                               "OBS_VALUE": "count"})[["iso3", "field", "year", "count"]]
    pre = pct[pct.year.between(2008, 2013)]
    world = pre[pre.iso3 == "W"].groupby("field")["count"].sum()
    send = pre[pre.iso3.isin(SENDERS_2014)].groupby("field")["count"].sum()
    dep = pd.DataFrame({"world_pct_2008_13": world, "sender_pct_2008_13": send}).reset_index()
    dep["dep_frontier"] = dep.sender_pct_2008_13 / dep.world_pct_2008_13
    dep["dep_frontier_z"] = (dep.dep_frontier - dep.dep_frontier.mean()) / dep.dep_frontier.std()
    names = pd.read_excel(RAW / "wipo" / "unzipped" / "patent_technology_field_names.xlsx")
    dep = dep.merge(names[["class_id", "field_en"]].rename(columns={"class_id": "field"}), on="field")
    dep.to_csv(CLEAN / "field_dependence.csv", index=False)
    print(dep.sort_values("dep_frontier")[["field", "field_en", "dep_frontier"]].round(3).to_string(index=False))

    # --- domestic panel (WIPO publications, residents at own office) -------------------------------------
    w = pd.read_csv(RAW / "wipo" / "unzipped" / "dc_indicator_patent_4_publication_by_technology.csv",
                    keep_default_na=False)
    w = w[(w.office == w.origin) & w.tec_id.between(1, 35) & (w.year <= 2021) & ~w.origin.isin(["**", "YU"])].copy()
    w["iso3"] = w.origin.map(iso2_to_3)
    assert w.iso3.notna().all(), sorted(w.loc[w.iso3.isna(), "origin"].unique())
    w = w.rename(columns={"tec_id": "field"})[["iso3", "field", "year", "count"]]
    pre_mean = w[w.year.between(2008, 2013)].groupby("iso3")["count"].sum() / 6
    keep = set(pre_mean[pre_mean >= 500].index) - {"UKR"}
    dom = complete(w[w.iso3.isin(keep)], "iso3", (2000, 2021))
    dom["sender"] = dom.iso3.isin(SENDERS_2014).astype(int)
    dom.to_csv(CLEAN / "field_panel_domestic.csv", index=False)
    print(f"\ndomestic panel: {dom.iso3.nunique()} countries ({sorted(keep)})")

    # --- PCT panel by inventor country ---------------------------------------------------------------------
    pct = pct[~pct.iso3.isin(AGGREGATES)]
    pre_mean = pct[pct.year.between(2008, 2013)].groupby("iso3")["count"].sum() / 6
    keep = set(pre_mean[pre_mean >= 100].index) - {"UKR"}
    pp = complete(pct[pct.iso3.isin(keep)], "iso3", (2000, 2022))
    pp["sender"] = pp.iso3.isin(SENDERS_2014).astype(int)
    pp.to_csv(CLEAN / "field_panel_pct.csv", index=False)
    print(f"PCT panel: {pp.iso3.nunique()} countries; RUS in panel: {'RUS' in keep}")


if __name__ == "__main__":
    main()
