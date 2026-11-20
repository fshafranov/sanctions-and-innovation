# 18t_filings_by_origin.R: does the ban-coverage result hold on FILINGS (published applications + fast grants,
# script 23b) instead of grants, and how do foreign filers respond? (20 Nov 2026; question: is the 9% driven by
# non-residents? The main panel is domestic only; this script puts the two origins side by side on a sample with
# a much shorter lag than grants.)
# (1) Benchmark: yearly filings by origin vs WIPO/World Bank resident / non-resident applications (panel.csv).
# (2) Main spec of note 11 by origin: PPML, field + year FE, Ban_f (industry map, end-2023, z-scored), 2015-2024,
#     clustered by field; domestic, foreign, all; event studies base 2020 (NOT 2021: foreign PCT filings dated 2021
#     are missing, their 30-month entry fell in 2022-23 when Western applicants stopped entering Russia; note 16),
#     and the pooled estimate also with 2021 dropped.
#     Also domestic grants (main panel) on the same years, for comparison; and foreign excluding PCT entries.
# 2025 is dropped: applications are published 18 months after priority, so 2025 filings are mostly unpublished.
# Output: output/tables/filings_origin.csv, filings_origin_es.csv, filings_benchmark.csv; fig60_filings_origin
source(here::here("empirics", "scripts", "00_setup.R"))
YEARS <- 2015:2024

tot <- read_csv(here("data", "clean", "ru_filings_year_totals.csv"), show_col_types = FALSE)
wb <- read_panel() %>% filter(iso3 == "RUS", year %in% 2012:2024) %>% select(year, pat_res, pat_nres)
bench <- tot %>% group_by(year, origin) %>% summarise(n = sum(n), n_pct = sum(n[pct]), .groups = "drop") %>%
  pivot_wider(names_from = origin, values_from = c(n, n_pct)) %>% inner_join(wb, by = "year") %>%
  mutate(ratio_dom = n_domestic / pat_res, ratio_for = n_foreign / pat_nres)
write_csv(bench, file.path(TAB_DIR, "filings_benchmark.csv"))
print(bench %>% mutate(across(starts_with("ratio"), ~ round(., 2))), width = 200)

fp <- read_csv(here("data", "clean", "ru_filings_field_year_origin.csv"), show_col_types = FALSE)
gp <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  transmute(field, year, y = n_frac)
fban <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023, map == "industry") %>%
  transmute(field, ban = as.numeric(scale(coverage)))

mk <- function(dd) dd %>% group_by(field, year) %>% summarise(y = sum(y), .groups = "drop") %>%
  complete(field = 1:35, year = YEARS, fill = list(y = 0)) %>% filter(year %in% YEARS) %>%
  inner_join(fban, by = "field") %>% mutate(post = as.integer(year >= 2022))
f <- fp %>% rename(y = n_frac)
samples <- list(
  "Domestic filings" = mk(filter(f, origin == "domestic")),
  "Foreign filings" = mk(filter(f, origin == "foreign")),
  "All filings" = mk(f),
  "Domestic grants (main panel)" = mk(gp)
)

res <- imap_dfr(samples, function(d, nm) {
  m <- fepois(y ~ ban:post | field + year, data = d, cluster = ~field)
  m2 <- fepois(y ~ ban:post | field + year, data = filter(d, year != 2021), cluster = ~field)
  tibble(sample = nm, spec = c("2015-2024", "2015-2024 without 2021"), beta = c(coef(m)[[1]], coef(m2)[[1]]),
         se = c(se(m)[[1]], se(m2)[[1]]), n_2020 = sum(d$y[d$year == 2020]), n_2023 = sum(d$y[d$year == 2023]))
}) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
es <- imap_dfr(samples, function(d, nm) {
  m <- fepois(y ~ i(year, ban, ref = 2020) | field + year, data = d, cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}")), sample = nm) %>%
    select(sample, year, estimate, conf.low, conf.high) %>%
    bind_rows(tibble(sample = nm, year = 2020L, estimate = 0, conf.low = 0, conf.high = 0))
})
write_csv(res, file.path(TAB_DIR, "filings_origin.csv"))
write_csv(es, file.path(TAB_DIR, "filings_origin_es.csv"))
print(res %>% mutate(across(where(is.double), ~ round(., 3))))
print(es %>% filter(year >= 2018) %>% mutate(across(where(is.double), ~ round(., 3))) %>%
        select(sample, year, estimate) %>% pivot_wider(names_from = year, values_from = estimate))

p <- ggplot(es, aes(year, estimate)) +
  geom_hline(yintercept = 0, colour = "grey50") + geom_vline(xintercept = 2021.5, linetype = 2, colour = "grey50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2, fill = "#0072B2") +
  geom_line(colour = "#0072B2") + geom_point(colour = "#0072B2", size = 1.4) +
  facet_wrap(~ factor(sample, names(samples)), nrow = 1, scales = "free_y") +
  labs(x = NULL, y = "Effect of 1 SD ban coverage (log points)",
       caption = paste("PPML, field + year FE, 35 WIPO fields, 2015-2024, base 2020, 95% CI clustered by field.",
                       "Filings = published applications + fast grants by filing year (script 23b);",
                       "PCT entries dated by international filing date.")) +
  theme_paper()
save_figure(p, "fig60_filings_origin", width = 12, height = 4)
