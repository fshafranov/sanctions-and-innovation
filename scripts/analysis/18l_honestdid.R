# 18l_honestdid.R: sensitivity of the main event study to pre-trend violations (Rambachan & Roth 2023, REStud;
# R package HonestDiD 0.2.8, CRAN). Session 5.
# Event study: PPML, 35 WIPO fields, field + year FE, Ban_f z-scored (end-2023 EU coverage), base 2021, SEs clustered by
# field; official IPC, 2015-2025. 6 pre-periods (2015-2020), 4 post-periods (2022-2025).
# Targets: (a) average post effect 2022-25; (b) the 2023 effect.
# Restrictions:
#   relative magnitudes (DeltaRM, Mbar): post-period violations of parallel trends at most Mbar times the largest
#     year-to-year change in the pre-period
#   smoothness (DeltaSD, M): the trend may change slope by at most M per year (M = 0: linear extrapolation of the
#     pre-trend)
# Breakdown value: the largest Mbar (or M) at which the robust 95% CI still excludes 0.
# Output: output/tables/honestdid.csv, honestdid_breakdown.csv; fig53_honestdid
source(here::here("scripts", "analysis", "00_setup.R"))
library(HonestDiD)
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(between(year, 2015, 2025))
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
MBAR <- seq(0, 2, by = 0.25)
MSD <- seq(0, 0.03, by = 0.005)
targets <- list("average 2022-25" = rep(0.25, 4), "2023" = c(0, 1, 0, 0))

out <- list()
for (mp in c("industry", "text")) {
  b <- cov %>% filter(map == mp) %>% transmute(field, ban = as.numeric(scale(coverage)))
  d <- pat %>% inner_join(b, by = "field")
  m <- fepois(n_frac ~ i(year, ban, ref = 2021) | field + year, data = d, cluster = ~field)
  nm <- names(coef(m))
  ord <- c(grep("201[5-9]|2020", nm), grep("202[2-5]", nm))
  bh <- coef(m)[ord]; S <- vcov(m)[ord, ord]
  stopifnot(length(bh) == 10)
  for (tg in names(targets)) {
    l <- targets[[tg]]
    orig <- constructOriginalCS(betahat = bh, sigma = S, numPrePeriods = 6, numPostPeriods = 4, l_vec = l)
    rm <- createSensitivityResults_relativeMagnitudes(betahat = bh, sigma = S, numPrePeriods = 6, numPostPeriods = 4,
                                                      Mbarvec = MBAR, l_vec = l)
    sd <- createSensitivityResults(betahat = bh, sigma = S, numPrePeriods = 6, numPostPeriods = 4, Mvec = MSD, l_vec = l)
    out[[length(out) + 1]] <- bind_rows(
      tibble(restriction = "original", M = 0, lb = as.numeric(orig$lb), ub = as.numeric(orig$ub)),
      tibble(restriction = "relative magnitudes (Mbar)", M = as.numeric(rm$Mbar), lb = as.numeric(rm$lb), ub = as.numeric(rm$ub)),
      tibble(restriction = "smoothness (M)", M = as.numeric(sd$M), lb = as.numeric(sd$lb), ub = as.numeric(sd$ub))) %>%
      mutate(map = mp, target = tg, point = sum(l * bh[7:10]))
  }
}
res <- bind_rows(out)
write_csv(res, file.path(TAB_DIR, "honestdid.csv"))
print(res %>% mutate(across(c(M, lb, ub, point), ~ round(., 3))) %>% select(map, target, restriction, M, lb, ub, point), n = Inf)

bd <- res %>% filter(restriction != "original") %>% group_by(map, target, restriction) %>% arrange(M) %>%
  summarise(breakdown = { ok <- ub < 0; if (!ok[1]) 0 else max(M[cumprod(ok) == 1]) },
            grid_max = max(M), .groups = "drop")
write_csv(bd, file.path(TAB_DIR, "honestdid_breakdown.csv"))
cat("\nBreakdown values (largest grid value with the robust CI below 0; equal to grid_max = robust over the whole grid):\n")
print(bd)

pd <- res %>% filter(target == "average 2022-25") %>%
  mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map"))
mk <- function(r, xlab, ttl) {
  dd <- bind_rows(pd %>% filter(restriction == r) %>% mutate(kind = "robust"),
                  pd %>% filter(restriction == "original") %>% mutate(kind = "original", M = -diff(range(pd$M[pd$restriction == r])) / 10))
  ggplot(dd, aes(M, ymin = lb, ymax = ub, colour = map, linetype = kind)) +
    geom_hline(yintercept = 0, colour = "grey40") +
    geom_errorbar(width = 0, linewidth = 0.8, position = position_dodge(diff(range(dd$M)) / 25)) +
    scale_linetype_manual(values = c(original = "dotted", robust = "solid"), guide = "none") +
    scale_colour_manual(values = c("#0072B2", "#D55E00")) +
    labs(x = xlab, y = "95% CI, average effect 2022-25", colour = NULL, title = ttl) +
    theme_paper() + theme(legend.position = "top")
}
p <- patchwork::wrap_plots(
  mk("relative magnitudes (Mbar)", "Mbar: post-period violation / largest pre-period year-to-year change",
     "A. Relative magnitudes"),
  mk("smoothness (M)", "M: allowed change in the trend's slope per year (0 = linear pre-trend continues)",
     "B. Smoothness"), nrow = 1) +
  patchwork::plot_annotation(caption = paste("Rambachan & Roth (2023) robust 95% CIs for the average 2022-25 event-study coefficient",
                                             "(PPML, 35 fields, field + year FE, per SD of ban coverage). Leftmost dotted bar: original CI. Official IPC."))
ggsave(file.path(FIG_DIR, "fig53_honestdid.pdf"), p, width = 12, height = 5)
ggsave(file.path(FIG_DIR, "fig53_honestdid.png"), p, width = 12, height = 5, dpi = 150)
