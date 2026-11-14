"""Region x year panel for Design D maps and the pre/post-2022 comparison.

Inputs : data/clean/rospatent_inventions.parquet (11_parse_rospatent_register.py)
         data/raw/openalex/regions/region_year.csv (09_get_openalex_regions.py)
         data/raw/rucities/russia-regions.json (ISO codes, names, population)
Outputs: data/clean/region_crosswalk.csv   OpenAlex region name -> ISO 3166-2
         data/clean/region_year_panel.csv  ISO x year: patents (domestic, by holder type, attorney-free), Western
                                           co-invention, publications (all/small teams, coalition, China)
         data/clean/region_exposure.csv    ISO: exposure measures (pre-2022) and pre/post changes
         data/clean/region_exposure_2014.csv  same for 2014: pre 2011-13 (articles 2012-13, OpenAlex series
                                           starts 2012), post 2014-16, co-invention 2006-13
Rules: P7 patents dated by application (filing) year, domestic only, individual mass filers dropped;
       2022: pre = 2019-21, post = 2022-24 (2025 filings still incomplete because of the grant lag);
       2014: pre = 2011-13, post = 2014-16. Exposure uses the 2022 coalition in both (2014 senders are a subset).
       X1 science exposure = coalition co-authored share of small-team (<= 50 authors) articles 2019-21.
       X2 invention exposure = share of domestic-holder grants filed 2012-21 with a coalition co-inventor or
          co-holder (patents where a Russian holder or inventor works with the West).
"""
import json
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
CLEAN = ROOT / "data" / "clean"

OA = {"Adygeya Republic": "RU-AD", "Altai": "RU-AL", "Altai Krai": "RU-ALT", "Amur Oblast": "RU-AMU",
      "Arkhangelskaya": "RU-ARK", "Astrakhan Oblast": "RU-AST", "Bashkortostan Republic": "RU-BA",
      "Belgorod Oblast": "RU-BEL", "Bryansk Oblast": "RU-BRY", "Buryatiya Republic": "RU-BU", "Chechnya": "RU-CE",
      "Chelyabinsk": "RU-CHE", "Chuvash Republic": "RU-CU", "Dagestan": "RU-DA", "Ingushetiya Republic": "RU-IN",
      "Irkutsk Oblast": "RU-IRK", "Ivanovo Oblast": "RU-IVA", "Jewish Autonomous Oblast": "RU-YEV",
      "Kabardino-Balkariya Republic": "RU-KB", "Kaliningrad Oblast": "RU-KGD", "Kalmykiya Republic": "RU-KL",
      "Kaluga Oblast": "RU-KLU", "Kamchatka": "RU-KAM", "Karachayevo-Cherkesiya Republic": "RU-KC",
      "Karelia": "RU-KR", "Khabarovsk": "RU-KHA", "Khakasiya Republic": "RU-KK", "Khanty-Mansia": "RU-KHM",
      "Kirov Oblast": "RU-KIR", "Komi": "RU-KO", "Kostroma Oblast": "RU-KOS", "Krasnodar Krai": "RU-KDA",
      "Krasnoyarsk Krai": "RU-KYA", "Kurgan Oblast": "RU-KGN", "Kursk Oblast": "RU-KRS", "Kuzbass": "RU-KEM",
      "Leningradskaya Oblast'": "RU-LEN", "Lipetsk Oblast": "RU-LIP", "Magadan Oblast": "RU-MAG",
      "Mariy-El Republic": "RU-ME", "Mordoviya Republic": "RU-MO", "Moscow": "RU-MOW", "Moscow Oblast": "RU-MOS",
      "Murmansk": "RU-MUR", "Nenets": "RU-NEN", "Nizhny Novgorod Oblast": "RU-NIZ",
      "North Ossetia–Alania": "RU-SE", "Novgorod Oblast": "RU-NGR", "Novosibirsk Oblast": "RU-NVS",
      "Omsk Oblast": "RU-OMS", "Orenburg Oblast": "RU-ORE", "Oryol oblast": "RU-ORL", "Penza Oblast": "RU-PNZ",
      "Perm Krai": "RU-PER", "Primorye": "RU-PRI", "Pskov Oblast": "RU-PSK", "Republic of Tyva": "RU-TY",
      "Rostov": "RU-ROS", "Ryazan Oblast": "RU-RYA", "Sakha": "RU-SA", "Sakhalin Oblast": "RU-SAK",
      "Samara Oblast": "RU-SAM", "Saratov Oblast": "RU-SAR", "Smolensk Oblast": "RU-SMO",
      "St.-Petersburg": "RU-SPE", "Stavropol Kray": "RU-STA", "Sverdlovsk Oblast": "RU-SVE",
      "Tambov Oblast": "RU-TAM", "Tatarstan Republic": "RU-TA", "Tomsk Oblast": "RU-TOM", "Tula Oblast": "RU-TUL",
      "Tver Oblast": "RU-TVE", "Tyumen Oblast": "RU-TYU", "Udmurtiya Republic": "RU-UD", "Ulyanovsk": "RU-ULY",
      "Vladimir Oblast": "RU-VLA", "Volgograd Oblast": "RU-VGG", "Vologda Oblast": "RU-VLG",
      "Voronezh Oblast": "RU-VOR", "Yamalo-Nenets": "RU-YAN", "Yaroslavl Oblast": "RU-YAR",
      "Zabaykalskiy (Transbaikal) Kray": "RU-ZAB"}
# episode: (pre window, post window, years for the co-invention exposure, output suffix)
EPISODES = {2022: (range(2019, 2022), range(2022, 2025), range(2012, 2022), ""),
            2014: (range(2011, 2014), range(2014, 2017), range(2006, 2014), "_2014")}


def main():
    reg = json.load(open(ROOT / "data" / "raw" / "rucities" / "russia-regions.json", encoding="utf-8"))
    regions = pd.DataFrame([{"iso": r["iso_3166-2"], "name_ru": r["name"], "name_en": r["name_en"],
                             "district": r["district"], "pop": r["population"]} for r in reg])
    assert regions.iso.is_unique and len(regions) == 83
    cw = pd.DataFrame({"openalex_region": list(OA), "iso": list(OA.values())})
    assert cw.iso.isin(regions.iso).all() and cw.iso.is_unique
    cw.to_csv(CLEAN / "region_crosswalk.csv", index=False)

    # patents
    p = pd.read_parquet(CLEAN / "rospatent_inventions.parquet")
    p = p[p.app_year.between(2006, 2025) & p.region.isin(regions.iso)].copy()
    p["app_year"] = p.app_year.astype(int)
    dom = p[p.domestic & ~p.mass_filer]
    g = dom.groupby(["region", "app_year"])
    pan = pd.DataFrame({"pat": g.size(),
                        "pat_noatt": g.attorney.agg(lambda s: (~s).sum()),
                        "pat_west_coinv": g.west_coinvent.sum()})
    for t in ("university", "research", "firm", "individual"):
        pan["pat_" + t] = dom[dom.holder_type == t].groupby(["region", "app_year"]).size()
    # Russian-holder patents with a coalition co-holder or co-inventor (not domestic by P2 when co-held)
    ruh = p[p.ru_holder & ~p.mass_filer]
    ruh = ruh.assign(west_link=ruh.west_coinvent | ruh.west_holder)
    gr = ruh.groupby(["region", "app_year"])
    pan["ruh_pat"] = gr.size()
    pan["ruh_west_link"] = gr.west_link.sum()
    pan = pan.fillna(0).astype(int).reset_index().rename(columns={"region": "iso", "app_year": "year"})
    full = pd.MultiIndex.from_product([regions.iso, range(2006, 2026)], names=["iso", "year"]).to_frame(index=False)
    pan = full.merge(pan, how="left").fillna(0)

    # publications
    oa = pd.read_csv(ROOT / "data" / "raw" / "openalex" / "regions" / "region_year.csv")
    oa["iso"] = oa.region.map(OA)
    assert oa.iso.notna().all()
    oa = oa.pivot_table(index=["iso", "year"], columns="partner", values="works", aggfunc="sum").add_prefix("pub_")
    pan = pan.merge(oa.reset_index(), on=["iso", "year"], how="left")
    pan = pan.merge(regions[["iso", "name_en", "district", "pop"]], on="iso")
    pan.to_csv(CLEAN / "region_year_panel.csv", index=False)

    print(pan.groupby("year")[["pat", "pat_firm", "pat_university", "pub_all_small", "ruh_west_link"]].sum())
    for ep, (PRE, POST, LINK, suf) in EPISODES.items():
        exposure(pan, regions, PRE, POST, LINK, suf, ep)


def exposure(pan, regions, PRE, POST, LINK, suf, ep):
    print(f"--- episode {ep}")
    def per(cols, yrs):
        return pan[pan.year.isin(yrs)].groupby("iso")[cols].sum()

    pre = per(["pat", "pat_noatt", "pat_firm", "pat_university", "pat_research", "pat_individual",
               "pub_all_small", "pub_coalition_small", "pub_china_small", "pub_all"], PRE)
    post = per(pre.columns.tolist(), POST)
    lnk = per(["ruh_pat", "ruh_west_link"], LINK)
    ex = regions.set_index("iso")[["name_en", "name_ru", "district", "pop"]].copy()
    ex["x_science"] = pre.pub_coalition_small / pre.pub_all_small
    ex["x_china_sci"] = pre.pub_china_small / pre.pub_all_small
    ex["x_invent"] = lnk.ruh_west_link / lnk.ruh_pat
    ex["n_ruh_pat_link"] = lnk.ruh_pat
    ex["n_west_link"] = lnk.ruh_west_link
    for c in pre.columns:
        ex[c + "_pre"] = pre[c]
        ex[c + "_post"] = post[c]
    ex["pat_pc_pre"] = ex.pat_pre / len(PRE) / ex["pop"] * 1e6
    ex["pat_pc_post"] = ex.pat_post / len(POST) / ex["pop"] * 1e6
    # change relative to Russia: log(post/pre) minus the national log change (positive = gained ground)
    for c in ("pat", "pat_noatt", "pat_firm", "pat_university", "pat_research", "pub_all_small"):
        nat = np.log(ex[c + "_post"].sum() / ex[c + "_pre"].sum())
        ok = (ex[c + "_pre"] >= 30) & (ex[c + "_post"] > 0)
        ex["dlog_" + c] = np.where(ok, np.log(ex[c + "_post"] / ex[c + "_pre"]) - nat, np.nan)
        ex["share_pre_" + c] = ex[c + "_pre"] / ex[c + "_pre"].sum()
        ex["share_post_" + c] = ex[c + "_post"] / ex[c + "_post"].sum()
    ex.reset_index().to_csv(CLEAN / f"region_exposure{suf}.csv", index=False)

    print(ex[["x_science", "x_invent", "dlog_pat", "dlog_pat_firm", "dlog_pub_all_small"]].describe().round(3))
    print(ex[["x_science", "x_invent", "dlog_pat", "dlog_pat_firm", "dlog_pub_all_small", "pat_pc_pre"]]
          .corr().round(2))


if __name__ == "__main__":
    main()
