"""Impute WIPO technology fields for Rospatent inventions from their Russian titles (fills the post-2018 IPC gap).

Why: the Rospatent register (11_parse_rospatent_register.py) has titles for ~99% of patents through 2026 but no IPC.
IPC comes from Google Patents (BigQuery, 08_get_bigquery_ru.py), matched on registration number: 96-99% of patents
filed 2008-2017, 89% (2018), 70% (2020), 39% (2021), ~0% (2022+). See notes/08_title_classifier.md.

Input
  data/raw/rospatent/data-20261102-structure-20180828.csv   titles ("invention name"), registration numbers
  data/clean/rospatent_inventions.parquet                   domestic flag, region, mass filers (script 11)
  data/raw/bigquery/ru_publications.parquet                 IPC codes of granted RU inventions (kind C*)
  data/raw/wipo/ipc_technology.xlsx                          IPC -> 35 WIPO fields (same rule as script 10, D1)

Model (T1-T4 in notes/data_decisions.md)
  T1 labels: every IPC code -> WIPO field; a patent with k distinct fields enters training k times, weight 1/k.
  T2 features: TF-IDF of the lower-cased title, word unigrams+bigrams and character 3-5-grams within words
     (catches Russian inflection), sublinear tf, min_df 3.
  T3 classifier: multinomial logistic regression (SGD, log loss, L2 penalty), outputs a probability per field.
  T4 validation: (a) random 10% of 2005-2017 patents held out; (b) out-of-time: model trained on filings
     <= 2017 predicts the 2018-2021 patents that do have IPC. Hit = predicted field among the true fields.
     Field shares by year: sum of predicted probabilities vs true fractional counts.
  T5 cross-fitting: labelled patents filed 2000-2021 get out-of-fold predictions (5 folds); unlabelled patents
     (mostly 2021+) get the model trained on all labelled patents filed 2000-2021.

Output
  data/clean/rospatent_field_probs.parquet  reg_no, app_year, domestic, region, mass_filer, labelled, true fields,
                                            p_1..p_35 (predicted probabilities)
  data/clean/ru_domestic_field_year_imputed.csv  field x filing year, domestic non-mass-filer inventions:
            n_top (MAIN: each patent counted once in its top predicted field, T6),
            n_prob (sum of predicted probabilities; attenuates changes, check only),
            n_obs (IPC-based, where matched), n_hybrid (IPC where matched, predicted otherwise)
  data/clean/ru_domestic_region_field_year_imputed.csv  region x field x filing year, n_top and n_hybrid
  data/logs/14_title_classifier_validation.csv  accuracy table
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

ROOT = Path(__file__).resolve().parents[3]
RAW, CLEAN, LOGS = ROOT / "data" / "raw", ROOT / "data" / "clean", ROOT / "data" / "logs"
REG_CSV = RAW / "rospatent" / "data-20261102-structure-20180828.csv"
SEED = 20261112

spec = importlib.util.spec_from_file_location("s10", ROOT / "data" / "scripts" / "processing" / "process_ru_patents_google.py")
s10 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s10)


def load():
    t = pd.read_csv(REG_CSV, usecols=["registration number", "invention name"], dtype=str)
    t.columns = ["reg_no", "title"]
    t["title"] = (t.title.fillna("").str.replace(r"\s+", " ", regex=True).str.strip().str.lower()
                  .str.replace("ё", "е"))
    r = pd.read_parquet(CLEAN / "rospatent_inventions.parquet",
                        columns=["reg_no", "app_year", "domestic", "region", "mass_filer"])
    r = r.merge(t.drop_duplicates("reg_no"), on="reg_no", how="left")
    r = r[(r.app_year >= 2000) & (r.title.str.len() > 3)].copy()
    r["app_year"] = r.app_year.astype(int)

    by_group, by_sub, names = s10.concordance()

    def fields(codes):
        out = set()
        for c in codes if codes is not None else []:
            m = re.match(r"([A-H]\d\d[A-Z])(\d+)/", c)
            if m:
                f = by_group.get((m.group(1), m.group(2))) or by_sub.get(m.group(1))
                if f:
                    out.add(f)
        return sorted(out)

    b = pd.read_parquet(RAW / "bigquery" / "ru_publications.parquet", columns=["publication_number", "ipc"])
    b = b[b.publication_number.str.match(r"RU-\d+-C")].copy()
    b["reg_no"] = b.publication_number.str.split("-").str[1]
    b["fields"] = b.ipc.apply(fields)
    b = b[b.fields.str.len() > 0].drop_duplicates("reg_no")
    r = r.merge(b[["reg_no", "fields"]], on="reg_no", how="left")
    r["labelled"] = r.fields.notna()
    return r, names


def expand(d):
    """One row per (patent, true field), weight 1/k."""
    x = d[["title", "fields"]].explode("fields")
    w = 1 / d.fields.str.len()
    return x.title.values, x.fields.astype(int).values, w.reindex(x.index).values


class Model:
    def fit(self, titles, y, w):
        self.vw = TfidfVectorizer(ngram_range=(1, 2), min_df=3, sublinear_tf=True, max_features=300_000)
        self.vc = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), min_df=3, sublinear_tf=True,
                                  max_features=400_000)
        X = hstack([self.vw.fit_transform(titles), self.vc.fit_transform(titles)]).tocsr()
        self.clf = SGDClassifier(loss="log_loss", alpha=2e-6, max_iter=30, tol=1e-4, random_state=SEED,
                                 n_jobs=-1)
        self.clf.fit(X, y, sample_weight=w)
        return self

    def proba(self, titles):
        X = hstack([self.vw.transform(titles), self.vc.transform(titles)]).tocsr()
        return self.clf.predict_proba(X)


def evaluate(m, d, label, names):
    p = m.proba(d.title.values)
    cls = m.clf.classes_
    top = np.argsort(-p, axis=1)[:, :3]
    true = d.fields.tolist()
    hit1 = np.mean([cls[top[i, 0]] in true[i] for i in range(len(d))])
    hit3 = np.mean([any(cls[j] in true[i] for j in top[i]) for i in range(len(d))])
    out = [{"sample": label, "metric": "top1_hit", "value": hit1, "n": len(d)},
           {"sample": label, "metric": "top3_hit", "value": hit3, "n": len(d)}]
    # field shares by year: predicted vs true (fractional)
    pr = pd.DataFrame(p, columns=cls, index=d.index).assign(year=d.app_year).groupby("year").sum()
    tr = d[["app_year", "fields"]].explode("fields")
    tr["w"] = 1 / d.fields.str.len().reindex(tr.index)
    tr = tr.pivot_table(index="app_year", columns="fields", values="w", aggfunc="sum").reindex(
        columns=cls, fill_value=0).fillna(0)
    for y in pr.index:
        a, b = pr.loc[y] / pr.loc[y].sum(), tr.loc[y] / tr.loc[y].sum()
        out.append({"sample": label, "metric": f"share_corr_{y}", "value": np.corrcoef(a, b)[0, 1], "n": int(
            (d.app_year == y).sum())})
        out.append({"sample": label, "metric": f"share_mae_pp_{y}", "value": 100 * np.abs(a - b).mean(),
                    "n": int((d.app_year == y).sum())})
    print(f"  {label}: top-1 {hit1:.3f}, top-3 {hit3:.3f}, n={len(d)}")
    return out, p


def main():
    t0 = time.time()
    r, names = load()
    print(f"patents filed 2000+ with title: {len(r)}; with IPC field: {r.labelled.sum()}")
    print(r.groupby("app_year").labelled.mean().round(3).loc[2008:].to_dict())

    lab = r[r.labelled]
    rng = np.random.default_rng(SEED)
    core = lab[lab.app_year.between(2005, 2017)]
    hold = core.sample(frac=0.1, random_state=SEED)
    train = lab[(lab.app_year <= 2017) & ~lab.index.isin(hold.index)]
    print(f"[{time.time()-t0:.0f}s] validation model: training on {len(train)} patents (filed <= 2017)")
    m = Model().fit(*expand(train))
    rows = []
    o, _ = evaluate(m, hold, "holdout_2005_2017", names)
    rows += o
    oot = lab[lab.app_year.between(2018, 2021)]
    o, _ = evaluate(m, oot, "out_of_time_2018_2021", names)
    rows += o
    # per-field recall out of time (is any field systematically missed?)
    p = m.proba(oot.title.values)
    pred = m.clf.classes_[p.argmax(1)]
    rec = (pd.DataFrame({"pred": pred, "fields": oot.fields.values}).explode("fields")
           .assign(hit=lambda x: x.pred == x.fields).groupby("fields").hit.mean())
    for f, v in rec.items():
        rows.append({"sample": "out_of_time_2018_2021", "metric": f"recall_field_{int(f)}", "value": v,
                     "n": int((oot.fields.apply(lambda s: f in s)).sum())})
    val = pd.DataFrame(rows)
    LOGS.mkdir(exist_ok=True)
    val.to_csv(LOGS / "14_title_classifier_validation.csv", index=False)
    print(val[val.metric.str.startswith(("share_corr", "share_mae"))].pivot_table(
        index="metric", columns="sample", values="value").round(3))

    # T5 cross-fitting: labelled patents filed 2000-2021 get out-of-fold predictions (5 folds), so predicted
    # series in the labelled years are not in-sample; unlabelled patents get the model trained on all labelled.
    lab21 = lab[lab.app_year <= 2021]
    fold = pd.Series(rng.integers(0, 5, len(lab21)), index=lab21.index)
    P = np.zeros((len(r), 35), dtype="float32")
    pos = pd.Series(np.arange(len(r)), index=r.index)
    for k in range(5):
        print(f"[{time.time()-t0:.0f}s] cross-fit fold {k + 1}/5")
        m = Model().fit(*expand(lab21[fold != k]))
        te = lab21[fold == k]
        P[pos[te.index].values] = m.proba(te.title.values)
    print(f"[{time.time()-t0:.0f}s] final model: training on {len(lab21)} patents (2000-2021)")
    m = Model().fit(*expand(lab21))
    joblib.dump(m, CLEAN / "title_field_model.joblib")  # reused for product names (16_hs_field_maps.py)
    rest = r[~r.index.isin(lab21.index)]
    P[pos[rest.index].values] = m.proba(rest.title.values)
    cls = [int(c) for c in m.clf.classes_]
    assert cls == list(range(1, 36))
    pc = [f"p_{c}" for c in cls]
    out = pd.concat([r.reset_index(drop=True), pd.DataFrame(P, columns=pc)], axis=1)
    out["fields"] = out.fields.apply(lambda s: list(s) if isinstance(s, list) else [])
    out["field_top"] = np.array(cls)[P.argmax(1)]
    out.to_parquet(CLEAN / "rospatent_field_probs.parquet", index=False)

    # panels: domestic, not mass filers
    d = out[out.domestic & ~out.mass_filer].copy()
    # T6 main count = top predicted field (whole count). Summing raw probabilities shrinks within-field changes
    # toward the average field (slope ~0.6 against IPC-based counts), which would bias event studies to zero.
    top = d[["region", "app_year", "field_top"]].rename(columns={"field_top": "field"}).assign(w=1.0)
    pred_long = d[["region", "app_year"] + pc].melt(id_vars=["region", "app_year"], var_name="f", value_name="w")
    pred_long["field"] = pred_long.f.str[2:].astype(int)
    obs = d[d.fields.str.len() > 0][["region", "app_year", "fields"]].explode("fields")
    obs["w"] = 1 / d.fields.str.len().reindex(obs.index)
    obs = obs.rename(columns={"fields": "field"})
    obs["field"] = obs.field.astype(int)
    unl = d[d.fields.str.len() == 0][["region", "app_year"] + pc].melt(id_vars=["region", "app_year"],
                                                                         var_name="f", value_name="w")
    unl["field"] = unl.f.str[2:].astype(int)
    hyb = pd.concat([obs[["region", "app_year", "field", "w"]], unl[["region", "app_year", "field", "w"]]])

    def agg(x, keys, name):
        return x.groupby(keys).w.sum().rename(name)

    k = ["field", "app_year"]
    fy = pd.concat([agg(top, k, "n_top"), agg(pred_long, k, "n_prob"), agg(obs, k, "n_obs"),
                    agg(hyb, k, "n_hybrid")], axis=1)
    full = pd.MultiIndex.from_product([cls, sorted(d.app_year.unique())], names=k)
    fy = fy.reindex(full).fillna(0).reset_index().rename(columns={"app_year": "year"})
    fy["field_en"] = fy.field.map(names)
    fy.to_csv(CLEAN / "ru_domestic_field_year_imputed.csv", index=False)

    k = ["region", "field", "app_year"]
    rfy = pd.concat([agg(top.dropna(subset=["region"]), k, "n_top"),
                     agg(hyb.dropna(subset=["region"]), k, "n_hybrid")], axis=1).fillna(0)
    rfy.reset_index().rename(columns={"app_year": "year"}).to_csv(
        CLEAN / "ru_domestic_region_field_year_imputed.csv", index=False)

    # T6 check: within-field changes, predicted vs IPC-based, after field and year FE, 2010-2020 (out-of-fold)
    g = fy[fy.year.between(2010, 2020)].copy()
    for c in ["n_top", "n_prob", "n_obs"]:
        g[c] = np.log(g[c])
        g[c] -= g.groupby("field")[c].transform("mean")
        g[c] -= g.groupby("year")[c].transform("mean")
    for c in ["n_top", "n_prob"]:
        print(f"T6 {c} vs IPC-based, field+year FE, 2010-20: corr {np.corrcoef(g[c], g.n_obs)[0, 1]:.3f}, "
              f"slope {np.polyfit(g.n_obs, g[c], 1)[0]:.3f}")

    tot = fy.groupby("year")[["n_top", "n_prob", "n_obs", "n_hybrid"]].sum().round(0)
    print(tot.loc[2010:])
    print(f"[{time.time()-t0:.0f}s] done")


if __name__ == "__main__":
    main()
