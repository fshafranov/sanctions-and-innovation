"""GSDB V4 case list -> country-year sanction measures.

Input:  data/raw/gsdb/GSDB_V4.csv (case level: case_id, sanctioned_state, sanctioning_state, begin, end, type dummies)
        data/raw/wb/wb_countries.csv (target universe: World Bank economies, aggregates dropped)
Output: data/clean/gsdb/gsdb_cases_long.csv   one row per case x target country (after splitting lists)
        data/clean/gsdb/gsdb_country_year.csv one row per ISO3 x year (1985-2023), zeros where no case

Decisions (notes/data_decisions.md, G1-G7):
  G1 multi-target rows are split, one case per listed country (user, 11 Nov 2026)
  G2 non-state / bloc targets dropped (EU, ECOWAS, EEU, Comecon, Balkans, League of Arab States,
     ICC Rome Statute Signatories, Terrorist Organizations ...) (user)
  G3 'Yugoslavia' -> Serbia (SRB) for all years; Hong Kong and Palestine kept as own units (HKG, PSE) (user)
  G4 Western senders = US, EU, UN, UK, Canada, Japan, Australia, Switzerland, Norway (user: "broader Western group")
  G5 economic case = trade == 1 or financial == 1; placebo case = Western case with no trade/financial measure
     (only arms, military, travel or other)
  G6 a case is in force in every year begin..end (inclusive)
  G7 GSDB keeps historical names for present-day states; mapped by name: South Vietnam -> VNM, Yemen, North -> YEM,
     Transjordan -> JOR, Ceylon -> LKA, Malaya -> MYS, Malagasy Republic -> MDG (name artefacts, e.g. case 1364
     'South Vietnam' 2022). Soviet Union -> RUS; Czechoslovakia -> CZE and SVK (both). These two only matter for the
     5-year clean window of 1995-96 events (Soviet cases end 1991, Czechoslovak case 68 ends 1991). Provisional.
  G7b German Democratic Republic, North Vietnam, Rhodesia: all cases end before 1990, dropped.
  G8 'Cyprus (Northern)' (case 179, Cyprus vs Northern Cyprus) dropped as a non-state target.
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "clean" / "gsdb"
OUT.mkdir(parents=True, exist_ok=True)

WESTERN = {"United States", "EU", "UN", "United Kingdom", "Canada", "Japan", "Australia", "Switzerland", "Norway"}
NON_STATE = {"Cyprus (Northern)", "EU", "EEC", "Western countries", "ECOWAS", "EEU", "Comecon", "Balkans", "League of Arab States", "ICC Rome Statute Signatories"}
SUFFIXES = {"North", "South", "The", "Democratic Republic of the", "Arab Rep."}  # second halves of comma names
NAME_TO_ISO3 = {  # GSDB name -> ISO3 where the World Bank name differs (mechanical)
    "Bahamas": "BHS", "Brunei": "BRN", "Cape Verde": "CPV", "Ceylon": "LKA", "Congo (Brazzaville)": "COG",
    "Congo, Democratic Republic of the": "COD", "Cote d'Ivoire": "CIV", "Egypt, Arab Rep.": "EGY", "Ethiopia (excludes Eritrea)": "ETH", "Gambia, The": "GMB", "Hong Kong": "HKG",
    "Iran": "IRN", "Korea, North": "PRK", "Korea, South": "KOR", "Kyrgyzstan": "KGZ", "Laos": "LAO",
    "Macedonia": "MKD", "Malagasy Republic": "MDG", "Malaya": "MYS", "Micronesia": "FSM", "Palestine": "PSE",
    "Russia": "RUS", "Slovakia": "SVK", "St. Lucia": "LCA", "Syria": "SYR", "Taiwan": "TWN", "Turkey": "TUR",
    "Venezuela": "VEN", "Vietnam": "VNM", "Yemen": "YEM", "Yemen, South": "YEM", "Yugoslavia": "SRB",
    "Burma": "MMR", "Myanmar": "MMR", "Swaziland": "SWZ", "Czech Republic": "CZE", "Zaire": "COD",
    "South Vietnam": "VNM", "Yemen, North": "YEM", "Transjordan": "JOR", "Soviet Union": "RUS",
    "Somalia": "SOM", "Bosnia and Herzegovina": "BIH", "Kosovo": "XKX", "Moldova": "MDA", "Tanzania": "TZA", "Egypt": "EGY",
}


def split_names(s):
    """Split a GSDB list on commas, re-attaching suffixes such as 'Korea, North'."""
    out = []
    for tok in (t.strip() for t in s.split(",")):
        if not tok:
            continue
        if out and tok in SUFFIXES:
            out[-1] = f"{out[-1]}, {tok}"
        else:
            out.append(tok)
    return out


def main():
    g = pd.read_csv(RAW / "gsdb" / "GSDB_V4.csv", encoding="latin-1")
    meta = pd.read_csv(RAW / "wb" / "wb_countries.csv", keep_default_na=False)
    meta = meta[meta.region != "Aggregates"]
    wb_name = dict(zip(meta.name, meta.iso3))
    universe = set(meta.iso3) | {"TWN"}  # Taiwan is not a WB economy; kept so its cases are visible

    g["targets"] = g.sanctioned_state.map(split_names)
    g["senders"] = g.sanctioning_state.map(split_names)
    long = g.explode("targets").rename(columns={"targets": "target"})
    long = long[~long.target.isin(NON_STATE) & ~long.target.str.startswith("Terrorist Organizations")]

    # states that ended before the analysis window: dropped, checked to end before 1990 (G7)
    gone = long.target.isin({"German Democratic Republic", "North Vietnam", "Rhodesia"})
    assert (long.loc[gone, "end"] < 1990).all(), "pre-window state in force after 1989"
    long = long[~gone]
    # Czechoslovakia -> both successor states (G7)
    cz = long.target == "Czechoslovakia"
    long = pd.concat([long[~cz], long[cz].assign(target="Czech Republic"), long[cz].assign(target="Slovakia")])

    long["iso3"] = long.target.map(lambda n: NAME_TO_ISO3.get(n, wb_name.get(n)))
    unmatched = sorted(long.loc[long.iso3.isna(), "target"].unique())
    assert not unmatched, f"unmatched GSDB names: {unmatched}"
    outside = sorted(set(long.iso3) - universe)
    assert not outside, f"ISO3 outside WB universe: {outside}"

    long["western"] = long.senders.map(lambda s: bool(WESTERN & set(s)))
    long["econ"] = (long.trade == 1) | (long.financial == 1)
    long["n_senders"] = long.senders.map(len)
    long["groups"] = long.apply(lambda r: [k for k, ok in {
        "west_econ": r.western and r.econ,
        "west_placebo": r.western and not r.econ,
        "any_econ": r.econ}.items() if ok], axis=1)
    long[["case_id", "target", "iso3", "begin", "end", "trade", "financial", "arms", "military", "travel",
          "other", "western", "econ", "n_senders", "sanctioning_state", "objective"]].to_csv(
        OUT / "gsdb_cases_long.csv", index=False)

    years = range(1985, 2024)
    cy = [(r.iso3, y, grp, int(y == r.begin)) for r in long.itertuples()
          for y in range(max(r.begin, 1985), min(r.end, 2023) + 1) for grp in r.groups]
    cy = pd.DataFrame(cy, columns=["iso3", "year", "group", "new"])
    agg = cy.groupby(["iso3", "year", "group"]).agg(n_active=("new", "size"), n_new=("new", "sum")).reset_index()
    wide = agg.pivot_table(index=["iso3", "year"], columns="group", values=["n_active", "n_new"], fill_value=0)
    wide.columns = [f"{a}_{b}" for a, b in wide.columns]
    grid = pd.MultiIndex.from_product([sorted(universe), years], names=["iso3", "year"]).to_frame(index=False)
    out = grid.merge(wide.reset_index(), on=["iso3", "year"], how="left").fillna(0)
    for grp in ["west_econ", "west_placebo", "any_econ"]:
        for c in [f"n_active_{grp}", f"n_new_{grp}"]:
            if c not in out:
                out[c] = 0
            out[c] = out[c].astype(int)
        out[f"new_{grp}"] = (out[f"n_new_{grp}"] > 0).astype(int)
        # episode: a case begins in t and no case of the group was in force in t-1..t-5 (window starts 1985)
        prev = sum(out.groupby("iso3")[f"n_active_{grp}"].shift(k) for k in range(1, 6))
        out[f"episode5_{grp}"] = ((out[f"new_{grp}"] == 1) & (prev == 0)).astype(int)
        out.loc[prev.isna(), f"episode5_{grp}"] = pd.NA
    out.to_csv(OUT / "gsdb_country_year.csv", index=False)

    s = out[out.year.between(1995, 2023)]
    print(f"cases after split: {long.case_id.nunique()} cases, {len(long)} case-targets")
    for grp in ["west_econ", "west_placebo", "any_econ"]:
        print(f"{grp:13s} 1995-2023: onset years {int(s[f'new_{grp}'].sum())}, "
              f"5-yr-clean episodes {int(s[f'episode5_{grp}'].sum())}, "
              f"countries ever active {s.loc[s[f'n_active_{grp}'] > 0, 'iso3'].nunique()}")


if __name__ == "__main__":
    main()
