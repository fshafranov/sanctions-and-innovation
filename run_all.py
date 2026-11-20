"""
run_all.py
Stage:      master script (G3): rebuild every output from data/raw/ with one command.
Usage:      uv run python run_all.py                     # cleaning -> processing -> empirics
            uv run python run_all.py --with-collection   # also re-acquire raw data first
            uv run python run_all.py --stage empirics    # one stage only
            uv run python run_all.py --only clean_cbp    # one step only (name or substring)
            uv run python run_all.py --list              # show steps and dependencies, run nothing
            uv run python run_all.py --check             # afterwards, compare outputs with archive/baseline
            uv run python run_all.py --set-baseline      # afterwards, freeze outputs as the new baseline
Writes:     data/logs/run_all.log, data/logs/session_info.log, one log per step (data/logs/{stem}.log,
            empirics/results/logs/{stem}.log), one appended row in
            attempts-log.csv (the only append-only file: it is a register, not an output),
            plus everything the steps write.

Each step runs in a fresh process with the project root as working directory and stops the
run on failure. Python steps use this interpreter (the uv .venv), R steps Rscript (renv
activates via .Rprofile), Stata steps batch mode. Every script must appear in STEPS, in run
order; `needs` lists steps whose outputs it reads, and is checked before running.
"""
import argparse
import csv
import logging
import os
import platform
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RSCRIPT = os.environ.get("RSCRIPT", "Rscript")
CHECK_SCRIPT = "data/scripts/checks/check_baseline.py"

# (stage, script path, [names of steps it needs]); name = file stem.
# Collection needs network access and credentials (env ROSPATENT_TOKEN for the Rospatent API, GCP_PROJECT and a
# cached Google login for BigQuery); it is off by default. Raw files that cannot be scripted are listed in README.md.
# Not in STEPS: empirics/scripts/10_robust_synthdid_python.py (optional cross-check in a separate Python env with the
# synthdid package; see its header).
STEPS = [
    ("collection", "data/scripts/collection/acquire_wb.py", []),
    ("collection", "data/scripts/collection/acquire_openalex.py", ["acquire_wb"]),
    ("collection", "data/scripts/collection/acquire_pwt.py", ["acquire_wb"]),
    ("collection", "data/scripts/collection/acquire_oecd.py", []),
    ("collection", "data/scripts/collection/acquire_bigquery_ru.py", []),
    ("collection", "data/scripts/collection/acquire_openalex_regions.py", []),
    ("collection", "data/scripts/collection/acquire_rospatent_api.py", []),
    ("collection", "data/scripts/collection/acquire_rospatent_api_apps.py", []),
    ("collection", "data/scripts/collection/acquire_rfsd.py", []),
    ("collection", "data/scripts/collection/acquire_bigquery_movers.py", []),
    ("collection", "data/scripts/collection/acquire_openalex_authors.py", []),
    ("cleaning", "data/scripts/cleaning/clean_gsdb.py", []),
    ("cleaning", "data/scripts/cleaning/clean_rospatent.py", []),
    ("cleaning", "data/scripts/cleaning/clean_wb_covariates.py", []),
    ("cleaning", "data/scripts/cleaning/clean_concordances.R", []),
    ("cleaning", "data/scripts/cleaning/clean_eu_sanctions.py", ["clean_concordances"]),
    ("cleaning", "data/scripts/cleaning/clean_rospatent_api.py", []),
    ("cleaning", "data/scripts/cleaning/clean_rospatent_api_apps.py", []),
    ("cleaning", "data/scripts/cleaning/clean_bea.py", []),
    ("processing", "data/scripts/processing/process_country_panel.py", ["clean_gsdb"]),
    ("processing", "data/scripts/processing/process_field_panel_2014.py", []),
    ("processing", "data/scripts/processing/process_ru_patents_google.py", []),
    ("processing", "data/scripts/processing/process_region_panel.py", ["process_country_panel", "clean_rospatent"]),
    ("processing", "data/scripts/processing/process_title_fields.py", ["clean_rospatent"]),
    ("processing", "data/scripts/processing/process_ru_imports.py", []),
    ("processing", "data/scripts/processing/process_hs_field_maps.py", ["process_title_fields", "clean_concordances"]),
    ("processing", "data/scripts/processing/process_field_exposure.py",
     ["process_ru_imports", "process_hs_field_maps", "process_title_fields"]),
    ("processing", "data/scripts/processing/process_ban_coverage.py",
     ["clean_eu_sanctions", "process_ru_imports", "process_hs_field_maps", "process_title_fields"]),
    ("processing", "data/scripts/processing/process_field_holder_panel.py", ["process_title_fields"]),
    ("processing", "data/scripts/processing/process_title_subclasses.py", ["clean_rospatent"]),
    ("processing", "data/scripts/processing/process_subclass_ban_coverage.py",
     ["process_title_subclasses", "clean_eu_sanctions", "process_ru_imports"]),
    ("processing", "data/scripts/processing/process_official_ipc_panels.py", ["clean_rospatent", "clean_rospatent_api"]),
    ("processing", "data/scripts/processing/process_filings_panel.py",
     ["clean_rospatent_api_apps", "process_official_ipc_panels"]),
    ("processing", "data/scripts/processing/process_tech_proximity.py", ["clean_rospatent_api"]),
    ("processing", "data/scripts/processing/process_prewar_characteristics.py",
     ["process_official_ipc_panels", "process_ru_imports", "process_hs_field_maps"]),
    ("processing", "data/scripts/processing/process_dualuse_2014.py",
     ["process_title_fields", "process_ru_imports", "process_hs_field_maps"]),
    ("processing", "data/scripts/processing/process_industry_panel.py",
     ["process_official_ipc_panels", "clean_eu_sanctions", "process_ru_imports"]),
    ("processing", "data/scripts/processing/process_naics_isic_concord.R", ["clean_bea"]),
    ("processing", "data/scripts/processing/process_input_exposure.py",
     ["process_naics_isic_concord", "process_industry_panel"]),
    ("processing", "data/scripts/processing/process_input_exposure_ru.py", ["process_industry_panel"]),
    ("processing", "data/scripts/processing/process_inventor_panel.py",
     ["clean_rospatent_api", "clean_rospatent_api_apps"]),
    ("empirics", "empirics/scripts/01_explore_descriptives.R", ["process_country_panel"]),
    ("empirics", "empirics/scripts/02_analyze_cross_country_lp.R", ["process_country_panel"]),
    ("empirics", "empirics/scripts/03_robust_cross_country_leave_one_out.R", ["process_country_panel"]),
    ("empirics", "empirics/scripts/04_explore_cross_country_figures.R", ["02_analyze_cross_country_lp"]),
    ("empirics", "empirics/scripts/05_robust_lp_diagnostics.R", ["process_country_panel"]),
    ("empirics", "empirics/scripts/06_analyze_field_triple_diff_2014.R", ["process_field_panel_2014"]),
    ("empirics", "empirics/scripts/07_analyze_staggered_did.R", ["process_country_panel"]),
    ("empirics", "empirics/scripts/08_analyze_synthetic_did.R", ["process_country_panel"]),
    ("empirics", "empirics/scripts/09_robust_sdid_simulation.R", []),
    ("empirics", "empirics/scripts/11_robust_sdid_covariates.R", ["08_analyze_synthetic_did", "clean_wb_covariates"]),
    ("empirics", "empirics/scripts/12_explore_regions_openalex.R", []),
    ("empirics", "empirics/scripts/13_explore_ru_patents_types.R", ["process_ru_patents_google", "process_field_panel_2014"]),
    ("empirics", "empirics/scripts/14_explore_region_maps.R", ["process_region_panel"]),
    ("empirics", "empirics/scripts/15_explore_title_classifier_check.R", ["process_title_fields"]),
    ("empirics", "empirics/scripts/16_analyze_import_exposure_first_stage.R", ["process_field_exposure"]),
    ("empirics", "empirics/scripts/17_analyze_ban_first_stage.R", ["process_ban_coverage", "process_field_exposure"]),
    ("empirics", "empirics/scripts/18_analyze_patents_ban_test.R", ["process_ban_coverage", "process_field_holder_panel"]),
    ("empirics", "empirics/scripts/19_robust_patents_ban_trends.R", ["process_ban_coverage"]),
    ("empirics", "empirics/scripts/20_analyze_patents_2014.R", ["process_ban_coverage"]),
    ("empirics", "empirics/scripts/21_robust_patents_staggered.R", ["process_ban_coverage"]),
    ("empirics", "empirics/scripts/22_robust_patents_sector_fe.R", ["process_ban_coverage"]),
    ("empirics", "empirics/scripts/23_analyze_patents_holder_region.R", ["process_ban_coverage"]),
    ("empirics", "empirics/scripts/24_analyze_patents_subclass.R", ["process_subclass_ban_coverage"]),
    ("empirics", "empirics/scripts/25_analyze_patents_official.R", ["process_official_ipc_panels", "process_ban_coverage"]),
    ("empirics", "empirics/scripts/26_explore_official_raw_series.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/27_robust_subclass_twfe.R", ["process_official_ipc_panels", "process_subclass_ban_coverage"]),
    ("empirics", "empirics/scripts/28_explore_pitch_figures.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/29_robust_pretrend_tests.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/30_explore_raw_lines.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/31_robust_leave_one_out.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/32_explore_summary_figure.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/33_robust_oriv.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/34_analyze_spillovers.R", ["process_tech_proximity"]),
    ("empirics", "empirics/scripts/35_robust_oriv_spillovers.R", ["process_tech_proximity"]),
    ("empirics", "empirics/scripts/36_robust_honestdid.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/37_robust_prewar_controls.R", ["process_prewar_characteristics"]),
    ("empirics", "empirics/scripts/38_robust_bootstrap_es.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/39_analyze_2014_official.R", ["process_official_ipc_panels"]),
    ("empirics", "empirics/scripts/40_analyze_dualuse_2014.R", ["process_dualuse_2014"]),
    ("empirics", "empirics/scripts/41_analyze_industry_design.R", ["process_industry_panel"]),
    ("empirics", "empirics/scripts/42_analyze_input_exposure.R", ["process_input_exposure"]),
    ("empirics", "empirics/scripts/43_analyze_rosstat_input_exposure.R", ["process_input_exposure_ru"]),
    ("empirics", "empirics/scripts/44_robust_unbanned_western_inputs.R", ["process_input_exposure_ru"]),
    ("empirics", "empirics/scripts/45_analyze_filings_by_origin.R", ["process_filings_panel"]),
    ("empirics", "empirics/scripts/46_analyze_filings_2014.R", ["process_filings_panel"]),
    ("empirics", "empirics/scripts/47_analyze_inventor_exit.R", ["process_inventor_panel"]),
    ("empirics", "empirics/scripts/48_explore_movers_bigquery.R", []),
    ("empirics", "empirics/scripts/49_explore_openalex_movers.py", []),
]
STAGES = ["collection", "cleaning", "processing", "empirics"]
# data/ is not in git, so its output folders are created before a run
DATA_DIRS = ["data/logs", "empirics/results/logs", "empirics/results/tables", "empirics/results/figures",
             *(f"data/clean/{d}" for d in ("gsdb", "rospatent", "rospatent_api", "wb", "concordances", "eu_sanctions",
                                           "bea")),
             *(f"data/processed/{d}" for d in (
                 "country_panel", "field_panel_2014", "ru_patents_google", "region_panel", "title_fields",
                 "title_subclasses", "ru_imports", "hs_field_maps", "field_exposure", "ban_coverage",
                 "subclass_ban_coverage", "field_holder_panel", "official_ipc_panels", "filings_panel", "tech_proximity",
                 "prewar_characteristics", "dualuse_2014", "industry_panel", "input_exposure", "input_exposure_ru",
                 "inventor_panel", "sdid_cases"))]


def stata_bin():
    return shutil.which("stata-mp") or shutil.which("stata-se") or shutil.which("stata") or "stata"


def command_for(script: str) -> list:
    suffix = Path(script).suffix
    if suffix == ".py":
        return [sys.executable, "-I", "-W", "ignore", script]
    if suffix.lower() == ".r":
        return [RSCRIPT, script]
    if suffix == ".do":
        return [stata_bin(), "-b", "do", script]
    raise ValueError(f"don't know how to run {script}")


def git_commit() -> str:
    try:
        h = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True,
                           text=True, check=True).stdout.strip()
        dirty = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True,
                               text=True).stdout.strip()
        return h + ("-dirty" if dirty else "")
    except (subprocess.CalledProcessError, FileNotFoundError):
        inside = subprocess.run(["git", "rev-parse", "--is-inside-work-tree"], cwd=ROOT,
                                capture_output=True).returncode == 0 if shutil.which("git") else False
        return "uncommitted" if inside else "no-git"


def log_attempt(what: str, command: str, outcome: str, details: str) -> None:
    path = ROOT / "attempts-log.csv"
    new = not path.exists()
    with path.open("a", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        if new:
            w.writerow(["timestamp", "actor", "what", "command", "outcome", "details", "git_commit"])
        w.writerow([datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "run_all", what, command,
                    outcome, details, git_commit()])


def session_info(steps) -> None:
    """Document the software environment of this run (G3)."""
    lines = [f"Python {platform.python_version()} ({sys.executable})", f"Platform {platform.platform()}",
             f"Commit {git_commit()}", ""]
    if shutil.which("uv"):
        out = subprocess.run(["uv", "pip", "freeze", "--python", sys.executable],
                             cwd=ROOT, capture_output=True, text=True)
        lines += ["# Python packages (uv pip freeze; pinned in uv.lock)", out.stdout.strip(), ""]
    if any(s.lower().endswith(".r") for _, s, _ in steps) and shutil.which(RSCRIPT):
        out = subprocess.run([RSCRIPT, "-e", "sessionInfo()"], cwd=ROOT, capture_output=True, text=True)
        lines += ["# R sessionInfo() (pinned in renv.lock)", (out.stdout or out.stderr).strip(), ""]
    if any(s.endswith(".do") for _, s, _ in steps):
        lines += ["# Stata: version and ado packages are listed in README.md", f"binary: {stata_bin()}", ""]
    (ROOT / "data/logs/session_info.log").write_text("\n".join(lines) + "\n", encoding="utf-8")


def stata_failed(script: str) -> bool:
    """Stata batch mode exits 0 on error; its batch log in the cwd shows r(###);."""
    batch_log = ROOT / (Path(script).stem + ".log")
    if not batch_log.exists():
        return False
    text = batch_log.read_text(errors="replace")
    batch_log.unlink()  # the do-file keeps its own log under data/logs or empirics/results/logs
    return bool(re.search(r"^r\(\d+\);", text, re.M))


def validate_steps() -> None:
    names = [Path(s).stem for _, s, _ in STEPS]
    for i, (stage, script, needs) in enumerate(STEPS):
        assert stage in STAGES, f"{script}: unknown stage {stage}"
        for n in needs:
            assert n in names[:i], f"{script} needs {n}, which is not an earlier step"
    nums = [int(Path(s).name[:2]) for st, s, _ in STEPS if st == "empirics" and Path(s).name[:2].isdigit()]
    assert nums == sorted(nums), f"empirics scripts are not numbered in run order: {nums}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--with-collection", action="store_true")
    ap.add_argument("--stage", choices=STAGES)
    ap.add_argument("--only")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--set-baseline", action="store_true")
    args = ap.parse_args()
    validate_steps()

    steps = [s for s in STEPS if s[0] != "collection" or args.with_collection or args.stage == "collection"]
    if args.stage:
        steps = [s for s in steps if s[0] == args.stage]
    if args.only:
        steps = [s for s in steps if args.only in Path(s[1]).stem]
        if not steps:
            sys.exit(f"--only {args.only!r} matches no step")
    if args.list:
        for stage, script, needs in steps:
            print(f"{stage:<11} {script:<60} needs: {', '.join(needs) or '-'}")
        return

    for d in DATA_DIRS:
        (ROOT / d).mkdir(parents=True, exist_ok=True)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)-7s | %(message)s",
                        handlers=[logging.FileHandler(ROOT / "data/logs/run_all.log", mode="w"),
                                  logging.StreamHandler(sys.stdout)])
    log = logging.getLogger("run_all")
    invocation = "run_all.py " + " ".join(sys.argv[1:])
    log.info("START %s: %d steps", invocation, len(steps))
    session_info(steps)

    for stage, script, _ in steps:
        cmd = command_for(script)
        log.info("RUN [%s] %s", stage, " ".join(cmd))
        step_log = ROOT / ("empirics/results/logs" if stage == "empirics" else "data/logs") / (Path(script).stem + ".log")
        with step_log.open("w", encoding="utf-8") as fh:  # one log per script, overwritten each run (G5)
            rc = subprocess.run(cmd, cwd=ROOT, stdout=fh, stderr=subprocess.STDOUT).returncode
        if rc != 0 or (script.endswith(".do") and stata_failed(script)):
            log.error("FAILED %s (exit %d); see %s", script, rc, step_log.relative_to(ROOT))
            log_attempt("pipeline run", invocation, "failure", f"failed at {script}")
            sys.exit(rc or 1)
        log.info("DONE %s", script)

    if args.set_baseline or args.check:
        flag = ["--set-baseline"] if args.set_baseline else []
        rc = subprocess.run([sys.executable, CHECK_SCRIPT] + flag, cwd=ROOT).returncode
        if args.check and rc != 0:
            log.warning("outputs differ from archive/baseline: see data/logs/check_baseline.log")
            log_attempt("pipeline run + baseline check", invocation, "failure",
                        "outputs differ from baseline")
            sys.exit(1)
    log.info("END run_all")
    log_attempt("pipeline run", invocation, "success", f"{len(steps)} steps")


if __name__ == "__main__":
    main()
