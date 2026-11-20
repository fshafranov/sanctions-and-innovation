# 11_staggered_did.R: cross-country event studies with staggered adoption (main method from 12 Nov 2026; the local
# projections in 02/03 are kept as a robustness check).
#
# Treatment (absorbing, intention-to-treat): a country is treated from its FIRST clean episode g of the measure,
#   i.e. the first year in 1995-2023 in which a case begins after >= 5 years with no case in force (= episode5 in
#   the panel). Later cases, and the end of the case, are ignored (effects = "after the first sanction episode").
# Never treated: no case of the measure in force in any year 1990-2023. Dropped: countries with cases in force but
#   no clean episode in 1995-2023 (always or continuously sanctioned).
# Cohort variant "first_ever": only cohorts with no case in force in any year before g since 1985.
# Estimators (relative time -5..8, base period -1, SE clustered by country):
#   twfe   OLS dynamic TWFE: y_it = a_i + g_t + sum_k b_k 1[t - g_i = k] (endpoints binned) -- biased if effects differ
#          across cohorts or over time; shown for comparison only
#   sa     Sun-Abraham (fixest::sunab), never-treated as the control cohort; OLS, and PPML for counts (sa_ppml)
#   cs     Callaway-Sant'Anna (did::att_gt), never-treated controls (cs) or not-yet-treated (cs_nyt); outcome-
#          regression DiD without covariates, universal base period, aggregated to event time (aggte dynamic)
# Outcomes: counts in log(1+y) for OLS estimators (equal weight per country); PPML on levels weights big countries.
# Output: empirics/results/tables/staggered_did.csv, empirics/results/tables/staggered_cohorts.csv, figures fig17-fig19.
source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "specifications.R"))
suppressPackageStartupMessages(library(did))
set.seed(20261112)

EMIN <- -5; EMAX <- 8
panel <- read_panel()

cohorts <- function(measure, variant = "episode5") {
  act <- paste0("n_active_", measure); ep <- paste0("episode5_", measure)
  panel %>% group_by(iso3) %>%
    summarise(ever = any(.data[[act]] > 0 & year %in% 1990:2023, na.rm = TRUE),
              g = suppressWarnings(min(year[.data[[ep]] == 1 & year %in% 1995:2023], na.rm = TRUE)),
              act_before = any(.data[[act]] > 0 & year < g, na.rm = TRUE), .groups = "drop") %>%
    mutate(g = case_when(!ever ~ 0, is.finite(g) & (variant == "episode5" | !act_before) ~ g, TRUE ~ NA_real_)) %>%
    filter(!is.na(g)) %>% select(iso3, g)
}

prep <- function(outcome, kind, measure, sample, variant) {
  rule <- SAMPLE_RULES[[sample]]
  panel %>% inner_join(cohorts(measure, variant), by = "iso3") %>%
    filter(year %in% 1990:2023, !rule$pop_ge1m | pop_ge1m == 1, !iso3 %in% rule$drop) %>%
    mutate(y = .data[[outcome]], yy = transform_y(y, kind), id = as.integer(factor(iso3)),
           rel = if_else(g > 0, year - g, NA_real_),
           rel_b = case_when(is.na(rel) ~ -1000, rel < EMIN ~ EMIN - 1, rel > EMAX ~ EMAX + 1, TRUE ~ rel),
           g_sa = if_else(g == 0, 10000, g)) %>%
    filter(!is.na(yy))
}

tidy_rel <- function(fit, pat) {
  ct <- coeftable(fit)
  tibble(term = rownames(ct), estimate = ct[, 1], se = ct[, 2]) %>%
    filter(str_detect(term, pat)) %>%
    mutate(e = as.numeric(str_extract(term, "-?\\d+$"))) %>% filter(between(e, EMIN, EMAX)) %>% select(e, estimate, se)
}

est_one <- function(outcome, kind, measure, sample, variant, estimators) {
  d <- prep(outcome, kind, measure, sample, variant)
  n_coh <- n_distinct(d$iso3[d$g > 0]); n_nev <- n_distinct(d$iso3[d$g == 0])
  out <- list()
  if ("twfe" %in% estimators) out$twfe <- tryCatch(
    tidy_rel(feols(yy ~ i(rel_b, ref = c(-1, -1000)) | iso3 + year, d, cluster = ~iso3), "rel_b"),
    error = function(e) NULL)
  if ("sa" %in% estimators) out$sa <- tryCatch(
    tidy_rel(feols(yy ~ sunab(g_sa, year) | iso3 + year, d, cluster = ~iso3), "year::"),
    error = function(e) NULL)
  if ("sa_ppml" %in% estimators && kind == "count") out$sa_ppml <- tryCatch(
    tidy_rel(fepois(y ~ sunab(g_sa, year) | iso3 + year, d, cluster = ~iso3), "year::"),
    error = function(e) NULL)
  for (cg in intersect(c("cs", "cs_nyt"), estimators)) out[[cg]] <- tryCatch({
    a <- suppressWarnings(att_gt(yname = "yy", tname = "year", idname = "id", gname = "g", data = as.data.frame(d),
                                 control_group = if (cg == "cs") "nevertreated" else "notyettreated",
                                 base_period = "universal", est_method = "reg", allow_unbalanced_panel = TRUE,
                                 clustervars = "id", bstrap = TRUE, biters = 999, cband = FALSE))
    ag <- aggte(a, type = "dynamic", min_e = EMIN, max_e = EMAX, na.rm = TRUE, bstrap = TRUE, cband = FALSE)
    tibble(e = ag$egt, estimate = ag$att.egt, se = ag$se.egt)
  }, error = function(e) { message(outcome, " ", measure, " ", sample, " ", cg, ": ", conditionMessage(e)); NULL })
  bind_rows(out, .id = "estimator") %>%
    mutate(outcome = outcome, measure = measure, sample = sample, variant = variant,
           n_cohort_countries = n_coh, n_never = n_nev)
}

# grid: main = Western economic, base sample, episode5 cohorts, all estimators; robustness one dimension at a time
grid <- bind_rows(
  expand_grid(measure = "west_econ", sample = "base", variant = "episode5",
              estimators = list(c("twfe", "sa", "sa_ppml", "cs", "cs_nyt"))),
  expand_grid(measure = "west_econ", sample = c("no_chn", "no_big3"), variant = "episode5",
              estimators = list(c("sa", "sa_ppml", "cs"))),
  expand_grid(measure = "west_econ", sample = "base", variant = "first_ever", estimators = list(c("sa", "cs"))),
  expand_grid(measure = c("west_placebo", "any_econ"), sample = "base", variant = "episode5",
              estimators = list(c("sa", "cs"))))

res <- pmap_dfr(grid, function(measure, sample, variant, estimators)
  map2_dfr(OUTCOMES$outcome, OUTCOMES$kind, ~ est_one(.x, .y, measure, sample, variant, estimators))) %>%
  left_join(OUTCOMES, by = "outcome") %>%
  mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se)
write_csv(res, file.path(TAB_DIR, "staggered_did.csv"))

coh <- map_dfr(names(DIMENSIONS$measure), function(m) bind_rows(
  cohorts(m) %>% mutate(variant = "episode5"), cohorts(m, "first_ever") %>% mutate(variant = "first_ever")) %>%
  mutate(measure = m)) %>% left_join(distinct(panel, iso3, name, pop_ge1m), by = "iso3")
write_csv(coh, file.path(TAB_DIR, "staggered_cohorts.csv"))

# figures ---------------------------------------------------------------------------------------------------------
EST_LAB <- c(twfe = "TWFE (OLS)", sa = "Sun-Abraham (OLS)", cs = "Callaway-Sant'Anna, never treated",
             cs_nyt = "Callaway-Sant'Anna, not yet treated", sa_ppml = "Sun-Abraham (PPML, counts)")
EST_COL <- c("TWFE (OLS)" = "#999999", "Sun-Abraham (OLS)" = "#0072B2",
             "Callaway-Sant'Anna, never treated" = "#D55E00", "Callaway-Sant'Anna, not yet treated" = "#E69F00",
             "Sun-Abraham (PPML, counts)" = "#009E73")
add_ref <- function(x) bind_rows(x, distinct(x, across(-c(e, estimate, se, lo, hi))) %>%
                                   mutate(e = -1, estimate = 0, se = 0, lo = 0, hi = 0))
es_plot <- function(x, colour_by, title, caption, ncol = 4) {
  ggplot(x, aes(e, estimate, colour = .data[[colour_by]], fill = .data[[colour_by]])) +
    geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_vline(xintercept = -0.5, linetype = "dashed", colour = "grey60") +
    geom_pointrange(aes(ymin = lo, ymax = hi), position = position_dodge(width = 0.6), size = 0.15,
                    linewidth = 0.35) +
    facet_wrap(~label, scales = "free_y", ncol = ncol) +
    scale_x_continuous(breaks = seq(EMIN, EMAX, 2)) +
    labs(x = "Years since the first clean sanction episode", y = "Effect (log points; pp for shares)",
         colour = NULL, fill = NULL, title = title, caption = caption) +
    theme_paper()
}
cap <- paste("Western economic sanctions (GSDB). Treated from the first case starting after >= 5 years without one",
             "(1995-2023); never treated = no case 1990-2023.\nCountries with population >= 1m. Base period -1;",
             "95% intervals clustered by country. Counts in log(1+y) except PPML.")

main <- res %>% filter(measure == "west_econ", sample == "base", variant == "episode5") %>%
  mutate(est = factor(EST_LAB[estimator], EST_LAB)) %>% add_ref() %>%
  mutate(label = factor(label, OUTCOMES$label))
save_figure(es_plot(main, "est", "Innovation outcomes after a first Western economic sanction episode", cap) +
              scale_colour_manual(values = EST_COL, aesthetics = c("colour", "fill")),
            "fig17_staggered_did_estimators", 12, 8)

samp <- res %>% filter(measure == "west_econ", variant == "episode5", estimator == "cs") %>%
  mutate(smp = factor(DIMENSIONS$sample[sample], DIMENSIONS$sample)) %>% add_ref() %>%
  filter(outcome %in% c("pat_res", "pat_nres", "works_oa", "articles_wb", "intl_share", "tfp")) %>%
  mutate(label = factor(label, OUTCOMES$label))
save_figure(es_plot(samp, "smp", "Callaway-Sant'Anna: does the result depend on China, Russia and Iran?", cap, 3) +
              scale_colour_manual(values = c("#D55E00", "#0072B2", "#009E73"), aesthetics = c("colour", "fill")),
            "fig18_staggered_did_samples", 11, 6.5)

meas <- res %>% filter(sample == "base", estimator == "cs",
                       (measure == "west_econ" & variant %in% c("episode5", "first_ever")) | measure != "west_econ") %>%
  mutate(m = case_when(variant == "first_ever" ~ "Western economic, first-ever sanction only",
                       measure == "west_placebo" ~ "Western, other sanction types (arms/travel)",
                       TRUE ~ DIMENSIONS$measure[measure])) %>% add_ref() %>%
  filter(outcome %in% c("pat_res", "pat_nres", "works_oa", "articles_wb", "intl_share", "tfp")) %>%
  mutate(label = factor(label, OUTCOMES$label))
save_figure(es_plot(meas, "m", "Callaway-Sant'Anna by sanction measure and cohort definition", cap, 3) +
              scale_colour_manual(values = c("#D55E00", "#56B4E9", "#CC79A7", "#009E73"),
                                  aesthetics = c("colour", "fill")),
            "fig19_staggered_did_measures", 11, 6.5)

# console summary: which cells exclude zero, pre (-5..-2) and post (0..8)
res %>% mutate(period = if_else(e < 0, "pre", "post")) %>% filter(e != -1) %>%
  group_by(measure, sample, variant, estimator, outcome, period) %>%
  summarise(cells = n(), neg = sum(hi < 0, na.rm = TRUE), pos = sum(lo > 0, na.rm = TRUE),
            mean_est = round(mean(estimate, na.rm = TRUE), 3), .groups = "drop") %>%
  pivot_wider(names_from = period, values_from = c(cells, neg, pos, mean_est)) %>%
  select(measure, sample, variant, estimator, outcome, neg_pre, pos_pre, mean_est_pre, neg_post, pos_post,
         mean_est_post) %>% print(n = 300)
print(res %>% distinct(measure, sample, variant, outcome, n_cohort_countries, n_never) %>%
        filter(sample == "base", variant == "episode5"), n = 50)
