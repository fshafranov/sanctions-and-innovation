# 18h_summary_figure.R: one-page summary of the main result for the advisor meeting (session 5).
# Official Rospatent IPC codes for all years, 35 WIPO fields, EU ban coverage end-2023 (industry map).
#  A: raw patents, highest vs lowest coverage quarter of fields, 2019-21 = 100 (no regression)
#  B: continuous-treatment event study, PPML, field + year FE, base 2021, per SD of coverage, 95% CIs by field
#  C: leave-one-field-out estimates of the pooled coefficient (35 re-estimates), with the full-sample estimate
# Output: fig48_summary
source(here::here("scripts", "analysis", "00_setup.R"))
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(between(year, 2010, 2025))
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023, map == "industry") %>% select(field, coverage) %>%
  mutate(ban = as.numeric(scale(coverage)),
         q = cut(coverage, quantile(coverage, 0:4 / 4), include.lowest = TRUE, labels = c("Q1", "Q2", "Q3", "Q4")))

# A: raw lines
g <- pat %>% inner_join(cov, by = "field") %>% filter(q %in% c("Q1", "Q4")) %>%
  group_by(q, year) %>% summarise(n = sum(n_frac), .groups = "drop") %>%
  group_by(q) %>% mutate(idx = 100 * n / mean(n[year %in% 2019:2021])) %>% ungroup() %>%
  mutate(q = recode(q, Q1 = "Least banned quarter of fields (coverage 8-43%)",
                    Q4 = "Most banned quarter of fields (coverage 59-67%)"))
pA <- ggplot(g, aes(year, idx, colour = q)) +
  annotate("rect", xmin = 2018.5, xmax = 2021.5, ymin = -Inf, ymax = Inf, alpha = 0.08) +
  geom_hline(yintercept = 100, colour = "grey60") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_line(linewidth = 0.9) + geom_point(size = 1.3) +
  scale_colour_manual(values = c("#009E73", "#D55E00")) + scale_x_continuous(breaks = seq(2010, 2025, 3)) +
  guides(colour = guide_legend(ncol = 1)) +
  labs(title = "A. Raw patent counts (2019-21 = 100)", x = NULL, y = "Index", colour = NULL) +
  theme_paper() + theme(legend.position = "bottom")

# B: event study
d <- pat %>% filter(year >= 2015) %>% inner_join(cov, by = "field")
es <- fepois(n_frac ~ i(year, ban, ref = 2021) | field + year, data = d, cluster = ~field)
pooled <- fepois(n_frac ~ ban:post | field + year, data = mutate(d, post = as.integer(year >= 2022)), cluster = ~field)
e <- broom::tidy(es, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
  bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0))
pB <- ggplot(e, aes(year, estimate)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), colour = "#0072B2", size = 0.3) +
  annotate("text", x = 2015, y = -0.13, hjust = 0, size = 3.2,
           label = sprintf("Pooled post-2022: %.3f (SE %.3f)", coef(pooled)[[1]], se(pooled)[[1]])) +
  scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  labs(title = "B. Event study, per SD of ban coverage", x = NULL, y = "PPML coefficient (log points)") +
  theme_paper()

# C: leave one out
loo <- map_dfr(sort(unique(cov$field)), function(f) {
  b <- cov %>% filter(field != f) %>% mutate(ban = as.numeric(scale(coverage)))
  m <- fepois(n_frac ~ ban:post | field + year, cluster = ~field,
              data = pat %>% filter(year >= 2015) %>% inner_join(select(b, field, ban), by = "field") %>%
                mutate(post = as.integer(year >= 2022)))
  tibble(field = f, beta = coef(m)[[1]], se = se(m)[[1]])
}) %>% arrange(beta) %>% mutate(rank = row_number())
pC <- ggplot(loo, aes(rank, beta)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_hline(yintercept = coef(pooled)[[1]], linetype = "dashed", colour = "#D55E00") +
  geom_pointrange(aes(ymin = beta - 1.96 * se, ymax = beta + 1.96 * se), colour = "#0072B2", size = 0.15) +
  labs(title = "C. Dropping one field at a time", x = "35 re-estimates, sorted", y = "Pooled coefficient") +
  theme_paper()

p <- patchwork::wrap_plots(pA, pB, pC, nrow = 1, widths = c(1.2, 1, 0.8)) +
  patchwork::plot_annotation(caption = paste0(
    "Russian domestic invention patents (Rospatent, official IPC), fractional WIPO field counts, by filing year; 2025 incomplete.\n",
    "Ban coverage: share of a field's 2019-21 Western imports banned by the EU by end 2023. Field + year FE, SEs clustered by field (35)."))
ggsave(file.path(FIG_DIR, "fig48_summary.pdf"), p, width = 14, height = 5)
ggsave(file.path(FIG_DIR, "fig48_summary.png"), p, width = 14, height = 5, dpi = 150)
cat("pooled", coef(pooled), se(pooled), "; LOO range", range(loo$beta), "\n")
