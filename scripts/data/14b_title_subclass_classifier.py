"""Impute IPC subclasses (4 characters, e.g. H04W) for Rospatent inventions from their Russian titles (session 5).

Same method as 14_title_field_classifier.py (TF-IDF + multinomial logit via SGD), one level finer: about 460 IPC
subclasses instead of 35 WIPO fields. Gives ~13x more technology units for the ban-coverage design (note 13).

Input : as script 14 (register titles, rospatent_inventions.parquet, BigQuery IPC codes)
Rules (SC1-SC4 in notes/data_decisions.md)
  SC1 labels: distinct IPC subclasses of a granted patent (kind C*), weight 1/k; classes = subclasses with >= 200
     labelled patents filed 2000-2021 (rarer subclasses are dropped from training; their patents still get a
     predicted class among the kept ones).
  SC2 validation: model trained on filings <= 2017 predicts 2018-2021 patents with IPC (out of time): top-1/top-5
     hit; within-subclass changes after subclass and year FE, 2010-2020 (predicted vs IPC counts).
  SC3 cross-fitting: 3 folds for labelled patents filed 2000-2021; final model on all of them for the rest.
  SC4 count = top predicted subclass (whole count), domestic non-mass-filer inventions, by filing year.
Output: data/clean/ru_domestic_subclass_year.csv   subclass, year, n_top, n_obs (IPC-based where matched)
        data/clean/ru_domestic_region_subclass_year.csv  region, subclass, year, n_top
        data/clean/rospatent_subclass_top.parquet  reg_no, app_year, domestic, mass_filer, holder_type, sub_top,
                                                    p_top, subs (true subclasses)
        data/clean/title_subclass_model.joblib     final model (used for product names in 16b_hs_subclass_maps.py)
        data/logs/14b_subclass_validation.csv
"""
import importlib.util
import re
import time
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from scipy.sparse import hstack
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import SGDClassifier

ROOT = Path(__file__).resolve().parents[2]
RAW, CLEAN, LOGS = ROOT / "data" / "raw", ROOT / "data" / "clean", ROOT / "data" / "logs"
REG_CSV = RAW / "rospatent" / "data-20261102-structure-20180828.csv"
SEED = 20261118
MIN_LABELLED = 200


def load():
    t = pd.read_csv(REG_CSV, usecols=["registration number", "invention name"], dtype=str)
    t.columns = ["reg_no", "title"]
    t["title"] = (t.title.fillna("").str.replace(r"\s+", " ", regex=True).str.strip().str.lower()
                  .str.replace("ё", "е"))
    r = pd.read_parquet(CLEAN / "rospatent_inventions.parquet",
                        columns=["reg_no", "app_year", "domestic", "region", "mass_filer", "holder_type"])
    r = r.merge(t.drop_duplicates("reg_no"), on="reg_no", how="left")
    r = r[(r.app_year >= 2000) & (r.title.str.len() > 3)].copy()
    r["app_year"] = r.app_year.astype(int)
    b = pd.read_parquet(RAW / "bigquery" / "ru_publications.parquet", columns=["publication_number", "ipc"])
    b = b[b.publication_number.str.match(r"RU-\d+-C")].copy()
    b["reg_no"] = b.publication_number.str.split("-").str[1]
    b["subs"] = b.ipc.apply(lambda cs: sorted({m.group(1) for c in (cs if cs is not None else [])
                                               for m in [re.match(r"([A-H]\d\d[A-Z])", c)] if m}))
    b = b[b.subs.str.len() > 0].drop_duplicates("reg_no")
    r = r.merge(b[["reg_no", "subs"]], on="reg_no", how="left")
    r["labelled"] = r.subs.notna()
    return r


def expand(d, keep):
    x = d[["title", "subs"]].explode("subs")
    x = x[x.subs.isin(keep)]
    k = x.groupby(level=0).size()
    return x.title.values, x.subs.values, (1 / k).reindex(x.index).values


class Model:
    def fit(self, titles, y, w):
        self.vw = TfidfVectorizer(ngram_range=(1, 2), min_df=3, sublinear_tf=True, max_features=150_000)
        self.vc = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), min_df=3, sublinear_tf=True,
                                  max_features=200_000, dtype=np.float32)
        X = hstack([self.vw.fit_transform(titles), self.vc.fit_transform(titles)]).tocsr().astype(np.float32)
        self.clf = SGDClassifier(loss="log_loss", alpha=2e-6, max_iter=20, tol=1e-4, random_state=SEED, n_jobs=-1)
        self.clf.fit(X, y, sample_weight=w)
        return self

    def proba(self, titles, chunk=50_000):
        out = []
        for i in range(0, len(titles), chunk):
            X = hstack([self.vw.transform(titles[i:i + chunk]), self.vc.transform(titles[i:i + chunk])]).tocsr()
            out.append(self.clf.predict_proba(X).astype(np.float32))
        return np.vstack(out)


def top_k(m, titles, k=5):
    p = m.proba(titles)
    idx = np.argsort(-p, axis=1)[:, :k]
    return m.clf.classes_[idx], np.take_along_axis(p, idx[:, :1], 1)[:, 0]


def main():
    t0 = time.time()
    r = load()
    lab = r[r.labelled & (r.app_year <= 2021)]
    cnt = lab.subs.explode().value_counts()
    keep = set(cnt[cnt >= MIN_LABELLED].index)
    print(f"patents 2000+: {len(r)}; labelled <= 2021: {len(lab)}; subclasses {len(cnt)}, kept {len(keep)} "
          f"(>= {MIN_LABELLED}); labelled patents with a kept subclass: "
          f"{lab.subs.apply(lambda s: any(x in keep for x in s)).mean():.3f}")

    # S2 out-of-time validation
    tr, te = lab[lab.app_year <= 2017], r[r.labelled & r.app_year.between(2018, 2021)]
    print(f"[{time.time()-t0:.0f}s] validation model on {len(tr)} patents")
    m = Model().fit(*expand(tr, keep))
    pred, _ = top_k(m, te.title.values)
    true = te.subs.tolist()
    hit1 = np.mean([pred[i, 0] in true[i] for i in range(len(te))])
    hit5 = np.mean([any(p in true[i] for p in pred[i]) for i in range(len(te))])
    print(f"  out of time 2018-21: top-1 {hit1:.3f}, top-5 {hit5:.3f}, n={len(te)}")
    val = [{"metric": "oot_top1", "value": hit1, "n": len(te)}, {"metric": "oot_top5", "value": hit5, "n": len(te)}]

    # S3 cross-fitting
    fold = pd.Series(np.random.default_rng(SEED).integers(0, 3, len(lab)), index=lab.index)
    sub_top = pd.Series(index=r.index, dtype=object)
    p_top = pd.Series(index=r.index, dtype="float32")
    for k in range(3):
        print(f"[{time.time()-t0:.0f}s] cross-fit fold {k + 1}/3")
        m = Model().fit(*expand(lab[fold != k], keep))
        tt = lab[fold == k]
        c, p = top_k(m, tt.title.values, 1)
        sub_top[tt.index], p_top[tt.index] = c[:, 0], p
    print(f"[{time.time()-t0:.0f}s] final model on {len(lab)} patents")
    m = Model().fit(*expand(lab, keep))
    joblib.dump(m, CLEAN / "title_subclass_model.joblib")
    rest = r[~r.index.isin(lab.index)]
    c, p = top_k(m, rest.title.values, 1)
    sub_top[rest.index], p_top[rest.index] = c[:, 0], p
    r["sub_top"], r["p_top"] = sub_top, p_top
    r[["reg_no", "app_year", "domestic", "mass_filer", "holder_type", "region", "sub_top", "p_top", "subs"]].assign(
        subs=lambda x: x.subs.apply(lambda s: list(s) if isinstance(s, list) else [])).to_parquet(
        CLEAN / "rospatent_subclass_top.parquet", index=False)

    d = r[r.domestic & ~r.mass_filer]
    top = d.groupby(["sub_top", "app_year"]).size().rename("n_top")
    obs = d[d.labelled][["app_year", "subs"]].explode("subs")
    obs["w"] = (1 / d.subs.str.len()).reindex(obs.index)
    obs = obs.groupby(["subs", "app_year"]).w.sum().rename("n_obs")
    obs.index.names = ["sub_top", "app_year"]
    full = pd.MultiIndex.from_product([sorted(keep), sorted(d.app_year.unique())], names=["sub_top", "app_year"])
    sy = pd.concat([top, obs], axis=1).reindex(full).fillna(0).reset_index()
    sy.columns = ["subclass", "year", "n_top", "n_obs"]
    sy.to_csv(CLEAN / "ru_domestic_subclass_year.csv", index=False)
    (d.dropna(subset=["region"]).groupby(["region", "sub_top", "app_year"]).size().rename("n_top").reset_index()
     .rename(columns={"sub_top": "subclass", "app_year": "year"})
     .to_csv(CLEAN / "ru_domestic_region_subclass_year.csv", index=False))

    # S2 within-subclass changes, out-of-fold predicted vs IPC, 2010-2020, subclasses with >= 20 per year on avg
    g = sy[sy.year.between(2010, 2020)].copy()
    big = g.groupby("subclass").n_obs.mean() >= 20
    g = g[g.subclass.map(big)]
    for col in ["n_top", "n_obs"]:
        g[col] = np.log(g[col].clip(lower=0.5))
        g[col] -= g.groupby("subclass")[col].transform("mean")
        g[col] -= g.groupby("year")[col].transform("mean")
    corr, slope = np.corrcoef(g.n_top, g.n_obs)[0, 1], np.polyfit(g.n_obs, g.n_top, 1)[0]
    print(f"within-subclass changes 2010-20 ({g.subclass.nunique()} subclasses): corr {corr:.3f}, slope {slope:.3f}")
    val += [{"metric": "within_corr", "value": corr, "n": g.subclass.nunique()},
            {"metric": "within_slope", "value": slope, "n": g.subclass.nunique()}]
    pd.DataFrame(val).to_csv(LOGS / "14b_subclass_validation.csv", index=False)
    print(sy.groupby("year")[["n_top", "n_obs"]].sum().loc[2010:].round(0))
    print(f"[{time.time()-t0:.0f}s] done")


if __name__ == "__main__":
    main()
