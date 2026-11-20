# 17_patents_subclass.R: EXPLORATORY (session 5; note 13). The main test at the IPC subclass level.
#   P_st = exp(beta * Ban_s * Post_t + subclass FE + [year | WIPO field x year] FE), PPML, 2015-2025.
# Sample rule (fixed before estimation): subclasses with >= 10 domestic patents per year on average in 2015-2021
# and with a coverage value. Ban_s = EU ban coverage end-2023 (z-scored over the sample), industry map (main) and
# product-name map. Field x year FE compare subclasses within the same WIPO field, which removes the cross-field
# drift (life sciences vs machinery) behind the field-level pre-trend.
# SEs clustered by subclass; conservative variant clustered by WIPO field (35). Randomization inference permutes
# Ban_s across subclasses within field (1,000 draws).
# Output: empirics/results/tables/patents_subclass.csv, patents_subclass_es.csv, patents_subclass_holder.csv;
#         fig37_patents_subclass_es. Holder counts: data/processed/title_subclasses/ru_domestic_subclass_holder_year.csv (from 14b output)
source(here::here("empirics", "scripts", "00_setup.R"))
set.seed(20261118)
YEARS <- 2015:2025

pat <- read_csv(here("data", "processed", "title_subclasses", "ru_domestic_subclass_year.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS)
cov <- read_csv(here("data", "processed", "subclass_ban_coverage", "subclass_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(year == 2023) %>% select(map, subclass, field, coverage, coverage_noex)
size <- pat %>% filter(year <= 2021) %>% group_by(subclass) %>% summarise(avg = mean(n_top))
keep <- size %>% filter(avg >= 10) %>% pull(subclass)

panel <- function(mp, var = "coverage", data = pat, y = "n_top") {
  b <- cov %>% filter(map == mp, subclass %in% keep, !is.na(field)) %>%
    mutate(ban = as.numeric(scale(.data[[var]])), sector = cut(field, c(0, 8, 13, 24, 32, 35),
                                                               labels = c("El", "In", "Ch", "Me", "Ot")))
  data %>% filter(subclass %in% b$subclass) %>% rename(y = all_of(y)) %>% inner_join(b, by = "subclass") %>%
    mutate(post = as.integer(year >= 2022))
}
cat("subclasses kept:", length(keep), "\n")

fit <- function(d, fe) {
  m <- fepois(as.formula(paste("y ~ ban:post | subclass +", fe)), data = d)
  tibble(beta = coef(m)[[1]], se_sub = se(m, cluster = ~subclass)[[1]], se_field = se(m, cluster = ~field)[[1]],
         n = nobs(m), n_sub = n_distinct(d$subclass))
}
ri <- function(d, R = 1000) {
  b0 <- coef(fepois(y ~ ban:post | subclass + field^year, data = d))[[1]]
  f <- distinct(d, subclass, field, ban)
  perm <- replicate(R, {
    s <- f %>% group_by(field) %>% mutate(ban = sample(ban)) %>% ungroup() %>% select(subclass, ban)
    coef(fepois(y ~ ban:post | subclass + field^year, data = select(d, -ban) %>% inner_join(s, by = "subclass")))[[1]]
  })
  mean(abs(perm) >= abs(b0))
}

res <- map_dfr(c("industry", "text"), function(mp) {
  d <- panel(mp)
  bind_rows(
    fit(d, "year") %>% mutate(spec = "subclass + year FE"),
    fit(d, "sector^year") %>% mutate(spec = "subclass + sector x year FE"),
    fit(d, "field^year") %>% mutate(spec = "subclass + field x year FE (main)", p_ri = ri(d)),
    fit(filter(d, year >= 2019), "field^year") %>% mutate(spec = "field x year FE, 2019-2025"),
    fit(panel(mp, "coverage_noex"), "field^year") %>% mutate(spec = "field x year FE, coverage without ex")
  ) %>% mutate(map = mp)
}) %>% mutate(lo = beta - 1.96 * se_sub, hi = beta + 1.96 * se_sub,
              lo_field = beta - 1.96 * se_field, hi_field = beta + 1.96 * se_field)
write_csv(res, file.path(TAB_DIR, "patents_subclass.csv"))
print(res %>% select(map, spec, beta, lo, hi, lo_field, hi_field, p_ri, n_sub) %>%
        mutate(across(where(is.double), ~ round(., 3))), width = Inf)

es <- map_dfr(c("industry", "text"), function(mp) map_dfr(c("year", "field^year"), function(fe) {
  m <- fepois(as.formula(paste("y ~ i(year, ban, ref = 2021) | subclass +", fe)), data = panel(mp),
              cluster = ~subclass)
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
    bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0)) %>% mutate(map = mp, fe = fe)
}))
write_csv(es, file.path(TAB_DIR, "patents_subclass_es.csv"))
print(es %>% select(map, fe, year, estimate, conf.low, conf.high) %>% arrange(map, fe, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)
p <- es %>% mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map"),
                   fe = recode(fe, year = "Subclass + year FE", `field^year` = "Subclass + WIPO field x year FE")) %>%
  ggplot(aes(year, estimate, colour = fe)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.25) +
  facet_wrap(~map) + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (SD)", colour = NULL,
       caption = paste0("Domestic invention patents by IPC subclass (", length(keep),
                        " subclasses with >= 10 patents/yr), base 2021, 95% CIs clustered by subclass.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig37_patents_subclass_es.pdf"), p, width = 9, height = 5)
ggsave(file.path(FIG_DIR, "fig37_patents_subclass_es.png"), p, width = 9, height = 5, dpi = 150)

# holder types at subclass level (field x year FE within holder)
pt <- read_csv(here("data", "processed", "title_subclasses", "ru_domestic_subclass_holder_year.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS, h %in% c("firm", "university", "research", "individual")) %>%
  complete(subclass, year = YEARS, h, fill = list(n = 0))
hres <- map_dfr(c("industry", "text"), function(mp) {
  d <- panel(mp, data = pt, y = "n")
  m <- fepois(y ~ ban:post:i(h) | subclass^h + field^year^h, data = d, cluster = ~subclass)
  broom::tidy(m, conf.int = TRUE) %>% mutate(map = mp, h = str_extract(term, "(firm|university|research|individual)"))
})
write_csv(hres, file.path(TAB_DIR, "patents_subclass_holder.csv"))
print(hres %>% select(map, h, estimate, conf.low, conf.high) %>% mutate(across(where(is.double), ~ round(., 3))))
