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
      Rscript scripts/analysis/16e_patents_sector_fe.R 2>&1 | tee data/logs/16e_patents_sector_fe_R.log
      Rscript scripts/analysis/16f_patents_holder_region.R 2>&1 | tee data/logs/16f_patents_holder_region_R.log
      # session 5: IPC subclass design (classifier ~30 min)
      uv run python -I -W ignore scripts/data/14b_title_subclass_classifier.py 2>&1 | tee data/logs/14b_subclass_classifier.log
      uv run python -I -c "import pandas as pd; p=pd.read_parquet('data/clean/rospatent_subclass_top.parquet'); p=p[p.domestic & ~p.mass_filer & p.app_year.between(2015,2025)]; p.groupby(['sub_top','app_year','holder_type']).size().rename('n').reset_index().rename(columns={'sub_top':'subclass','app_year':'year','holder_type':'h'}).to_csv('data/clean/ru_domestic_subclass_holder_year.csv', index=False)"
      uv run python -I -W ignore scripts/data/19b_subclass_ban_coverage.py 2>&1 | tee data/logs/19b_subclass_ban_coverage.log
      Rscript scripts/analysis/17_patents_subclass.R 2>&1 | tee data/logs/17_patents_subclass_R.log
      # official IPC from the Rospatent API (needs ROSPATENT_TOKEN; slow, resumable) and RFSD
      zsh -ic 'uv run python -I scripts/data/21b_get_rospatent_api.py' 2>&1 | tee -a data/logs/21b_rospatent_api.log
      uv run python -I scripts/data/22_parse_rospatent_api.py 2>&1 | tee data/logs/22_parse_api.log
      uv run python -I scripts/data/23_build_official_ipc_panels.py 2>&1 | tee data/logs/23_official_panels.log
      Rscript scripts/analysis/18_patents_official.R 2>&1 | tee data/logs/18_patents_official_R.log
      Rscript scripts/analysis/18b_official_raw_series.R 2>&1 | tee data/logs/18b_official_raw_R.log
      Rscript scripts/analysis/18c_subclass_twfe.R 2>&1 | tee data/logs/18c_subclass_twfe_R.log
      Rscript scripts/analysis/18d_pitch_figures.R 2>&1 | tee data/logs/18d_pitch_figures_R.log
      Rscript scripts/analysis/18e_pretrend_tests.R 2>&1 | tee data/logs/18e_pretrend_tests_R.log
      Rscript scripts/analysis/18f_raw_lines.R 2>&1 | tee data/logs/18f_raw_lines_R.log
      Rscript scripts/analysis/18g_leave_one_out.R 2>&1 | tee data/logs/18g_leave_one_out_R.log
      Rscript scripts/analysis/18h_summary_figure.R 2>&1 | tee data/logs/18h_summary_figure_R.log
      Rscript scripts/analysis/18i_oriv.R 2>&1 | tee data/logs/18i_oriv_R.log
      uv run python -I scripts/data/25_build_tech_proximity.py 2>&1 | tee data/logs/25_tech_proximity.log
      Rscript scripts/analysis/18j_spillovers.R 2>&1 | tee data/logs/18j_spillovers_R.log
      Rscript scripts/analysis/18k_oriv_spillovers.R 2>&1 | tee data/logs/18k_oriv_spillovers_R.log
      Rscript scripts/analysis/18l_honestdid.R 2>&1 | tee data/logs/18l_honestdid_R.log
      uv run python -I scripts/data/26_field_prewar_characteristics.py 2>&1 | tee data/logs/26_prewar_chars.log
      Rscript scripts/analysis/18m_prewar_controls.R 2>&1 | tee data/logs/18m_prewar_controls_R.log
      Rscript scripts/analysis/18n_bootstrap_es.R 2>&1 | tee data/logs/18n_bootstrap_es_R.log
      Rscript scripts/analysis/18o_2014_official.R 2>&1 | tee data/logs/18o_2014_official_R.log
      uv run python -I scripts/data/27_dualuse_2014_coverage.py 2>&1 | tee data/logs/27_dualuse_2014.log
      Rscript scripts/analysis/18p_dualuse_2014.R 2>&1 | tee data/logs/18p_dualuse_2014_R.log
      uv run python -I scripts/data/28_industry_panel.py 2>&1 | tee data/logs/28_industry_panel.log
      Rscript scripts/analysis/18q_industry_design.R 2>&1 | tee data/logs/18q_industry_design_R.log
      uv run python -I scripts/data/29a_bea_naics_parse.py 2>&1 | tee data/logs/29a_bea.log
      Rscript scripts/data/29b_naics_isic_concord.R 2>&1 | tee data/logs/29b_naics_isic.log
      uv run python -I scripts/data/29c_input_exposure.py 2>&1 | tee data/logs/29c_input_exposure.log
      Rscript scripts/analysis/18r_input_exposure.R 2>&1 | tee data/logs/18r_input_exposure_R.log
      uv run python -I scripts/data/30_rosstat_input_exposure.py 2>&1 | tee data/logs/30_rosstat_input.log
      Rscript scripts/analysis/18s_rosstat_input_exposure.R 2>&1 | tee data/logs/18s_rosstat_input_R.log
      # filings (published applications + fast grants) by origin (needs ROSPATENT_TOKEN; ~1.5 h, resumable)
      zsh -ic 'uv run python -I scripts/data/21c_get_rospatent_api_apps.py' 2>&1 | tee -a data/logs/21c_rospatent_api_apps.log
      uv run python -I scripts/data/22b_parse_rospatent_api_apps.py 2>&1 | tee data/logs/22b_parse_api_apps.log
      uv run python -I scripts/data/23b_build_filings_panel.py 2>&1 | tee data/logs/23b_filings_panel.log
      Rscript scripts/analysis/18t_filings_by_origin.R 2>&1 | tee data/logs/18t_filings_origin_R.log
      uv run python -I scripts/data/24_get_rfsd.py 2>&1 | tee data/logs/24_get_rfsd.log
    fi
  fi
fi
