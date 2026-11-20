"""Domestic invention patents by WIPO field (top predicted, note 08) x filing year x holder type (note 11).

Input : data/clean/rospatent_field_probs.parquet (14), rospatent_inventions.parquet (11; holder type, rule P4)
Output: data/clean/ru_domestic_field_year_holder.csv  field, year, holder_type, n
        holder_type: firm, university, research, individual, none (as P4); mass filers dropped (P6)
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
CLEAN = ROOT / "data" / "clean"


def main():
    p = pd.read_parquet(CLEAN / "rospatent_field_probs.parquet",
                        columns=["reg_no", "app_year", "domestic", "mass_filer", "field_top"])
    h = pd.read_parquet(CLEAN / "rospatent_inventions.parquet", columns=["reg_no", "holder_type"]).drop_duplicates("reg_no")
    d = p[p.domestic & ~p.mass_filer].merge(h, on="reg_no", how="left")
    d["holder_type"] = d.holder_type.fillna("none")
    g = d.groupby(["field_top", "app_year", "holder_type"]).size().rename("n").reset_index()
    g = g.rename(columns={"field_top": "field", "app_year": "year"})
    full = pd.MultiIndex.from_product([range(1, 36), sorted(g.year.unique()), sorted(g.holder_type.unique())],
                                      names=["field", "year", "holder_type"])
    g = g.set_index(["field", "year", "holder_type"]).reindex(full, fill_value=0).reset_index()
    g.to_csv(CLEAN / "ru_domestic_field_year_holder.csv", index=False)
    print(g[g.year.between(2019, 2025)].pivot_table(index="year", columns="holder_type", values="n", aggfunc="sum"))


if __name__ == "__main__":
    main()
