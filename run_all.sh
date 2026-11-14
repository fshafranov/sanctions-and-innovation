#!/usr/bin/env bash
# Rebuild everything: downloads (WB, OpenAlex), GSDB cleaning, panel, estimates, figures.
# WIPO patent indicators zip (data/raw/wipo/) was downloaded by hand from wipo.int (Indicators by technology).
# GSDB V4 raw files are not downloadable by script (request form); they must be in data/raw/gsdb/.
# Design D: 08_get_bigquery_ru.py needs the user's Google login, so it is not run here; run it by hand with
#   GCP_PROJECT=sanctions-innovation uv run python scripts/data/08_get_bigquery_ru.py
# The steps that use its output run only if data/raw/bigquery/ru_publications.parquet exists.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p data/logs
uv run python scripts/data/01_get_wb.py        | tee data/logs/01_get_wb.log
uv run python scripts/data/02_get_openalex.py  | tee data/logs/02_get_openalex.log
uv run python scripts/data/05_get_pwt_tfp.py    | tee data/logs/05_get_pwt_tfp.log
uv run python scripts/data/03_clean_gsdb.py    | tee data/logs/03_clean_gsdb.log
uv run python scripts/data/04_build_panel.py   | tee data/logs/04_build_panel.log
uv run python scripts/data/06_get_oecd_fields.py | tee data/logs/06_get_oecd_fields.log
uv run python scripts/data/07_build_field_panel.py | tee data/logs/07_build_field_panel.log
Rscript scripts/analysis/01_descriptives.R     2>&1 | tee data/logs/01_descriptives.log
Rscript scripts/analysis/02_cross_country_lp.R 2>&1 | tee data/logs/02_cross_country_lp.log
Rscript scripts/analysis/03_leave_one_out.R    2>&1 | tee data/logs/03_leave_one_out.log
Rscript scripts/analysis/04_figures.R          2>&1 | tee data/logs/04_figures.log
Rscript scripts/analysis/05_diagnostics.R      2>&1 | tee data/logs/05_diagnostics.log
Rscript scripts/analysis/07_field_triple_diff.R 2>&1 | tee data/logs/07_field_triple_diff.log
Rscript scripts/analysis/11_staggered_did.R    2>&1 | tee data/logs/11_staggered_did_R.log   # main cross-country (needs R package did)
Rscript scripts/analysis/12_synthetic_did.R   2>&1 | tee data/logs/12_synthetic_did_R.log   # single cases (needs quadprog)
uv run python -I scripts/data/13_get_wb_covariates.py | tee data/logs/13_wb_covariates.log   # needs data/raw/wb/wdi_bulk/WDI_CSV.zip
Rscript scripts/analysis/12d_sdid_covariates.R 2>&1 | tee data/logs/12d_sdid_covariates_R.log
# optional cross-check, separate env (see header of 12c): $SDID_ENV/bin/python -I scripts/analysis/12c_synthdid_python.py
uv run python scripts/data/09_get_openalex_regions.py 2>&1 | tee data/logs/09_openalex_regions.log
Rscript scripts/analysis/09_regions_openalex.R 2>&1 | tee data/logs/09_regions_openalex_R.log
if [ -f data/raw/bigquery/ru_publications.parquet ]; then
  uv run python scripts/data/10_build_ru_patent_fields.py | tee data/logs/10_build_ru_patent_fields.log
  Rscript scripts/analysis/08_ru_patents_types.R 2>&1 | tee data/logs/08_ru_patents_types_R.log
fi
if [ -f data/raw/rospatent/data-20261102-structure-20180828.csv ]; then   # user's download, rospatent.gov.ru/opendata
  uv run python -I scripts/data/11_parse_rospatent_register.py | tee data/logs/11_parse_rospatent.log
  uv run python -I scripts/data/12_build_region_panel.py | tee data/logs/12_region_panel.log
  Rscript scripts/analysis/10_region_maps.R 2>&1 | tee data/logs/10_region_maps_R.log
  if [ -f data/raw/bigquery/ru_publications.parquet ]; then   # fields from titles (~10 min, local)
    uv run python -I scripts/data/14_title_field_classifier.py 2>&1 | grep -v -i warning | tee data/logs/14_title_classifier.log
    Rscript scripts/analysis/13_title_classifier_check.R 2>&1 | tee data/logs/13_title_classifier_check_R.log
    # import exposure by field: BACI (manual-size download, see note 09), TN VED names, IAB concordance, R `concordance` 2.1.0
    if [ -f data/raw/baci/BACI_HS07_V202601.zip ]; then
      uv run python -I scripts/data/15_build_ru_imports.py | tee data/logs/15_ru_imports.log
      Rscript scripts/data/16a_export_concordances.R
      uv run python -I scripts/data/16_hs_field_maps.py 2>&1 | grep -v -i warning | tee data/logs/16_hs_field_maps.log
      uv run python -I -W ignore scripts/data/17_build_field_exposure.py | tee data/logs/17_field_exposure.log
      Rscript scripts/analysis/14_import_exposure_first_stage.R 2>&1 | tee data/logs/14_import_first_stage_R.log
      # EU ban lists: 35 consolidated versions of Reg. 833/2014 from the CELLAR API (see header of 18)
      uv run python -I -W ignore scripts/data/18_parse_eu_bans.py | tee data/logs/18_parse_eu_bans.log
      uv run python -I -W ignore scripts/data/19_build_ban_coverage.py | tee data/logs/19_ban_coverage.log
      Rscript scripts/analysis/15_ban_first_stage.R 2>&1 | tee data/logs/15_ban_first_stage_R.log
      # main test (pre-registered in notes/11) and exploratory trend checks
      uv run python -I -W ignore scripts/data/20_build_field_holder_panel.py | tee data/logs/20_field_holder_panel.log
      Rscript scripts/analysis/16_patents_ban_test.R 2>&1 | tee data/logs/16_patents_ban_test_R.log
      Rscript scripts/analysis/16b_patents_ban_trends.R 2>&1 | tee data/logs/16b_patents_ban_trends_R.log
      Rscript scripts/analysis/16c_patents_2014.R 2>&1 | tee data/logs/16c_patents_2014_R.log
      Rscript scripts/analysis/16d_patents_staggered.R 2>&1 | tee data/logs/16d_patents_staggered_R.log
    fi
  fi
fi
