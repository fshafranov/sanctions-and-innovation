# 16e_patents_sector_fe.R: EXPLORATORY (not pre-registered; next step 1 in AI_CONTEXT, session 5).
# Main test with WIPO sector x year FE instead of year FE, so fields are compared only within their broad sector
# (Schmoch 2008: electrical engineering 1-8, instruments 9-13, chemistry 14-24, mechanical engineering 25-32,
# other 33-35). Aim: remove the machinery -> life-science drift behind the pre-trend in the main event study.
#   P_ft = exp(beta * Ban_f * Post_t + field FE + sector x year FE), PPML, 35 fields x 2015-2025.
# Randomization inference permutes Ban_f WITHIN sector (the comparison the FE leave).
# Output: output/tables/patents_sector_fe.csv, patents_sector_fe_es.csv; fig34_patents_sector_fe_es
source(here::here("scripts", "analysis", "00_setup.R"))
set.seed(20261118)

pat <- read_csv(here("data", "clean", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
sector_of <- function(f) cut(f, c(0, 8, 13, 24, 32, 35),
                             labels = c("Electrical", "Instruments", "Chemistry", "Mechanical", "Other"))

panel <- function(mp, years = 2015:2025) {
  pat %>% filter(year %in% years) %>% select(field, year, y = n_top) %>%
    inner_join(cov %>% filter(map == mp) %>% transmute(field, ban = as.numeric(scale(coverage))), by = "field") %>%
    mutate(post = as.integer(year >= 2022), sector = sector_of(field))
}
fit <- function(d, fe) {
  f <- as.formula(paste("y ~ ban:post |", fe))
  m <- fepois(f, data = d, cluster = ~field)
  tibble(beta = coef(m)[["ban:post"]], se = se(m)[["ban:post"]], n = nobs(m))
}
ri_within <- function(d, R = 2000) {
  b0 <- fit(d, "field + sector^year")$beta
  f <- distinct(d, field, sector, ban)
  perm <- replicate(R, {
    s <- f %>% group_by(sector) %>% mutate(ban = sample(ban)) %>% ungroup() %>% select(field, ban)
    coef(fepois(y ~ ban:post | field + sector^year, data = select(d, -ban) %>% inner_join(s, by = "field")))[[1]]
  })
  mean(abs(perm) >= abs(b0))
}

res <- map_dfr(c("industry", "text"), function(mp) {
  d <- panel(mp)
  dw <- panel(mp, 2019:2025)
  bind_rows(
    fit(d, "field + year") %>% mutate(spec = "year FE (pre-registered main)"),
    fit(d, "field + sector^year") %>% mutate(spec = "sector x year FE", p_ri = ri_within(d)),
    fit(dw, "field + sector^year") %>% mutate(spec = "sector x year FE, 2019-2025"),
    fit(d, "field[year] + sector^year") %>% mutate(spec = "sector x year FE + field trends")
  ) %>% mutate(map = mp)
}) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
write_csv(res, file.path(TAB_DIR, "patents_sector_fe.csv"))
print(res %>% mutate(across(c(beta, se, lo, hi), ~ round(., 3))), width = Inf)

es <- map_dfr(c("industry", "text"), function(mp) map_dfr(c("year", "sector^year"), function(fe) {
  m <- fepois(as.formula(paste("y ~ i(year, ban, ref = 2021) | field +", fe)), data = panel(mp), cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
    bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0)) %>%
    mutate(map = mp, fe = fe)
}))
write_csv(es, file.path(TAB_DIR, "patents_sector_fe_es.csv"))
print(es %>% select(map, fe, year, estimate, conf.low, conf.high) %>% arrange(map, fe, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)

p <- es %>% mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map"),
                   fe = recode(fe, year = "Field + year FE (main)", `sector^year` = "Field + sector x year FE")) %>%
  ggplot(aes(year, estimate, colour = fe)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.25) +
  facet_wrap(~map) +
  scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (SD), log points", colour = NULL,
       caption = paste("Domestic invention patents by WIPO field (35), base 2021, 95% CIs clustered by field.",
                       "Sector = WIPO's 5 sectors. 2025 filings incomplete.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig34_patents_sector_fe_es.pdf"), p, width = 9, height = 5)
ggsave(file.path(FIG_DIR, "fig34_patents_sector_fe_es.png"), p, width = 9, height = 5, dpi = 150)
