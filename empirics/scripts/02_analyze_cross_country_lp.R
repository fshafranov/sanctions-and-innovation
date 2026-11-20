# 02_cross_country_lp.R: country-year responses of innovation outcomes to sanctions, three event codings.
#
#  onset     (panel LP on case onset): for h = 1..H
#              y(t+h) = b_h new(t) + sum_{l=1,2} [c_l new(t-l) + d_l y(t-l)] (+ e y(t) if shock second) + a_i + g_t
#            new(t) = 1 if at least one case of the measure begins in t. SE clustered by country.
#  intensity same, with new(t) replaced by the number of cases in force.
#  episode5  (LP-DiD, Dube-Girardi-Jorda-Taylor): y(t+h) - y(t-1) = b_h E(t) + g_t, h = -5..H,
#            E(t) = case begins in t and no case of the measure in force in t-5..t-1;
#            controls = countries with no case of the measure in force in t-5..t+h ("clean").
#  Counts: PPML on the level (estimator option "ols": OLS on log(1+y)) (lags in log(1+y)); LP-DiD uses log(1+y) differences. b_h ~ log points.
#
# Output: empirics/results/tables/lp_results.csv, empirics/results/tables/run_log.csv (one row per run)
source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "specifications.R"))

source(here::here("empirics", "scripts", "lp_functions.R"))

panel <- read_panel()
grid <- spec_grid()
t0 <- Sys.time()
results <- pmap_dfr(grid, function(...) {
  spec <- list(...)
  map2_dfr(OUTCOMES$outcome, OUTCOMES$kind, ~ run_one(panel, spec, .x, .y))
}) %>%
  left_join(OUTCOMES, by = "outcome") %>%
  mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se)

write_csv(results, file.path(TAB_DIR, "lp_results.csv"))
commit <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) NA, warning = function(w) NA)
log_row <- tibble(run_time = format(Sys.time(), "%Y-%m-%d %H:%M"), git_commit = commit, n_specs = nrow(grid),
                  n_paths = nrow(distinct(results, measure, coding, sample, timing, controls, outcome)),
                  minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1))
log_file <- file.path(TAB_DIR, "run_log.csv")
write_csv(log_row, log_file, append = file.exists(log_file))
print(log_row)

# Console summary: base onset LP and LP-DiD, cells whose 95% interval excludes zero
results %>% filter(sample == "base", timing == "second", controls == "none", horizon > 0 | coding == "episode5",
                   horizon != -1) %>%
  group_by(measure, coding, outcome) %>%
  summarise(cells = sum(!is.na(estimate)), excl_zero_neg = sum(hi < 0, na.rm = TRUE),
            excl_zero_pos = sum(lo > 0, na.rm = TRUE), events_h1 = first(n_events[horizon %in% c(0, 1)]),
            .groups = "drop") %>%
  print(n = 100)
