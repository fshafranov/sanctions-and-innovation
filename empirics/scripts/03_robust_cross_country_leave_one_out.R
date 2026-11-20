# 03_leave_one_out.R: base onset LP (Western economic, and the placebo measure), dropping one event country at a time.
# Counts are estimated by PPML, which weights countries by their level (China files ~1.5m resident patent
# applications a year), so a few large countries can carry the pooled estimate.
# Output: empirics/results/tables/leave_one_out.csv
source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "specifications.R"))
source(here::here("empirics", "scripts", "lp_functions.R"))

LOO_OUTCOMES <- c("pat_res", "pat_nres", "articles_wb", "works_oa", "tfp")
LOO_H <- c(2, 4, 6)
panel <- read_panel()
base_spec <- list(coding = "onset", sample = "base", timing = "second", controls = "none", estimator = "ppml")

loo <- map_dfr(c("west_econ", "west_placebo"), function(m) {
  spec <- c(list(measure = m), base_spec)
  event_countries <- panel %>%
    filter(.data[[paste0("new_", m)]] == 1, year %in% SAMPLE_RULES$base$years, pop_ge1m == 1) %>%
    distinct(iso3) %>% pull()
  map_dfr(LOO_OUTCOMES, function(o) {
    kind <- OUTCOMES$kind[OUTCOMES$outcome == o]
    map_dfr(c("none", event_countries), function(c) {
      run_one(panel %>% filter(iso3 != c), spec, o, kind) %>%
        filter(horizon %in% LOO_H) %>% mutate(dropped = c)
    })
  })
}) %>% left_join(OUTCOMES %>% select(outcome, label), by = "outcome")
write_csv(loo, file.path(TAB_DIR, "leave_one_out.csv"))

# Most influential country per outcome x horizon
loo %>% group_by(measure, outcome, horizon) %>%
  mutate(full = estimate[dropped == "none"], shift = estimate - full) %>%
  filter(dropped != "none") %>% slice_max(abs(shift), n = 3) %>%
  select(measure, outcome, horizon, full, dropped, estimate, se, shift) %>% print(n = 80)
