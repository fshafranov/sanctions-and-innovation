# 12d_sdid_covariates.R: synthetic DiD with country-level covariates (robustness to 12_synthetic_did.R).
#
# Covariates (World Bank WDI; data/scripts/cleaning/clean_wb_covariates.py and the outcome panel), each averaged over the
# case's PRE-sanction years only (no post-sanction values, which the sanctions themselves move):
#   core: log GDP per capita, log population, oil + gas rents % GDP, trade % GDP, FDI inflows % GDP,
#         manufacturing value added % GDP, urban population %
#   extended (fewer countries): + tertiary enrolment %, R&D % GDP
# Variants, on the donor pool of 12 restricted to countries with complete covariates:
#   baseline  SDID on the outcome only (same donors as the covariate variants, for a like-for-like comparison)
#   adjusted  outcome residualised on the covariates with year-specific coefficients, estimated on donors only:
#             y*_it = y_it - z_i' b_t, b_t from OLS of y_it on standardised z_i across donors in year t; then SDID
#             (pre-determined covariates whose effect may change over time; keeps post-treatment covariates out)
#   matched   donors restricted to the half closest to the sanctioned country in standardised covariate space
#             (Euclidean distance), then SDID on the outcome
# Balance table: sanctioned country vs simple donor mean vs SDID-weighted donors (baseline weights), per covariate.
# Inputs: data/clean/sdid_case_data.csv (from 12), data/clean/covariates_country_year.csv (from 13), panel.
# Output: output/tables/sdid_covariates.csv, sdid_balance.csv; figures fig23_sdid_covariates, fig24_sdid_balance.
source(here::here("scripts", "analysis", "00_setup.R"))
source(here("scripts", "analysis", "sdid_functions.R"))

CASE_T0 <- c("Russia 2014" = 2014, "Russia 2022" = 2022, "Iran 2012" = 2012)
CASE_ISO <- c("Russia 2014" = "RUS", "Russia 2022" = "RUS", "Iran 2012" = "IRN")
OUTS <- c(pat_res = "Resident patents, log", pat_nres = "Non-resident patents, log",
          works_oa = "Articles (OpenAlex), log", articles_wb = "Journal articles (WB), log",
          intl_share = "Int. co-authored share, pp")
CORE <- c(lgdppc = "log GDP per capita", lpop = "log population", oilgas = "Oil + gas rents, % GDP",
          trade_gdp = "Trade, % GDP", fdi_in_gdp = "FDI inflows, % GDP", manuf_va_gdp = "Manufacturing VA, % GDP",
          urban_share = "Urban population, %")
EXT <- c(CORE, tertiary_enrol = "Tertiary enrolment, %", rd_gdp = "R&D, % GDP")

cases <- read_csv(here("data", "clean", "sdid_case_data.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "covariates_country_year.csv"), show_col_types = FALSE) %>%
  full_join(read_panel() %>% select(iso3, year, gdppc, pop, rd_gdp), by = c("iso3", "year")) %>%
  mutate(lgdppc = log(gdppc), lpop = log(pop), oilgas = oil_rents + gas_rents)

pre_means <- function(case, vars) {
  cov %>% filter(year >= min(cases$year[cases$case == case]), year < CASE_T0[case]) %>%
    group_by(iso3) %>% summarise(across(all_of(vars), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    filter(if_all(all_of(vars), is.finite))
}

to_matrix <- function(dd, iso) {
  w <- dd %>% select(iso3, year, y) %>% arrange(year) %>% pivot_wider(names_from = year, values_from = y)
  w <- w[c(which(w$iso3 != iso), which(w$iso3 == iso)), ]
  Y <- as.matrix(w[, -1]); rownames(Y) <- w$iso3; Y
}

est_variant <- function(Y, T0) {
  f <- sdid_fit(Y, T0, "sdid"); pl <- placebo(Y, T0, "sdid")
  tibble(tau = f$tau, se = sd(pl), p_rank = mean(abs(pl) >= abs(f$tau)), pre_rmse = f$pre_rmse,
         n_donors = nrow(Y) - 1, donors_top = paste(names(sort(f$w, decreasing = TRUE))[1:3], collapse = " "))
}

run_one <- function(case, outcome, set_name, vars) {
  iso <- CASE_ISO[case]; T0y <- CASE_T0[case]
  X <- pre_means(case, names(vars))
  dd <- cases %>% filter(case == !!case, outcome == !!outcome, iso3 %in% X$iso3)
  if (!iso %in% dd$iso3) return(NULL)
  Y <- to_matrix(dd, iso); T0 <- sum(as.integer(colnames(Y)) < T0y); N0 <- nrow(Y) - 1
  Z <- X %>% filter(iso3 %in% rownames(Y)) %>% slice(match(rownames(Y), iso3)) %>% select(all_of(names(vars))) %>%
    as.matrix()
  mu <- colMeans(Z[1:N0, , drop = FALSE]); sdv <- apply(Z[1:N0, , drop = FALSE], 2, sd); sdv[sdv == 0] <- 1
  Zs <- sweep(sweep(Z, 2, mu), 2, sdv, "/")
  # adjusted: year-specific coefficients from donors only
  B <- sapply(seq_len(ncol(Y)), function(t) coef(lm(Y[1:N0, t] ~ Zs[1:N0, ]))[-1])
  B[is.na(B)] <- 0
  Yadj <- Y - Zs %*% B
  # matched: closest half of donors
  dist <- sqrt(rowSums(sweep(Zs[1:N0, , drop = FALSE], 2, Zs[N0 + 1, ])^2))
  keep <- c(which(dist <= median(dist)), N0 + 1)
  bind_rows(baseline = est_variant(Y, T0), adjusted = est_variant(Yadj, T0),
            matched = est_variant(Y[keep, , drop = FALSE], T0), .id = "variant") %>%
    mutate(case = case, outcome = outcome, covariates = set_name, n_cov = length(vars))
}

grid <- expand_grid(case = names(CASE_T0), outcome = names(OUTS), set = c("core", "extended"))
res <- pmap_dfr(grid, function(case, outcome, set) run_one(case, outcome, set, if (set == "core") CORE else EXT)) %>%
  mutate(lo = tau - 1.96 * se, hi = tau + 1.96 * se)
base12 <- read_csv(file.path(TAB_DIR, "sdid_estimates.csv"), show_col_types = FALSE) %>% filter(method == "sdid") %>%
  transmute(case, outcome, variant = "original (all donors, no covariates)", covariates = "none", tau,
            se = se_placebo, p_rank, n_donors, lo, hi)
res_all <- bind_rows(base12, res)
write_csv(res_all, file.path(TAB_DIR, "sdid_covariates.csv"))

# balance: sanctioned country vs donors, core covariates, baseline SDID weights on the full donor set of 12
wts <- read_csv(file.path(TAB_DIR, "sdid_weights.csv"), show_col_types = FALSE) %>% filter(type == "unit")
bal <- map_dfr(names(CASE_T0), function(case) map_dfr(c("pat_nres", "pat_res", "works_oa"), function(outcome) {
  X <- pre_means(case, names(CORE))
  w <- wts %>% filter(case == !!case, outcome == !!outcome) %>% inner_join(X, by = c("key" = "iso3"))
  tr <- X %>% filter(iso3 == CASE_ISO[case])
  map_dfr(names(CORE), function(v) tibble(
    case = case, outcome = outcome, covariate = CORE[v], sanctioned = tr[[v]],
    donor_mean = mean(w[[v]]), synthetic = sum(w$weight * w[[v]]) / sum(w$weight),
    weight_covered = sum(w$weight)))
}))
write_csv(bal, file.path(TAB_DIR, "sdid_balance.csv"))

# figures --------------------------------------------------------------------------------------------------------
VAR_LAB <- c("original (all donors, no covariates)" = "Original (all donors)",
             baseline = "Same donors, no covariates", adjusted = "Covariate-adjusted",
             matched = "Closest half of donors")
p23 <- res_all %>% filter(covariates %in% c("none", "core")) %>%
  mutate(variant = factor(VAR_LAB[variant], VAR_LAB), label = factor(OUTS[outcome], OUTS)) %>%
  ggplot(aes(tau, fct_rev(variant), colour = variant)) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_pointrange(aes(xmin = lo, xmax = hi), size = 0.2) +
  facet_wrap(label ~ case, ncol = 3, scales = "free_x", labeller = labeller(.multi_line = FALSE)) +
  scale_colour_manual(values = c("#999999", "#56B4E9", "#0072B2", "#D55E00")) +
  labs(x = "Synthetic DiD effect, average over post years (log points; pp for the share)", y = NULL, colour = NULL,
       title = "Synthetic DiD with country covariates",
       caption = paste("Core covariates, averages over the pre-sanction years: log GDP per capita, log population,",
                       "oil + gas rents, trade, FDI inflows, manufacturing VA (% GDP), urban share.\nCovariate-adjusted:",
                       "outcome residualised on covariates with year-specific coefficients (donors only). Closest half:",
                       "donors nearest in standardised covariates.\n95% intervals from placebo SEs.")) +
  theme_paper() + guides(colour = guide_legend(nrow = 2))
save_figure(p23 + theme(axis.text.y = element_blank(), strip.text = element_text(size = 7.5)),
            "fig23_sdid_covariates", 11, 10)

p24 <- bal %>% filter(outcome == "pat_nres") %>%
  pivot_longer(c(sanctioned, donor_mean, synthetic), names_to = "who") %>%
  mutate(who = factor(recode(who, sanctioned = "Sanctioned country", donor_mean = "Donor average (equal weights)",
                             synthetic = "Synthetic DiD control"),
                      c("Sanctioned country", "Synthetic DiD control", "Donor average (equal weights)"))) %>%
  ggplot(aes(value, case, colour = who, shape = who)) +
  geom_point(size = 2.2, position = position_dodge(width = 0.5)) +
  facet_wrap(~covariate, scales = "free_x", ncol = 4) +
  scale_colour_manual(values = c("#D55E00", "#0072B2", "#999999")) +
  labs(x = NULL, y = NULL, colour = NULL, shape = NULL,
       title = "Who is the synthetic control? Covariate balance (non-resident patents)",
       caption = paste("Pre-sanction averages. Synthetic DiD control = donors weighted by the SDID unit weights of",
                       "12_synthetic_did.R (outcome-only weights; covariates were not used to choose them).")) +
  theme_paper()
save_figure(p24, "fig24_sdid_balance", 11, 5.5)

print(res_all %>% filter(covariates %in% c("none", "core")) %>% select(case, outcome, variant, tau, se, p_rank, n_donors) %>%
        mutate(across(where(is.double), ~ round(.x, 3))) %>% arrange(case, outcome), n = 80)
print(res_all %>% filter(covariates == "extended") %>% select(case, outcome, variant, tau, se, n_donors) %>%
        mutate(across(where(is.double), ~ round(.x, 3))), n = 60)
print(bal %>% filter(outcome == "pat_nres") %>% mutate(across(where(is.double), ~ round(.x, 2))), n = 30)
