# 18e_pretrend_tests.R: pre-trend checks for the continuous-treatment design (session 5). Official IPC, 35 WIPO
# fields, PPML, field + year FE, Ban_f = EU ban coverage end-2023 (industry map), z-scored.
#  (1) joint Wald test that all pre-period event-study coefficients (2015-2020, base 2021) are zero
#  (2) linear pre-trend: Ban_f x (year - 2021), pre-period only (2015-2021)
#  (3) placebo date: pretend treatment started in 2018, estimate Ban_f x Post2018 on 2015-2021 only
#  (4) placebo scatter: log change 2015-17 -> 2019-21 against coverage (fig43, left) next to the real change
#      2019-21 -> 2023-24 (right)
#  (5) dose-bin event study: quartiles of coverage vs the lowest quartile (fig44): parallel trends across doses
# Output: output/tables/pretrend_tests.csv; fig43_placebo_scatter, fig44_dose_bins_es
source(here::here("scripts", "analysis", "00_setup.R"))
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(between(year, 2015, 2025))
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
out <- list()
for (mp in c("industry", "text")) {
  b <- cov %>% filter(map == mp) %>% transmute(field, coverage, ban = as.numeric(scale(coverage)))
  d <- pat %>% inner_join(b, by = "field")
  es <- fepois(n_frac ~ i(year, ban, ref = 2021) | field + year, data = d, cluster = ~field)
  w <- wald(es, keep = "201[5-9]|2020", print = FALSE)
  pre <- filter(d, year <= 2021) %>% mutate(tr = year - 2021, p18 = as.integer(year >= 2018))
  lt <- fepois(n_frac ~ ban:tr | field + year, data = pre, cluster = ~field)
  pl <- fepois(n_frac ~ ban:p18 | field + year, data = pre, cluster = ~field)
  out[[mp]] <- tibble(map = mp,
    test = c("joint Wald, 2015-2020 coefficients = 0", "linear pre-trend per year (2015-2021)",
             "placebo: Ban x Post-2018, 2015-2021 only"),
    stat = c(w$stat, coef(lt)[[1]], coef(pl)[[1]]),
    se = c(NA, se(lt)[[1]], se(pl)[[1]]),
    p = c(w$p, pvalue(lt)[[1]], pvalue(pl)[[1]]))
}
res <- bind_rows(out)
write_csv(res, file.path(TAB_DIR, "pretrend_tests.csv"))
print(res %>% mutate(across(where(is.double), ~ round(., 4))), width = Inf)

# (4) placebo scatter
b <- cov %>% filter(map == "industry") %>% select(field, coverage)
ch <- pat %>% group_by(field) %>% summarise(
  a = mean(n_frac[year %in% 2015:2017]), p = mean(n_frac[year %in% 2019:2021]), q = mean(n_frac[year %in% 2023:2024]),
  .groups = "drop") %>% inner_join(b, by = "field") %>%
  transmute(field, coverage, w = p, `Placebo: 2015-17 to 2019-21 (before the bans)` = log(p / a),
            `Actual: 2019-21 to 2023-24 (after the bans)` = log(q / p)) %>%
  pivot_longer(-c(field, coverage, w), names_to = "panel", values_to = "dlog") %>%
  mutate(panel = factor(panel, c("Placebo: 2015-17 to 2019-21 (before the bans)", "Actual: 2019-21 to 2023-24 (after the bans)")))
slopes <- ch %>% group_by(panel) %>% group_modify(~ {
  m <- lm(dlog ~ coverage, data = .x, weights = w)
  tibble(slope_sd = coef(m)[[2]] * sd(b$coverage), se_sd = summary(m)$coef[2, 2] * sd(b$coverage),
         p = summary(m)$coef[2, 4])
})
print(slopes)
lab <- slopes %>% mutate(txt = sprintf("slope per SD = %.3f (SE %.3f)", slope_sd, se_sd))
p1 <- ggplot(ch, aes(coverage, dlog)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_smooth(method = "lm", aes(weight = w), colour = "#D55E00", fill = "#D55E00", alpha = 0.15) +
  geom_point(aes(size = w), colour = "#0072B2", alpha = 0.7) +
  geom_text(data = lab, aes(x = 0.1, y = 0.55, label = txt), hjust = 0, size = 3.3, inherit.aes = FALSE) +
  facet_wrap(~panel) + scale_size_area(max_size = 8, guide = "none") +
  scale_x_continuous(labels = scales::percent) + coord_cartesian(ylim = c(-0.7, 0.6)) +
  labs(x = "Share of the field's 2019-21 Western imports banned by the EU (end 2023)", y = "Change in domestic patents, log",
       caption = "One point per WIPO field; size = patents per year 2019-21; size-weighted OLS fit. Official IPC codes.") +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig43_placebo_scatter.pdf"), p1, width = 10, height = 4.8)
ggsave(file.path(FIG_DIR, "fig43_placebo_scatter.png"), p1, width = 10, height = 4.8, dpi = 150)

# (5) dose bins: quartiles vs lowest quartile
q <- b %>% mutate(bin = cut(coverage, quantile(coverage, 0:4 / 4), include.lowest = TRUE,
                            labels = c("Q1 (lowest)", "Q2", "Q3", "Q4 (highest)")))
print(q %>% group_by(bin) %>% summarise(n = n(), lo = min(coverage), hi = max(coverage)))
dq <- pat %>% inner_join(q, by = "field") %>% mutate(bin = relevel(bin, "Q1 (lowest)"))
mq <- fepois(n_frac ~ i(year, bin, ref = 2021, ref2 = "Q1 (lowest)") | field + year, data = dq, cluster = ~field)
eq <- broom::tidy(mq, conf.int = TRUE) %>%
  mutate(year = as.integer(str_extract(term, "\\d{4}")), bin = str_extract(term, "Q[234][^:]*$")) %>%
  bind_rows(expand_grid(year = 2021L, bin = c("Q2", "Q3", "Q4 (highest)")) %>% mutate(estimate = 0, conf.low = 0, conf.high = 0))
print(eq %>% select(bin, year, estimate, conf.low, conf.high) %>% arrange(bin, year) %>% mutate(across(where(is.double), ~ round(., 3))), n = Inf)
p2 <- ggplot(eq, aes(year, estimate, colour = bin)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.25) +
  scale_x_continuous(breaks = 2015:2025) + scale_colour_manual(values = c("grey60", "#E69F00", "#D55E00")) +
  labs(x = "Filing year", y = "Relative to the lowest-coverage quarter\n(PPML, log points)", colour = "Quarter of fields by ban coverage",
       caption = "9 fields per quarter (8 in one); field + year FE; base 2021; 95% CIs clustered by field. Official IPC.") +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig44_dose_bins_es.pdf"), p2, width = 9, height = 4.8)
ggsave(file.path(FIG_DIR, "fig44_dose_bins_es.png"), p2, width = 9, height = 4.8, dpi = 150)
