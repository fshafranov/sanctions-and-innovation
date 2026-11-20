# 05_diagnostics.R: why the placebo (arms/travel-only) responses are as large as, or larger than, the economic ones.
#  (a) overlap: how often a placebo onset coincides with Western economic sanctions
#  (b) placebo LP controlling for Western economic sanctions (onset, 2 lags, cases in force)
#  (c) which events carry the PPML estimate: patent level in t-1 (the PPML weight) and log change to t+4
# Output: empirics/results/tables/diag_overlap.csv, diag_placebo_controlled.csv, diag_event_contributions.csv
source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "specifications.R"))
source(here::here("empirics", "scripts", "lp_functions.R"))

panel <- read_panel() %>%
  group_by(iso3) %>%
  mutate(econ_window = (lag(new_west_econ, 2) + lag(new_west_econ, 1) + new_west_econ +
                          lead(new_west_econ, 1) + lead(new_west_econ, 2)) > 0,
         econ_l1 = lag(new_west_econ, 1), econ_l2 = lag(new_west_econ, 2),
         pat_res_l1 = lag(pat_res, 1), pat_res_f4 = lead(pat_res, 4),
         pat_nres_l1 = lag(pat_nres, 1), pat_nres_f4 = lead(pat_nres, 4)) %>%
  ungroup()
base_rows <- panel %>% filter(year %in% 1995:2023, pop_ge1m == 1)

# (a) overlap
overlap <- base_rows %>% filter(new_west_placebo == 1) %>%
  summarise(placebo_onsets = n(),
            econ_case_in_force = mean(n_active_west_econ > 0),
            econ_onset_same_year = mean(new_west_econ == 1),
            econ_onset_within_2y = mean(econ_window, na.rm = TRUE))
print(overlap); write_csv(overlap, file.path(TAB_DIR, "diag_overlap.csv"))

# (b) placebo onset LP with Western economic sanctions as controls
lp_controlled <- function(d, kind, econ_controls) {
  rhs <- c("s", "s_l1", "s_l2", "yy_l1", "yy_l2", "yy", if (econ_controls) c("econ", "econ_l1", "econ_l2", "econ_act"))
  map_dfr(1:H_MAX, function(h) {
    dh <- d %>% group_by(iso3) %>%
      mutate(s = new, s_l1 = lag(new), s_l2 = lag(new, 2), econ = new_west_econ, econ_act = n_active_west_econ,
             dep = if (kind == "count") lead(y, h) else lead(yy, h)) %>% ungroup() %>%
      filter(in_sample) %>% drop_na(all_of(c("dep", rhs)))
    f <- as.formula(paste("dep ~", paste(rhs, collapse = " + "), "| iso3 + year"))
    fit <- if (kind == "count") fepois(f, dh, cluster = ~iso3) else feols(f, dh, cluster = ~iso3)
    tibble(horizon = h, estimate = coef(fit)["s"], se = se(fit)["s"])
  })
}
ctrl <- map_dfr(c("pat_res", "pat_nres", "articles_wb", "works_oa"), function(o) {
  kind <- OUTCOMES$kind[OUTCOMES$outcome == o]
  d <- prep(panel, o, kind, "west_placebo", "base") %>%
    group_by(iso3) %>% mutate(econ_l1 = lag(new_west_econ), econ_l2 = lag(new_west_econ, 2)) %>% ungroup()
  bind_rows(lp_controlled(d, kind, FALSE) %>% mutate(controls = "none"),
            lp_controlled(d, kind, TRUE) %>% mutate(controls = "Western economic sanctions"),
            lp_controlled(d %>% filter(iso3 != "IRN"), kind, TRUE) %>% mutate(controls = "Western economic, without Iran")) %>%
    mutate(outcome = o)
})
write_csv(ctrl, file.path(TAB_DIR, "diag_placebo_controlled.csv"))
ctrl %>% filter(horizon %in% c(2, 4, 6)) %>%
  mutate(cell = sprintf("%.2f (%.2f)", estimate, se)) %>%
  select(outcome, controls, horizon, cell) %>% pivot_wider(names_from = horizon, values_from = cell, names_prefix = "h") %>%
  print(n = 20)

# (c) events, their PPML weight and their raw change
contrib <- base_rows %>%
  filter(new_west_econ == 1 | new_west_placebo == 1, !is.na(pat_res_l1), !is.na(pat_res_f4)) %>%
  transmute(iso3, year, measure = case_when(new_west_econ == 1 & new_west_placebo == 1 ~ "both",
                                            new_west_econ == 1 ~ "economic", TRUE ~ "placebo"),
            pat_res_l1, d_log_res = log1p(pat_res_f4) - log1p(pat_res_l1),
            pat_nres_l1, d_log_nres = log1p(pat_nres_f4) - log1p(pat_nres_l1)) %>%
  group_by(measure) %>% mutate(weight_share = pat_res_l1 / sum(pat_res_l1)) %>% ungroup() %>%
  arrange(measure, desc(weight_share))
write_csv(contrib, file.path(TAB_DIR, "diag_event_contributions.csv"))
contrib %>% group_by(measure) %>% slice_head(n = 6) %>%
  mutate(across(c(d_log_res, d_log_nres, weight_share), ~ round(.x, 2))) %>% print(n = 30)
