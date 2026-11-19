# 18d_pitch_figures.R: two figures that explain the continuous-treatment event study (fig38, left) (session 5).
# (1) fig41: the cross-field comparison behind the DiD: log change in domestic patents, 2019-21 -> 2023-24 (official
#     IPC, fractional), against EU ban coverage (end-2023, industry map), one point per WIPO field, size = 2019-21
#     patents, with the size-weighted fit (the slope is the simple pre/post DiD in log points per unit coverage).
# (2) fig42: binary version: top third vs bottom third of fields by coverage (middle third dropped), PPML event study
#     with field + year FE, base 2021: an explicit treated group and control group.
source(here::here("scripts", "analysis", "00_setup.R"))
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE)
names_f <- read_csv(here("data", "clean", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE) %>%
  distinct(field, field_en)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023, map == "industry") %>% select(field, coverage)

ch <- pat %>% group_by(field) %>%
  summarise(pre = mean(n_frac[year %in% 2019:2021]), post = mean(n_frac[year %in% 2023:2024]), .groups = "drop") %>%
  mutate(dlog = log(post / pre)) %>% inner_join(cov, by = "field") %>% inner_join(names_f, by = "field")
fit <- lm(dlog ~ coverage, data = ch, weights = pre)
cat("weighted slope per 1.0 coverage:", round(coef(fit)[2], 3), "; per SD (", round(sd(ch$coverage), 3), "):",
    round(coef(fit)[2] * sd(ch$coverage), 3), "\n")
print(ch %>% arrange(coverage) %>% transmute(field_en, coverage = round(coverage, 2), pre = round(pre),
                                             post = round(post), dlog = round(dlog, 2)), n = Inf)
short <- c("Pharmaceuticals", "Medical technology", "Biotechnology", "Telecommunications", "Digital communication",
           "Semiconductors", "Computer technology", "Engines, pumps, turbines", "Transport", "Machine tools",
           "Food chemistry", "Analysis of biological materials", "Civil engineering", "Materials, metallurgy")
p1 <- ggplot(ch, aes(coverage, dlog)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_smooth(method = "lm", mapping = aes(weight = pre), colour = "#D55E00", fill = "#D55E00", alpha = 0.15) +
  geom_point(aes(size = pre), colour = "#0072B2", alpha = 0.7) +
  ggrepel::geom_text_repel(data = filter(ch, field_en %in% short), aes(label = field_en), size = 3, colour = "grey25",
                           max.overlaps = 20, seed = 1) +
  scale_size_area(max_size = 9, guide = "none") +
  scale_x_continuous(labels = scales::percent) +
  labs(x = "Share of the field's 2019-21 Western imports banned by the EU (end 2023)",
       y = "Change in domestic patents, log\n(2023-24 vs 2019-21)",
       caption = "One point per WIPO technology field; size = patents per year 2019-21; line = size-weighted OLS fit. Official IPC codes.") +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig41_change_vs_coverage.pdf"), p1, width = 8, height = 5.5)
ggsave(file.path(FIG_DIR, "fig41_change_vs_coverage.png"), p1, width = 8, height = 5.5, dpi = 150)

terc <- cov %>% mutate(g = cut(coverage, quantile(coverage, c(0, 1/3, 2/3, 1)), include.lowest = TRUE,
                              labels = c("bottom", "middle", "top")))
cat("bottom-third coverage range:", range(terc$coverage[terc$g == "bottom"]), "; top-third:",
    range(terc$coverage[terc$g == "top"]), "\n")
d <- pat %>% filter(between(year, 2015, 2025)) %>% inner_join(terc, by = "field") %>% filter(g != "middle") %>%
  mutate(top = as.integer(g == "top"), post = as.integer(year >= 2022))
m0 <- fepois(n_frac ~ top:post | field + year, data = d, cluster = ~field)
cat("pooled top vs bottom third:", round(coef(m0), 3), "SE", round(se(m0), 3), "\n")
m <- fepois(n_frac ~ i(year, top, ref = 2021) | field + year, data = d, cluster = ~field)
es <- broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
  bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0))
print(es %>% select(year, estimate, conf.low, conf.high) %>% arrange(year) %>% mutate(across(-year, ~ round(., 3))))
p2 <- ggplot(es, aes(year, estimate)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), colour = "#0072B2") +
  scale_x_continuous(breaks = 2015:2025) +
  labs(x = "Filing year", y = "Most-banned vs least-banned third of fields\n(PPML, log points)",
       caption = paste0("Treated: 12 fields with the highest ban coverage; control: 12 with the lowest. Field + year FE, base 2021, ",
                        "95% CIs clustered by field. Official IPC.")) +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig42_top_vs_bottom_third_es.pdf"), p2, width = 8, height = 4.5)
ggsave(file.path(FIG_DIR, "fig42_top_vs_bottom_third_es.png"), p2, width = 8, height = 4.5, dpi = 150)
