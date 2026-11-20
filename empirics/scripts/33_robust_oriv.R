# 18i_oriv.R: obviously related instrumental variables (ORIV; Gillen, Snowberg & Yariv 2019, JPE) for the two
# noisy measures of ban coverage (industry map, product-name map), session 5.
# Measurement model: x_ind = x* + e1, x_txt = x* + e2 (both are shares of imports banned, same units), e1, e2
# independent. ORIV stacks the data twice: in copy A x_ind is instrumented by x_txt, in copy B x_txt by x_ind; all
# fixed effects are interacted with the copy; SEs clustered by unit (both copies of a unit in one cluster).
# Units: (1) IPC subclasses (official IPC, >= 10 patents/yr in 2015-21); (2) 35 WIPO fields (benchmark).
# FE: unit + year ("across"); for subclasses also unit + field x year ("within fields").
# Outcome: OLS log(1 + n_frac) (ORIV is linear). PPML: approximate control-function version, pooled only,
# cluster bootstrap. Coefficients per 10 pp of coverage; also per SD of the latent coverage, sd(x*) = sqrt(cov(x_ind, x_txt)).
# Comparison: naive OLS with each map alone and with the average of the two maps.
# Output: output/tables/oriv.csv, oriv_es.csv; fig49_oriv_es
source(here::here("empirics", "scripts", "00_setup.R"))
set.seed(20261119)
YEARS <- 2015:2025

# ---- panels ----
sp <- read_csv(here("data", "clean", "ru_domestic_subclass_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS) %>% complete(subclass, year = YEARS, fill = list(n_frac = 0, n_first = 0))
keep <- sp %>% filter(year <= 2021) %>% group_by(subclass) %>% summarise(avg = mean(n_frac)) %>%
  filter(avg >= 10) %>% pull(subclass)
sc <- read_csv(here("data", "clean", "subclass_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(year == 2023, subclass %in% keep, !is.na(field)) %>%
  select(map, unit = subclass, field, coverage) %>% pivot_wider(names_from = map, values_from = coverage) %>%
  drop_na(industry, text)
sub <- sp %>% rename(unit = subclass) %>% inner_join(sc, by = "unit")

fp <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS)
fc <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023) %>% select(map, field, coverage) %>%
  pivot_wider(names_from = map, values_from = coverage)
fld <- fp %>% inner_join(fc, by = "field") %>% mutate(unit = field)

prep <- function(d) d %>% mutate(x_ind = 10 * industry, x_txt = 10 * text, x_avg = (x_ind + x_txt) / 2,
                                  post = as.integer(year >= 2022), ly = log1p(n_frac), y = n_frac)

# stacked data: copy A (x = industry, z = text), copy B (x = text, z = industry)
stack <- function(d) bind_rows(d %>% mutate(s = "A", x = x_ind, z = x_txt), d %>% mutate(s = "B", x = x_txt, z = x_ind)) %>%
  mutate(xp = x * post, zp = z * post)
ev_vars <- function(d) {
  for (k in setdiff(YEARS, 2021)) { d[[paste0("x_", k)]] <- d$x * (d$year == k); d[[paste0("z_", k)]] <- d$z * (d$year == k) }
  d
}
fe_str <- function(fe) switch(fe, across = "unit^s + year^s", within = "unit^s + field^year^s")
fe_naive <- function(fe) switch(fe, across = "unit + year", within = "unit + field^year")

# latent SD (per 10 pp units): across units, and within fields
lat_sd <- function(d, within = FALSE) {
  u <- distinct(d, unit, field, x_ind, x_txt)
  if (within) u <- u %>% group_by(field) %>% mutate(across(c(x_ind, x_txt), ~ . - mean(.))) %>% ungroup()
  c(sd_lat = sqrt(max(cov(u$x_ind, u$x_txt), 0)), corr = cor(u$x_ind, u$x_txt), sd_ind = sd(u$x_ind), sd_txt = sd(u$x_txt))
}

# ---- pooled: naive OLS vs ORIV (log outcome) ----
pooled <- function(d, level, fe) {
  st <- stack(d)
  m_oriv <- feols(as.formula(paste("ly ~ 1 |", fe_str(fe), "| xp ~ zp")), data = st, cluster = ~unit)
  fs <- fitstat(m_oriv, "ivwald1")[[1]]$stat
  naive <- map_dfr(c(x_ind = "industry map", x_txt = "product-name map", x_avg = "average of maps") %>% imap(~ .y), function(v) {
    m <- feols(as.formula(paste0("ly ~ ", v, ":post | ", fe_naive(fe))), data = d, cluster = ~unit)
    tibble(est = paste("naive OLS,", c(x_ind = "industry map", x_txt = "product-name map", x_avg = "average of maps")[[v]]),
           beta = coef(m)[[1]], se = se(m)[[1]])
  })
  ls <- lat_sd(d, within = fe == "within")
  bind_rows(naive, tibble(est = "ORIV", beta = coef(m_oriv)[["fit_xp"]], se = se(m_oriv)[["fit_xp"]], first_stage_F = fs)) %>%
    mutate(level = level, fe = fe, n_units = n_distinct(d$unit), sd_lat = ls[["sd_lat"]], map_corr = ls[["corr"]],
           beta_per_latent_sd = beta * sd_lat, se_per_latent_sd = se * sd_lat)
}

# ---- PPML control function (approximate), pooled, cluster bootstrap ----
ppml_cf <- function(d, fe, B = 199) {
  est1 <- function(dd) {
    st <- stack(dd)
    st$v <- resid(feols(as.formula(paste("xp ~ zp |", fe_str(fe))), data = st), na.rm = FALSE)
    coef(fepois(as.formula(paste("y ~ xp + v |", fe_str(fe))), data = st))[["xp"]]
  }
  b0 <- est1(d)
  units <- unique(d$unit); dl <- split(d, d$unit)
  bs <- replicate(B, {
    draw <- sample(units, replace = TRUE)
    dd <- bind_rows(lapply(seq_along(draw), function(i) dl[[draw[i]]] %>% mutate(unit = paste0(unit, "_", i))))
    tryCatch(est1(dd), error = function(e) NA_real_)
  })
  naive <- fepois(as.formula(paste("y ~ x_avg:post |", fe_naive(fe))), data = d, cluster = ~unit)
  tibble(est = c("naive PPML, average of maps", "ORIV-CF PPML (bootstrap)"),
         beta = c(coef(naive)[[1]], b0), se = c(se(naive)[[1]], sd(bs, na.rm = TRUE)))
}

res <- bind_rows(
  pooled(prep(sub), "subclass", "across"),
  pooled(prep(sub), "subclass", "within"),
  pooled(prep(fld), "field", "across"))
cf <- bind_rows(
  ppml_cf(prep(sub), "across") %>% mutate(level = "subclass", fe = "across"),
  ppml_cf(prep(sub), "within") %>% mutate(level = "subclass", fe = "within"),
  ppml_cf(prep(fld), "across") %>% mutate(level = "field", fe = "across"))
out <- bind_rows(res, cf) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se, p = 2 * pnorm(-abs(beta / se)))
write_csv(out, file.path(TAB_DIR, "oriv.csv"))
cat("\nPooled estimates per 10 pp of coverage (log points):\n")
print(out %>% select(level, fe, est, beta, se, lo, hi, p, first_stage_F, map_corr, sd_lat) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf, width = Inf)

# ---- event studies: ORIV vs naive (average of maps) ----
es_one <- function(d, level, fe) {
  st <- ev_vars(stack(d))
  xs <- paste0("x_", setdiff(YEARS, 2021)); zs <- paste0("z_", setdiff(YEARS, 2021))
  m <- feols(as.formula(paste("ly ~ 1 |", fe_str(fe), "|", paste(xs, collapse = "+"), "~", paste(zs, collapse = "+"))),
             data = st, cluster = ~unit)
  w <- wald(m, keep = "fit_x_201[5-9]|fit_x_2020", print = FALSE)
  mn <- feols(as.formula(paste("ly ~ i(year, x_avg, ref = 2021) |", fe_naive(fe))), data = d, cluster = ~unit)
  bind_rows(
    broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}")), est = "ORIV"),
    broom::tidy(mn, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}")), est = "naive OLS, average of maps")) %>%
    bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0, est = c("ORIV", "naive OLS, average of maps"))) %>%
    mutate(level = level, fe = fe, pre_wald_p = w$p)
}
es <- bind_rows(es_one(prep(sub), "subclass", "across"), es_one(prep(sub), "subclass", "within"),
                es_one(prep(fld), "field", "across"))
write_csv(es %>% select(level, fe, est, year, estimate, std.error, conf.low, conf.high, pre_wald_p), file.path(TAB_DIR, "oriv_es.csv"))
print(es %>% filter(est == "ORIV") %>% select(level, fe, year, estimate, conf.low, conf.high, pre_wald_p) %>%
        arrange(level, fe, year) %>% mutate(across(where(is.double), ~ round(., 3))), n = Inf)

lab <- c("field_across" = "A. 35 fields, field + year FE", "subclass_across" = "B. Subclasses, subclass + year FE",
         "subclass_within" = "C. Subclasses within fields, subclass + field x year FE")
pd <- es %>% mutate(panel = factor(lab[paste(level, fe, sep = "_")], lab))
pl <- es %>% distinct(level, fe, pre_wald_p) %>% mutate(panel = factor(lab[paste(level, fe, sep = "_")], lab),
                                                        txt = sprintf("ORIV pre-period joint p = %.2f", pre_wald_p))
p <- ggplot(pd, aes(year, estimate, colour = est)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.2) +
  geom_text(data = pl, aes(x = 2015, y = -Inf, label = txt), hjust = 0, vjust = -0.6, size = 3, inherit.aes = FALSE) +
  facet_wrap(~panel, scales = "free_y") + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("ORIV" = "#D55E00", "naive OLS, average of maps" = "grey55")) +
  labs(x = "Filing year", y = "OLS log(1 + patents), per 10 pp of ban coverage", colour = NULL,
       caption = paste("ORIV: each map instruments the other (stacked, FE interacted with the copy), Gillen, Snowberg & Yariv (2019).",
                       "Base 2021; 95% CIs clustered by unit. Official IPC.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig49_oriv_es.pdf"), p, width = 13, height = 4.8)
ggsave(file.path(FIG_DIR, "fig49_oriv_es.png"), p, width = 13, height = 4.8, dpi = 150)
