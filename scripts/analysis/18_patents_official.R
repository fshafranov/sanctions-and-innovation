# 18_patents_official.R: main tests re-estimated with OFFICIAL IPC codes (Rospatent API for all years since session 5;
# script 23) instead of title-predicted fields/subclasses (session 5; note 14).
# (A) Field level, pre-registered spec (note 11): PPML, field + year FE, 2015-2025, Ban_f end-2023 z-scored,
#     clustered by field, RI 2,000 permutations; event study base 2021; + sector x year FE; holder types.
# (B) Subclass level (note 13): subclass + field x year FE, same sample rule (>= 10 patents/yr 2015-21).
# Outcomes: n_frac (fractional over distinct fields/subclasses, main) and n_first (first-listed code).
# Output: output/tables/patents_official.csv, patents_official_es.csv; fig38_patents_official_es
source(here::here("scripts", "analysis", "00_setup.R"))
set.seed(20261119)
YEARS <- 2015:2025
sector_of <- function(f) cut(f, c(0, 8, 13, 24, 32, 35), labels = c("El", "In", "Ch", "Me", "Ot"))

fpan <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS) %>% complete(field = 1:35, year = YEARS, fill = list(n_frac = 0, n_first = 0))
fhol <- read_csv(here("data", "clean", "ru_domestic_field_year_holder_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS, holder_type %in% c("firm", "university", "research", "individual")) %>%
  complete(field = 1:35, year = YEARS, holder_type, fill = list(n_frac = 0, n_first = 0))
pred <- read_csv(here("data", "clean", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS) %>% select(field, year, n_top)
fcov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
fban <- function(mp) fcov %>% filter(map == mp) %>% transmute(field, ban = as.numeric(scale(coverage)))

est <- function(d, fml, cl = ~field) {
  m <- fepois(fml, data = d, cluster = cl)
  tibble(beta = coef(m)[["ban:post"]], se = se(m)[["ban:post"]], n = nobs(m))
}
ri <- function(d, R = 2000) {
  b0 <- coef(fepois(y ~ ban:post | field + year, data = d))[[1]]
  f <- distinct(d, field, ban)
  perm <- replicate(R, coef(fepois(y ~ ban:post | field + year,
                                   data = select(d, -ban) %>% inner_join(f %>% mutate(ban = sample(ban)), by = "field")))[[1]])
  mean(abs(perm) >= abs(b0))
}

resA <- map_dfr(c("industry", "text"), function(mp) {
  map_dfr(c("n_frac", "n_first"), function(y) {
    d <- fpan %>% rename(y = all_of(y)) %>% inner_join(fban(mp), by = "field") %>%
      mutate(post = as.integer(year >= 2022), sector = sector_of(field))
    bind_rows(
      est(d, y ~ ban:post | field + year) %>% mutate(spec = "field + year FE (pre-registered)",
                                                    p_ri = if (mp == "industry" && y == "n_frac") ri(d) else NA),
      est(d, y ~ ban:post | field + sector^year) %>% mutate(spec = "field + sector x year FE"),
      est(filter(d, year >= 2019), y ~ ban:post | field + year) %>% mutate(spec = "window 2019-2025")
    ) %>% mutate(map = mp, outcome = y)
  })
})
# same population and years with the predicted outcome, for comparison
dp <- pred %>% rename(y = n_top) %>% inner_join(fban("industry"), by = "field") %>% mutate(post = as.integer(year >= 2022))
resA <- bind_rows(resA, est(dp, y ~ ban:post | field + year) %>%
                    mutate(spec = "field + year FE (pre-registered)", map = "industry", outcome = "n_top (predicted)"))

# holder types
hold <- fhol %>% rename(y = n_frac) %>% inner_join(fban("industry"), by = "field") %>%
  mutate(post = as.integer(year >= 2022), h = holder_type)
mh <- fepois(y ~ ban:post:i(h) | field^h + h^year, data = hold, cluster = ~field)
hres <- broom::tidy(mh, conf.int = TRUE) %>% mutate(spec = "holder type", map = "industry", outcome = "n_frac",
                                                    h = str_extract(term, "(firm|university|research|individual)"))
mdiff <- fepois(y ~ ban:post + ban:post:public | field^h + h^year,
                data = hold %>% filter(h != "individual") %>% mutate(public = as.integer(h %in% c("university", "research"))),
                cluster = ~field)

# (B) subclass, within field
spat <- read_csv(here("data", "clean", "ru_domestic_subclass_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS) %>% complete(subclass, year = YEARS, fill = list(n_frac = 0, n_first = 0))
keep <- spat %>% filter(year <= 2021) %>% group_by(subclass) %>% summarise(avg = mean(n_frac)) %>%
  filter(avg >= 10) %>% pull(subclass)
scov <- read_csv(here("data", "clean", "subclass_ban_coverage.csv"), show_col_types = FALSE) %>% filter(year == 2023)
resB <- map_dfr(c("industry", "text"), function(mp) {
  b <- scov %>% filter(map == mp, subclass %in% keep, !is.na(field)) %>% transmute(subclass, field, ban = as.numeric(scale(coverage)))
  d <- spat %>% rename(y = n_frac) %>% inner_join(b, by = "subclass") %>% mutate(post = as.integer(year >= 2022))
  bind_rows(est(d, y ~ ban:post | subclass + year, ~subclass) %>% mutate(spec = "subclass + year FE"),
            est(d, y ~ ban:post | subclass + field^year, ~subclass) %>% mutate(spec = "subclass + field x year FE")) %>%
    mutate(map = mp, outcome = "n_frac (subclass)", n_sub = n_distinct(d$subclass))
})

res <- bind_rows(resA, resB) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
write_csv(bind_rows(res, hres %>% transmute(spec, map, outcome, h, beta = estimate, lo = conf.low, hi = conf.high)),
          file.path(TAB_DIR, "patents_official.csv"))
print(res %>% select(map, outcome, spec, beta, lo, hi, p_ri, n_sub) %>% mutate(across(where(is.double), ~ round(., 3))),
      n = Inf, width = Inf)
print(hres %>% select(h, estimate, conf.low, conf.high) %>% mutate(across(where(is.double), ~ round(., 3))))
cat("\npublic (univ + research) minus firms:\n"); print(coeftable(mdiff))

# event studies
es <- bind_rows(
  map_dfr(c("industry", "text"), function(mp) {
    d <- fpan %>% rename(y = n_frac) %>% inner_join(fban(mp), by = "field") %>% mutate(sector = sector_of(field))
    m <- fepois(y ~ i(year, ban, ref = 2021) | field + year, data = d, cluster = ~field)
    broom::tidy(m, conf.int = TRUE) %>% mutate(map = mp, panel = "Fields (35), field + year FE")
  }),
  {
    b <- scov %>% filter(map == "industry", subclass %in% keep, !is.na(field)) %>%
      transmute(subclass, field, ban = as.numeric(scale(coverage)))
    d <- spat %>% rename(y = n_frac) %>% inner_join(b, by = "subclass")
    m <- fepois(y ~ i(year, ban, ref = 2021) | subclass + field^year, data = d, cluster = ~subclass)
    broom::tidy(m, conf.int = TRUE) %>% mutate(map = "industry", panel = "Subclasses, subclass + field x year FE")
  }) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
  bind_rows(expand_grid(map = c("industry", "text"), panel = "Fields (35), field + year FE") %>%
              bind_rows(tibble(map = "industry", panel = "Subclasses, subclass + field x year FE")) %>%
              mutate(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0))
write_csv(es, file.path(TAB_DIR, "patents_official_es.csv"))
print(es %>% select(panel, map, year, estimate, conf.low, conf.high) %>% arrange(panel, map, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)
p <- es %>% mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map")) %>%
  ggplot(aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.25) +
  facet_wrap(~panel) + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (SD)", colour = NULL,
       caption = "Domestic invention patents with official IPC (Rospatent API), fractional counts, base 2021, 95% CIs.") +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig38_patents_official_es.pdf"), p, width = 10, height = 5)
ggsave(file.path(FIG_DIR, "fig38_patents_official_es.png"), p, width = 10, height = 5, dpi = 150)

# fig38a: field panel alone (README opener)
pf <- es %>% filter(panel == "Fields (35), field + year FE") %>%
  mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map")) %>%
  ggplot(aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.3) +
  scale_x_continuous(breaks = 2015:2025) + scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (per SD)", colour = NULL,
       caption = paste("35 WIPO technology fields, field + year FE, base 2021, 95% CIs clustered by field.",
                       "Domestic invention patents, official IPC (Rospatent API), fractional counts.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig38a_fields_official_es.pdf"), pf, width = 8, height = 5)
ggsave(file.path(FIG_DIR, "fig38a_fields_official_es.png"), pf, width = 8, height = 5, dpi = 150)
