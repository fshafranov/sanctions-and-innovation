# 18w_movers_figure.R: Russian inventors who reappear abroad (BigQuery, script 32; note 17). Descriptive.
# Panels: (a) number of pooled RU inventors appearing with a foreign address in year y; (b) as a share of the pool
# (RU address in y-3..y-1); (c) destinations, 2017-2021 vs 2022-2025 (shares of destination mentions).
# 2024-2025 shaded: incomplete (publication lag). Output: empirics/results/tables/movers_bigquery.csv; fig65_movers_bigquery
source(here::here("empirics", "scripts", "00_setup.R"))
library(patchwork)
yr <- read_csv(here("data", "raw", "bigquery", "movers_by_year.csv"), show_col_types = FALSE) %>%
  filter(y >= 2013) %>% mutate(rate = 100 * abroad_n / pool_n)
de <- read_csv(here("data", "raw", "bigquery", "movers_by_destination.csv"), show_col_types = FALSE)
pre <- yr %>% filter(between(y, 2017, 2021))
cat(sprintf("2017-21 mean: %.0f movers/yr, rate %.2f%%; 2022-25 mean: %.0f, %.2f%%\n", mean(pre$abroad_n), mean(pre$rate),
            mean(yr$abroad_n[yr$y >= 2022]), mean(yr$rate[yr$y >= 2022])))
write_csv(yr, file.path(TAB_DIR, "movers_bigquery.csv"))

shade <- annotate("rect", xmin = 2023.5, xmax = 2025.5, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.6)
base <- function(var, lab, pm) ggplot(yr, aes(y, .data[[var]])) + shade +
  geom_vline(xintercept = 2021.5, linetype = 2, colour = "grey50") +
  annotate("segment", x = 2016.6, xend = 2021.4, y = pm, yend = pm, colour = "grey40", linetype = 3) +
  geom_line(colour = "#0072B2") + geom_point(colour = "#0072B2", size = 1.6) +
  scale_x_continuous(breaks = seq(2013, 2025, 2)) + expand_limits(y = 0) +
  labs(x = NULL, y = lab) + theme_paper()
pa <- base("abroad_n", "Inventors appearing abroad", mean(pre$abroad_n)) + ggtitle("(a) Count")
pb <- base("rate", "% of pool (RU address in prior 3 years)", mean(pre$rate)) + ggtitle("(b) Rate")
top <- de %>% filter(y >= 2017) %>% mutate(per = if_else(y >= 2022, "2022-2025", "2017-2021")) %>%
  group_by(per, cc) %>% summarise(n = sum(n), .groups = "drop") %>% group_by(per) %>% mutate(s = 100 * n / sum(n)) %>%
  ungroup()
keep <- top %>% group_by(cc) %>% summarise(m = max(s)) %>% slice_max(m, n = 12) %>% pull(cc)
pc <- top %>% filter(cc %in% keep) %>% mutate(cc = fct_reorder(cc, s, max)) %>%
  ggplot(aes(s, cc, fill = per)) + geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_fill_manual(values = c("2017-2021" = "grey60", "2022-2025" = "#D55E00")) +
  labs(x = "% of destination mentions", y = NULL, fill = NULL) + ggtitle("(c) Destinations") + theme_paper()
p <- (pa | pb | pc) + plot_annotation(
  caption = paste("Google Patents (BigQuery), all offices except Rospatent, filing year. Pool = harmonised inventor names with a",
                  "Russian address in the prior three years; abroad = same name with a foreign address in year y.\nNames not",
                  "disambiguated (levels are upper bounds). Grey: incomplete years (publication lag). Dotted: 2017-21 mean.",
                  "Dashed: 2022."),
  theme = theme(plot.caption = element_text(hjust = 0, size = 7.5, colour = "grey30")))
save_figure(p, "fig65_movers_bigquery", width = 13, height = 4.4)
