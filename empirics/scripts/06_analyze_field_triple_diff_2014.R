# 07_field_triple_diff.R: Design A. Russia 2014, country x technology field x year (notes/02_theory_and_design.md).
#
#   y_ckt = exp( sum_t b_t [RUS_c x Dep_k x 1(year = t)] + a_ct + g_kt + m_ck )      (event study, ref. year 2013)
#   y_ckt = exp( b [RUS_c x Dep_k x Post_t] + a_ct + g_kt + m_ck )                   (pooled)
#
# Dep_k = z-scored share of world PCT applications 2008-13 in field k from the 2014 Russia senders (F2).
# b < 0: after 2014, Russia's filings fell more in fields where the senders hold more of the world's technology,
# relative to the same fields in comparison countries and to Russia's other fields. Country x year FE absorb the
# war, recession and ruble; field x year FE absorb global field trends.
#
# Panels: domestic = residents' publications at their own office (WIPO; publication year, about 18 months after
#         filing, so 2014 filings appear from 2015-16); post = 2016-2021, transition 2014-15 left out of the pooled b.
#         pct = PCT applications by inventor country (OECD; priority year); post = 2015-2021, 2014 transition;
#         2022 shown in the event study only.
# Estimators: PPML (base) and OLS on log(1+y) (equal weights; PPML lets China dominate the field-year effects).
# Inference: (i) SE clustered by field; (ii) permutation: re-estimate with each comparison country as fake treated
#            (Russia dropped) and compare Russia's pooled b with that distribution.
# Output: empirics/results/tables/field_eventstudy.csv, field_pooled.csv, field_permutation.csv; figures fig6-fig8.
source(here::here("empirics", "scripts", "00_setup.R"))

dep <- read_csv(here("data", "clean", "field_dependence.csv"), show_col_types = FALSE)
load_panel <- function(file) read_csv(here("data", "clean", file), show_col_types = FALSE) %>%
  left_join(dep %>% select(field, dep_frontier_z, field_en), by = "field") %>%
  mutate(cf = paste(iso3, field), ky = paste(field, year), cy = paste(iso3, year))
PANELS <- list(
  domestic = list(data = load_panel("field_panel_domestic.csv"), years = 2005:2021, post = 2016:2021,
                  trans = 2014:2015, label = "Residents' publications at own office (WIPO, publication year)"),
  pct      = list(data = load_panel("field_panel_pct.csv"), years = 2005:2022, post = 2015:2021,
                  trans = 2014, label = "PCT applications by inventor country (OECD, priority year)"))

fit_model <- function(d, treated, estimator, pooled, panel) {
  d <- d %>% mutate(td = (iso3 == treated) * dep_frontier_z, lny = log1p(count))
  if (pooled) {
    d <- d %>% filter(!year %in% panel$trans) %>% mutate(tdp = td * (year %in% panel$post))
    f_p <- count ~ tdp | cy + ky + cf
    f_o <- lny ~ tdp | cy + ky + cf
  } else {
    f_p <- count ~ i(year, td, ref = 2013) | cy + ky + cf
    f_o <- lny ~ i(year, td, ref = 2013) | cy + ky + cf
  }
  if (estimator == "ppml") fepois(f_p, d, cluster = ~field) else feols(f_o, d, cluster = ~field)
}

es_rows <- list(); pooled_rows <- list(); perm_rows <- list()
for (pn in names(PANELS)) {
  panel <- PANELS[[pn]]
  d <- panel$data %>% filter(year %in% panel$years)
  for (est in c("ppml", "ols")) for (smp in c("all", "no_chn")) {
    ds <- if (smp == "no_chn") d %>% filter(iso3 != "CHN") else d
    es <- fit_model(ds, "RUS", est, FALSE, panel)
    ct <- as_tibble(coeftable(es), rownames = "term")
    es_rows[[length(es_rows) + 1]] <- ct %>%
      transmute(panel = pn, estimator = est, sample = smp, year = as.integer(str_extract(term, "\\d{4}")),
                estimate = Estimate, se = `Std. Error`) %>%
      bind_rows(tibble(panel = pn, estimator = est, sample = smp, year = 2013L, estimate = 0, se = 0))
    po <- fit_model(ds, "RUS", est, TRUE, panel)
    pooled_rows[[length(pooled_rows) + 1]] <- tibble(panel = pn, estimator = est, sample = smp,
      estimate = coef(po)["tdp"], se = se(po)["tdp"], n_obs = nobs(po), n_countries = n_distinct(ds$iso3))
    # permutation: each comparison country as fake treated, Russia excluded
    if (smp == "all") {
      others <- setdiff(unique(ds$iso3), "RUS")
      perm <- map_dfr(others, function(cc) {
        fit <- tryCatch(fit_model(ds %>% filter(iso3 != "RUS"), cc, est, TRUE, panel), error = function(e) NULL)
        tibble(fake = cc, estimate = if (is.null(fit)) NA_real_ else coef(fit)["tdp"])
      })
      perm_rows[[length(perm_rows) + 1]] <- perm %>% mutate(panel = pn, estimator = est)
    }
  }
}
es <- bind_rows(es_rows) %>% mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se)
pooled <- bind_rows(pooled_rows) %>% mutate(lo = estimate - 1.96 * se, hi = estimate + 1.96 * se)
perm <- bind_rows(perm_rows)
pooled <- pooled %>% left_join(
  perm %>% left_join(pooled %>% filter(sample == "all") %>% select(panel, estimator, rus = estimate),
                     by = c("panel", "estimator")) %>%
    group_by(panel, estimator) %>%
    summarise(perm_n = sum(!is.na(estimate)), perm_rank_abs = sum(abs(estimate) >= abs(first(rus)), na.rm = TRUE) + 1,
              perm_p = perm_rank_abs / (perm_n + 1), .groups = "drop") %>% mutate(sample = "all"),
  by = c("panel", "estimator", "sample"))
write_csv(es, file.path(TAB_DIR, "field_eventstudy.csv"))
write_csv(pooled, file.path(TAB_DIR, "field_pooled.csv"))
write_csv(perm, file.path(TAB_DIR, "field_permutation.csv"))
print(pooled %>% mutate(across(where(is.double), ~ round(.x, 3))), width = 200)

# ---- figures ----------------------------------------------------------------------------------------------
panel_labels <- c(domestic = PANELS$domestic$label, pct = PANELS$pct$label)
est_labels <- c(ppml = "PPML (base)", ols = "OLS on log(1+y), equal weights")
cap <- paste0(
  "Coefficient on Russia x field dependence (z-score) x year, reference 2013. Dependence = share of world PCT ",
  "applications 2008-13 in the field from\nthe 2014 senders (GSDB). Fixed effects: country x year, field x year, ",
  "country x field. 95% CI, SE clustered by field (35). Domestic: publication year (~18 months after filing).")
p6 <- ggplot(es %>% filter(sample == "all") %>%
               mutate(panel = factor(panel_labels[panel], levels = panel_labels),
                      estimator = factor(est_labels[estimator], levels = est_labels)),
             aes(year, estimate)) +
  annotate("rect", xmin = 2013.5, xmax = 2014.5, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.6) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_pointrange(aes(ymin = lo, ymax = hi), size = 0.2, colour = "#0072B2") +
  facet_grid(estimator ~ panel, scales = "free_y", labeller = label_wrap_gen(40)) +
  scale_x_continuous(breaks = seq(2005, 2022, 3)) +
  labs(title = "Russia after 2014: did fields that depend more on sanctioning countries' technology lose more?",
       x = NULL, y = "Response per 1 SD of dependence", caption = cap) +
  theme_paper()
save_figure(p6, "fig6_field_eventstudy", 11, 6.5)

pp <- perm %>% left_join(pooled %>% filter(sample == "all") %>% select(panel, estimator, rus = estimate, perm_p),
                         by = c("panel", "estimator")) %>%
  mutate(panel = factor(panel_labels[panel], levels = panel_labels),
         estimator = factor(est_labels[estimator], levels = est_labels))
p7 <- ggplot(pp, aes(estimate)) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_dotplot(binwidth = diff(range(pp$estimate, na.rm = TRUE)) / 40, fill = "grey60", colour = NA,
               method = "histodot", stackratio = 1.1) +
  geom_vline(aes(xintercept = rus), colour = "#D55E00", linewidth = 0.8) +
  geom_text(data = distinct(pp, panel, estimator, rus, perm_p),
            aes(x = rus, y = 0.95, label = sprintf("Russia\np = %.2f", perm_p)), colour = "#D55E00",
            hjust = -0.1, size = 2.8) +
  facet_grid(estimator ~ panel, scales = "free", labeller = label_wrap_gen(40)) +
  scale_y_continuous(NULL, breaks = NULL) +
  labs(title = "Pooled post-2014 effect for Russia vs the same estimate for each comparison country",
       x = "Pooled coefficient: treated country x dependence x post",
       caption = paste0("Grey dots: one estimate per comparison country treated as if sanctioned in 2014 (Russia ",
                        "excluded). Orange: Russia. p = share of countries with an estimate at least as large in ",
                        "absolute value (incl. Russia).")) +
  theme_paper()
save_figure(p7, "fig7_field_permutation", 11, 6)

# fig8: raw series, Russia's high- vs low-dependence fields (top / bottom third), index 2013 = 100
raw <- bind_rows(lapply(names(PANELS), function(pn) PANELS[[pn]]$data %>% mutate(panel = pn))) %>%
  mutate(tercile = ntile(dep_frontier_z, 3)) %>% filter(tercile != 2) %>%
  mutate(group = ifelse(tercile == 3, "High dependence (top third of fields)", "Low dependence (bottom third)"),
         who = ifelse(iso3 == "RUS", "Russia", "Comparison countries")) %>%
  group_by(panel, who, group, year) %>% summarise(count = sum(count), .groups = "drop") %>%
  group_by(panel, who, group) %>% mutate(index = 100 * count / count[year == 2013]) %>% ungroup() %>%
  filter(year >= 2005, !(panel == "domestic" & year > 2021)) %>%
  mutate(panel = factor(panel_labels[panel], levels = panel_labels))
p8 <- ggplot(raw, aes(year, index, colour = group, linetype = who)) +
  annotate("rect", xmin = 2013.5, xmax = 2014.5, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.6) +
  geom_hline(yintercept = 100, colour = "grey60", linewidth = 0.3) +
  geom_line(linewidth = 0.6) +
  facet_wrap(~ panel, scales = "free_y", labeller = label_wrap_gen(45)) +
  scale_colour_manual(values = c("#D55E00", "#0072B2"), name = NULL) +
  scale_linetype_manual(values = c(Russia = "solid", `Comparison countries` = "dashed"), name = NULL) +
  labs(title = "Filings in high- and low-dependence fields, Russia vs comparison countries",
       x = NULL, y = "Index, 2013 = 100",
       caption = "Comparison countries summed (dominated by China, the US, Japan, Korea). Fields split by thirds of the dependence measure.") +
  theme_paper() + theme(legend.box = "vertical")
save_figure(p8, "fig8_field_raw_series", 11, 4.8)
