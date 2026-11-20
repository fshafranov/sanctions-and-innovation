# 04_figures.R: figures from output/tables/lp_results.csv and leave_one_out.csv (Healy style: facets,
# intervals, zero line, full labels).
source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "specifications.R"))

res <- read_csv(file.path(TAB_DIR, "lp_results.csv"), show_col_types = FALSE) %>%
  mutate(label = factor(label, levels = OUTCOMES$label),
         measure_label = factor(DIMENSIONS$measure[measure], levels = DIMENSIONS$measure))

base_caption <- function(extra, counts = "Counts (patents, articles): PPML, coefficients ~ log points; other outcomes OLS.") paste0(
  "Sanctions: GSDB V4. Western = US, EU, UN, UK, Canada, Japan, Australia, Switzerland, Norway; economic = trade or financial measure;\n",
  "placebo = Western case with arms, military, travel or other measures only. ",
  "Countries with median population >= 1m; event years 1995-2023.\nBands: 95% CI, SE clustered by country. ",
  counts, "\n", extra)

path_plot <- function(d, title, xlab, caption, colour_var = measure_label) {
  ggplot(d, aes(horizon, estimate, colour = {{ colour_var }}, fill = {{ colour_var }})) +
    geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, colour = NA) +
    geom_line(linewidth = 0.6) + geom_point(size = 0.9) +
    facet_wrap(~ label, scales = "free_y", ncol = 3) +
    scale_colour_manual(values = MEASURE_COLOURS, name = NULL, aesthetics = c("colour", "fill")) +
    scale_x_continuous(breaks = seq(-PRE, H_MAX, 2)) +
    labs(title = title, x = xlab, y = "Response", caption = caption) + theme_paper()
}

base <- res %>% filter(sample == "base", timing == "second", controls == "none", estimator == "ppml",
                       measure %in% c("west_econ", "west_placebo"))

p1 <- path_plot(base %>% filter(coding == "onset"),
  "Innovation outcomes after the onset of a new sanction case",
  "Years after onset (h)",
  base_caption(paste0("Panel LP: y(t+h) on new case in t, 2 lags of shock and outcome, ",
                      "outcome in t (shock second), country and year FE. h = 0 is 0 by construction.")))
save_figure(p1, "fig1_onset_lp", 9, 7.5)

p2 <- path_plot(base %>% filter(coding == "episode5"),
  "Innovation outcomes around a new sanction episode (no case in force in the previous 5 years)",
  "Years relative to the episode start (h; h = -1 is the reference)",
  base_caption(paste0("LP-DiD: y(t+h) - y(t-1) on the episode dummy, year FE; controls = countries with no case ",
                      "of the same measure in force in t-5..t+h."),
               counts = "Counts in log(1+y) differences (~ log points); other outcomes in levels or logs as labelled."))
save_figure(p2, "fig2_episode_lpdid", 9, 7.5)

p3 <- path_plot(base %>% filter(coding == "intensity"),
  "Innovation outcomes after one more sanction case in force",
  "Years after the change (h)",
  base_caption("Panel LP as in fig1, shock = number of cases of the measure in force."))
save_figure(p3, "fig3_intensity_lp", 9, 7.5)

# fig4: Western economic, all specifications at h = 4 (h = 4 relative to t-1 for LP-DiD)
variant_label <- function(d) d %>% mutate(variant = case_when(
  sample != "base" ~ DIMENSIONS$sample[sample],
  timing != "second" & coding != "episode5" ~ "Shock first",
  controls != "none" ~ "Lagged GDP p.c. growth",
  estimator != "ppml" ~ "OLS on log(1+y) for counts",
  TRUE ~ "Base"))
v <- res %>% filter(measure == "west_econ", horizon == 4, !is.na(estimate)) %>% variant_label() %>%
  mutate(coding_label = factor(DIMENSIONS$coding[coding], levels = DIMENSIONS$coding),
         variant = fct_rev(factor(variant, levels = unique(c("Base", DIMENSIONS$sample[-1], "Shock first",
                                                              "Lagged GDP p.c. growth", "OLS on log(1+y) for counts")))))
p4 <- ggplot(v, aes(estimate, variant)) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_pointrange(aes(xmin = lo, xmax = hi, colour = variant == "Base"), size = 0.2, linewidth = 0.4) +
  facet_grid(coding_label ~ label, scales = "free", space = "free_y", labeller = label_wrap_gen(18)) +
  scale_colour_manual(values = c(`TRUE` = "#0072B2", `FALSE` = "grey35"), guide = "none") +
  labs(title = "Western economic sanctions: response at h = 4 across specifications",
       x = "Response at h = 4 (95% CI)", y = NULL,
       caption = paste0("Each row changes one dimension of the base specification (blue). ",
                        "Shock first and OLS do not apply to LP-DiD. Specification table: empirics/scripts/specifications.R.")) +
  theme_paper() + theme(strip.text.y = element_text(angle = 0), axis.text.x = element_text(size = 6.5))
save_figure(p4, "fig4_specifications_h4", 13, 6.5)

# fig5: leave one country out
loo_file <- file.path(TAB_DIR, "leave_one_out.csv")
if (file.exists(loo_file)) {
  loo <- read_csv(loo_file, show_col_types = FALSE) %>%
    filter(measure == "west_econ") %>%
    mutate(label = factor(label, levels = OUTCOMES$label), lo = estimate - 1.96 * se, hi = estimate + 1.96 * se)
  full <- loo %>% filter(dropped == "none")
  top <- loo %>% filter(dropped != "none") %>% group_by(outcome, horizon) %>%
    mutate(shift = abs(estimate - full$estimate[full$outcome == first(outcome) & full$horizon == first(horizon)])) %>%
    slice_max(shift, n = 2) %>% ungroup()
  p5 <- ggplot(loo %>% filter(dropped != "none"), aes(factor(horizon), estimate)) +
    geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_jitter(width = 0.12, height = 0, size = 0.7, alpha = 0.5, colour = "grey40") +
    geom_pointrange(data = full, aes(ymin = lo, ymax = hi), colour = "#0072B2", size = 0.3) +
    geom_text(data = top, aes(label = dropped), size = 2.4, nudge_x = 0.3, colour = "#D55E00") +
    facet_wrap(~ label, scales = "free_y", nrow = 1) +
    labs(title = "Onset LP, Western economic sanctions: dropping one event country at a time",
         x = "Years after onset (h)", y = "Response",
         caption = paste0("Blue: full sample with 95% CI. Grey: one estimate per dropped event country. Labelled: ",
                          "the two countries whose removal moves the estimate most. PPML, base specification.")) +
    theme_paper()
  save_figure(p5, "fig5_leave_one_out", 11, 4)
}
