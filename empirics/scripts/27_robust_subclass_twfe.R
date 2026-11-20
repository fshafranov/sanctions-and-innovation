# 18c_subclass_twfe.R: simple TWFE variants at the IPC subclass level with OFFICIAL IPC (session 5; note 14).
# Panel: domestic invention patents by subclass x filing year 2015-2025 (n_frac, script 23), subclasses with
# >= 10 patents/yr on average in 2015-21. Treatment: EU ban coverage end-2023 (industry map main, product-name map).
# Variants (all with subclass FE; time FE = year, or sector x year):
#   outcomes  : PPML on counts; OLS on log(1 + n); OLS on asinh(n)
#   treatment : continuous (z-score); binary above median; top vs bottom tercile (middle dropped)
#   dose      : time-varying coverage at end of each year (0 before 2022), per 10 pp
#   staggered : binary from the first year coverage >= 50% (2022-2026), Sun-Abraham (PPML) and TWFE
# SEs clustered by subclass; field-clustered SEs reported alongside.
# Output: empirics/results/tables/subclass_twfe.csv, subclass_twfe_es.csv; fig40_subclass_twfe_es
source(here::here("empirics", "scripts", "00_setup.R"))
YEARS <- 2015:2025

pat <- read_csv(here("data", "clean", "ru_domestic_subclass_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS) %>% complete(subclass, year = YEARS, fill = list(n_frac = 0, n_first = 0))
keep <- pat %>% filter(year <= 2021) %>% group_by(subclass) %>% summarise(avg = mean(n_frac)) %>%
  filter(avg >= 10) %>% pull(subclass)
covall <- read_csv(here("data", "clean", "subclass_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(subclass %in% keep, !is.na(field))
sector_of <- function(f) cut(f, c(0, 8, 13, 24, 32, 35), labels = c("El", "In", "Ch", "Me", "Ot"))

panel <- function(mp) {
  b <- covall %>% filter(map == mp, year == 2023) %>%
    transmute(subclass, field, cov23 = coverage, ban = as.numeric(scale(coverage)),
              hi = as.integer(coverage > median(coverage)),
              terc = cut(coverage, quantile(coverage, c(0, 1/3, 2/3, 1)), include.lowest = TRUE, labels = c("lo", "mid", "top")))
  dose <- covall %>% filter(map == mp) %>% select(subclass, year, cov_t = coverage)
  first50 <- dose %>% filter(cov_t >= 0.5) %>% group_by(subclass) %>% summarise(g = min(year))
  pat %>% filter(subclass %in% b$subclass) %>% inner_join(b, by = "subclass") %>%
    left_join(dose, by = c("subclass", "year")) %>% left_join(first50, by = "subclass") %>%
    mutate(post = as.integer(year >= 2022), cov_t = if_else(year >= 2022, coalesce(cov_t, 0), 0),
           g = coalesce(g, 10000L), treat_stag = as.integer(year >= g),
           sector = sector_of(field), y = n_frac, ly = log1p(n_frac), ay = asinh(n_frac))
}

one <- function(d, fml, est, label, treat) {
  m <- if (est == "ppml") fepois(fml, data = d) else feols(fml, data = d)
  k <- grep(treat, names(coef(m)), value = TRUE)[1]
  tibble(spec = label, beta = coef(m)[[k]], se_sub = se(m, cluster = ~subclass)[[k]],
         se_field = se(m, cluster = ~field)[[k]], n = nobs(m))
}

res <- map_dfr(c("industry", "text"), function(mp) {
  d <- panel(mp)
  dt <- filter(d, terc != "mid") %>% mutate(top = as.integer(terc == "top"))
  map_dfr(c("year", "sector^year"), function(fe) {
    f <- function(lhs, rhs) as.formula(paste(lhs, "~", rhs, "| subclass +", fe))
    bind_rows(
      one(d, f("y", "ban:post"), "ppml", "PPML, continuous (per SD)", "ban:post"),
      one(d, f("ly", "ban:post"), "ols", "OLS log(1+n), continuous", "ban:post"),
      one(d, f("ay", "ban:post"), "ols", "OLS asinh(n), continuous", "ban:post"),
      one(d, f("y", "hi:post"), "ppml", "PPML, above-median coverage", "hi:post"),
      one(d, f("ly", "hi:post"), "ols", "OLS log(1+n), above-median", "hi:post"),
      one(dt, f("y", "top:post"), "ppml", "PPML, top vs bottom tercile", "top:post"),
      one(d, f("y", "I(10 * cov_t)"), "ppml", "PPML, dose: coverage at end of year (per 10 pp)", "cov_t"),
      one(d, f("y", "treat_stag"), "ppml", "PPML TWFE, staggered (coverage >= 50%)", "treat_stag")
    ) %>% mutate(fe = fe)
  }) %>% mutate(map = mp)
}) %>% mutate(lo = beta - 1.96 * se_sub, hi = beta + 1.96 * se_sub,
              lo_f = beta - 1.96 * se_field, hi_f = beta + 1.96 * se_field)

# Sun-Abraham (staggered, heterogeneity-robust), PPML, never-treated = never reach 50% by 2026
sa <- map_dfr(c("industry", "text"), function(mp) {
  d <- panel(mp)
  cat(mp, "cohorts:", paste(capture.output(print(table(d$g[d$year == 2015]))), collapse = " "), "\n")
  m <- fepois(y ~ sunab(g, year, ref.p = -1) | subclass + year, data = d, cluster = ~subclass)
  a <- summary(m, agg = "ATT")
  tibble(spec = "PPML Sun-Abraham ATT (coverage >= 50%)", fe = "year", map = mp,
         beta = coef(a)[["ATT"]], se_sub = se(a)[["ATT"]], n = nobs(m)) %>%
    mutate(lo = beta - 1.96 * se_sub, hi = beta + 1.96 * se_sub)
})
res <- bind_rows(res, sa)
write_csv(res, file.path(TAB_DIR, "subclass_twfe.csv"))
print(res %>% select(map, fe, spec, beta, lo, hi, lo_f, hi_f) %>% mutate(across(where(is.double), ~ round(., 3))),
      n = Inf, width = Inf)

# event studies: binary above-median (PPML and OLS log), year FE, base 2021
es <- map_dfr(c("industry", "text"), function(mp) {
  d <- panel(mp)
  bind_rows(
    broom::tidy(fepois(y ~ i(year, hi, ref = 2021) | subclass + year, data = d, cluster = ~subclass), conf.int = TRUE) %>%
      mutate(model = "PPML, above-median coverage"),
    broom::tidy(feols(ly ~ i(year, hi, ref = 2021) | subclass + year, data = d, cluster = ~subclass), conf.int = TRUE) %>%
      mutate(model = "OLS log(1+n), above-median coverage"),
    broom::tidy(fepois(y ~ i(year, ban, ref = 2021) | subclass + year, data = d, cluster = ~subclass), conf.int = TRUE) %>%
      mutate(model = "PPML, continuous (per SD)")) %>% mutate(map = mp)
}) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
  bind_rows(expand_grid(map = c("industry", "text"),
                        model = c("PPML, above-median coverage", "OLS log(1+n), above-median coverage", "PPML, continuous (per SD)")) %>%
              mutate(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0))
write_csv(es, file.path(TAB_DIR, "subclass_twfe_es.csv"))
print(es %>% filter(map == "industry") %>% select(model, year, estimate, conf.low, conf.high) %>%
        arrange(model, year) %>% mutate(across(where(is.double), ~ round(., 3))), n = Inf)
p <- es %>% mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map")) %>%
  ggplot(aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.2) +
  facet_wrap(~model, scales = "free_y") + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "Coefficient (log points)", colour = NULL,
       caption = paste0("IPC subclasses (", length(keep), " with >= 10 patents/yr), official IPC, subclass + year FE, base 2021, 95% CIs clustered by subclass.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig40_subclass_twfe_es.pdf"), p, width = 11, height = 4.5)
ggsave(file.path(FIG_DIR, "fig40_subclass_twfe_es.png"), p, width = 11, height = 4.5, dpi = 150)
