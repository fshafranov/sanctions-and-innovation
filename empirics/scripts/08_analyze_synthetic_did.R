# 12_synthetic_did.R: synthetic difference-in-differences for single sanction cases (Russia 2014, Russia 2022,
# Iran 2012), with synthetic control and plain DiD on the same data for comparison.
#
# Estimator: Arkhangelsky, Athey, Hirshberg, Imbens & Wager (2021, AER), Algorithm 1, implemented here (the
# reference package `synthdid` is GitHub-only and could not be installed; quadprog solves the weight problems).
#   Y: units x years, controls i = 1..N0, one treated unit, pre years t = 1..T0, post years T0+1..T.
#   unit weights  (w0, w) = argmin sum_{t<=T0} (w0 + sum_i w_i Y_it - Y_tr,t)^2 + zeta^2 T0 |w|^2, w on the simplex,
#                 zeta = (N_tr T_post)^(1/4) * sd(first differences of control outcomes, pre years)
#   time weights  (l0, l) = argmin sum_{i<=N0} (l0 + sum_t l_t Y_it - mean_post Y_i)^2, l on the simplex
#                 (+ tiny ridge 1e-6 * sd, as in the reference code)
#   tau = [mean_post Y_tr - sum_t l_t Y_tr,t] - sum_i w_i [mean_post Y_i - sum_t l_t Y_it]
#   SC  : unit weights without intercept and without ridge; compares post means only (tau = post gap).
#   DiD : uniform unit and time weights.
#   Inference: placebo (Algorithm 4) -- every donor in turn plays the treated unit; SE = sd of placebo estimates;
#   also the rank p-value (share of placebos with |tau_placebo| >= |tau|).
# Donors (per case): population >= 1m; no Western economic case in force in any year of the case window
#   (GSDB, years <= 2023); outcome observed in every window year; count outcomes with >= 20 a year on average before;
#   close partners of the target excluded (spillovers): for Russia the former Soviet states, China and Turkey; for
#   Iran its neighbours (Iraq, Turkey, Afghanistan, Pakistan, Armenia, Azerbaijan, Turkmenistan, UAE) and China.
# Outcomes: log(1+resident patents), log(1+non-resident patents), log OpenAlex articles, log WB articles,
#   internationally co-authored share (pp).
# Output: output/tables/sdid_estimates.csv, sdid_paths.csv, sdid_weights.csv, sdid_yearly.csv; figures fig20-22;
#   data/clean/sdid_case_data.csv (the balanced case panels, re-estimated with the Python synthdid package in 12c).
source(here::here("empirics", "scripts", "00_setup.R"))
suppressPackageStartupMessages(library(quadprog))

FSU <- c("ARM", "AZE", "BLR", "EST", "GEO", "KAZ", "KGZ", "LTU", "LVA", "MDA", "TJK", "TKM", "UKR", "UZB")
CASES <- list(
  list(case = "Russia 2014", iso = "RUS", t0 = 2014, from = 2000, to = 2021, excl = c(FSU, "CHN", "TUR")),
  list(case = "Russia 2022", iso = "RUS", t0 = 2022, from = 2010, to = 2024, excl = c(FSU, "CHN", "TUR")),
  list(case = "Iran 2012",   iso = "IRN", t0 = 2012, from = 2000, to = 2015,
       excl = c("IRQ", "TUR", "AFG", "PAK", "ARM", "AZE", "TKM", "ARE", "CHN")))
OUTS <- c(pat_res = "Resident patent applications, log", pat_nres = "Non-resident patent applications, log",
          works_oa = "Articles (OpenAlex), log", articles_wb = "Journal articles (WB), log",
          intl_share = "Internationally co-authored share, pp")
COUNTS <- c("pat_res", "pat_nres")

panel <- read_panel()

source(here::here("empirics", "scripts", "sdid_functions.R"))

run_case <- function(cs, outcome) {
  yrs <- cs$from:cs$to
  d <- panel %>% filter(year %in% yrs) %>%
    mutate(v = if (outcome %in% COUNTS) log1p(.data[[outcome]]) else if (outcome == "intl_share") .data[[outcome]]
           else log(.data[[outcome]]))
  avail <- d %>% filter(iso3 == cs$iso, !is.na(v)) %>% pull(year)
  yrs <- intersect(yrs, avail); yrs <- yrs[yrs <= max(avail)]
  if (sum(yrs >= cs$t0) < 1) return(NULL)
  clean <- panel %>% filter(year %in% intersect(cs$from:cs$to, 1990:2023)) %>% group_by(iso3) %>%
    summarise(clean = all(coalesce(n_active_west_econ, 0) == 0), big = first(pop_ge1m) == 1, .groups = "drop")
  donors <- d %>% filter(year %in% yrs, iso3 != cs$iso, !iso3 %in% cs$excl) %>%
    semi_join(clean %>% filter(clean, big), by = "iso3") %>% group_by(iso3) %>%
    filter(sum(is.finite(v)) == length(yrs),
           !(outcome %in% COUNTS) | mean(.data[[outcome]][year < cs$t0]) >= 20) %>% ungroup()
  wide <- bind_rows(donors, d %>% filter(iso3 == cs$iso, year %in% yrs)) %>%
    select(iso3, year, v) %>% pivot_wider(names_from = year, values_from = v)
  wide <- wide[c(which(wide$iso3 != cs$iso), which(wide$iso3 == cs$iso)), ]
  Y <- as.matrix(wide[, -1]); rownames(Y) <- wide$iso3; Y <- Y[, as.character(sort(yrs)), drop = FALSE]
  stopifnot(!anyNA(Y), rownames(Y)[nrow(Y)] == cs$iso)
  T0 <- sum(yrs < cs$t0)
  fits <- map(c(sdid = "sdid", sc = "sc", did = "did"), ~ sdid_fit(Y, T0, .x))
  est <- imap_dfr(fits, function(f, m) {
    pl <- placebo(Y, T0, m)
    tibble(method = m, tau = f$tau, se_placebo = sd(pl), p_rank = mean(abs(pl) >= abs(f$tau)),
           pre_rmse = f$pre_rmse, n_donors = nrow(Y) - 1, pre_years = T0, post_years = ncol(Y) - T0)
  })
  meta <- tibble(case = cs$case, outcome = outcome)
  long <- as_tibble(Y, rownames = "iso3") %>% pivot_longer(-iso3, names_to = "year", values_to = "y") %>%
    mutate(year = as.integer(year), treated = as.integer(iso3 == cs$iso & year >= cs$t0))
  list(est = bind_cols(meta, est), data = bind_cols(meta, long),
       paths = imap_dfr(fits, ~ bind_cols(meta, method = .y, .x$path)),
       weights = bind_rows(
         tibble(type = "unit", key = names(fits$sdid$w), weight = fits$sdid$w),
         tibble(type = "time", key = names(fits$sdid$l), weight = fits$sdid$l)) %>% bind_cols(meta, .))
}

out <- map(CASES, function(cs) map(names(OUTS), ~ run_case(cs, .x))) %>% flatten() %>% compact()
est <- map_dfr(out, "est") %>% mutate(lo = tau - 1.96 * se_placebo, hi = tau + 1.96 * se_placebo)
paths <- map_dfr(out, "paths"); wts <- map_dfr(out, "weights")
write_csv(map_dfr(out, "data"), here("data", "clean", "sdid_case_data.csv"))   # input for 12c (Python synthdid)
write_csv(est, file.path(TAB_DIR, "sdid_estimates.csv"))
write_csv(paths, file.path(TAB_DIR, "sdid_paths.csv"))
write_csv(wts, file.path(TAB_DIR, "sdid_weights.csv"))

# fig20: treated vs synthetic (SDID) paths ------------------------------------------------------------------------
cap <- paste("Synthetic DiD (Arkhangelsky et al. 2021), implemented in empirics/scripts/08_analyze_synthetic_did.R. Donors:",
             "countries (pop >= 1m) without a Western economic\nsanction in force in the window; former Soviet states,",
             "China and Turkey (Russia) or Iran's neighbours and China excluded. Synthetic line shifted by the",
             "time-weighted pre-period gap.\nPlacebo SE and rank p from re-running with each donor as the treated unit.")
pp <- paths %>% filter(method == "sdid") %>%
  left_join(CASES %>% map_dfr(~ tibble(case = .x$case, t0 = .x$t0)), by = "case") %>%
  mutate(label = OUTS[outcome]) %>%
  pivot_longer(c(treated, synthetic), names_to = "series") %>%
  mutate(series = recode(series, treated = "Sanctioned country", synthetic = "Synthetic DiD control"))
tw <- wts %>% filter(type == "time") %>% mutate(year = as.integer(key), label = OUTS[outcome])
lab_est <- est %>% filter(method == "sdid") %>% mutate(label = OUTS[outcome],
  txt = sprintf("SDID %.2f (placebo SE %.2f, p = %.2f)\nSC %.2f, DiD %.2f", tau, se_placebo, p_rank,
                est$tau[est$method == "sc"][match(paste(case, outcome), paste(est$case[est$method == "sc"],
                                                                                est$outcome[est$method == "sc"]))],
                est$tau[est$method == "did"][match(paste(case, outcome), paste(est$case[est$method == "did"],
                                                                                 est$outcome[est$method == "did"]))]))
p20 <- ggplot(pp, aes(year, value)) +
  geom_vline(aes(xintercept = t0 - 0.5), linetype = "dashed", colour = "grey60") +
  geom_line(aes(colour = series), linewidth = 0.6) +
  geom_text(data = lab_est, aes(x = -Inf, y = Inf, label = txt), hjust = -0.03, vjust = 1.2, size = 2.3,
            colour = "grey20") +
  facet_wrap(case ~ label, scales = "free", ncol = 5, labeller = labeller(.multi_line = FALSE)) +
  scale_colour_manual(values = c("Sanctioned country" = "#D55E00", "Synthetic DiD control" = "#0072B2")) +
  labs(x = NULL, y = NULL, colour = NULL, title = "Synthetic difference-in-differences for three sanction cases",
       caption = cap) +
  theme_paper() + theme(strip.text = element_text(size = 7.5))
save_figure(p20, "fig20_sdid_paths", 14, 8.5)

# fig21: estimates by method -------------------------------------------------------------------------------------
p21 <- est %>% mutate(label = OUTS[outcome],
                      method = factor(recode(method, sdid = "Synthetic DiD", sc = "Synthetic control", did = "DiD"),
                                      c("Synthetic DiD", "Synthetic control", "DiD"))) %>%
  ggplot(aes(tau, fct_rev(label), colour = method)) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_pointrange(aes(xmin = lo, xmax = hi), position = position_dodge(width = 0.6), size = 0.25) +
  facet_wrap(~case, nrow = 1) +
  scale_colour_manual(values = c("Synthetic DiD" = "#0072B2", "Synthetic control" = "#009E73", "DiD" = "#999999")) +
  labs(x = "Average effect over the post years (log points; pp for the share)", y = NULL, colour = NULL,
       title = "Average post-sanction effect by estimator", caption = "Intervals: ±1.96 placebo SE.") +
  theme_paper()
save_figure(p21, "fig21_sdid_estimates", 11, 4.5)

# fig22: SDID effect by year with 95% placebo bands ---------------------------------------------------------------
# For each year: gap = treated minus synthetic control (after removing the time-weighted pre-period gap). Band =
# gap +/- 1.96 x sd of the same yearly gap across placebo runs (each donor in turn as the treated unit).
yearly <- map_dfr(out, function(o) {
  dd <- o$data; cs <- CASES[[match(dd$case[1], map_chr(CASES, "case"))]]
  wide <- dd %>% select(iso3, year, y) %>% arrange(year) %>% pivot_wider(names_from = year, values_from = y)
  wide <- wide[c(which(wide$iso3 != cs$iso), which(wide$iso3 == cs$iso)), ]
  Y <- as.matrix(wide[, -1]); rownames(Y) <- wide$iso3
  T0 <- sum(as.integer(colnames(Y)) < cs$t0); N0 <- nrow(Y) - 1
  f <- sdid_fit(Y, T0, "sdid")
  pl <- map_dfr(1:N0, function(j) sdid_fit(Y[c(setdiff(1:N0, j), j), , drop = FALSE], T0, "sdid")$path)
  f$path %>% select(year, gap) %>%
    left_join(pl %>% group_by(year) %>% summarise(se = sd(gap), .groups = "drop"), by = "year") %>%
    mutate(case = cs$case, outcome = dd$outcome[1], t0 = cs$t0, lo = gap - 1.96 * se, hi = gap + 1.96 * se)
})
write_csv(yearly, file.path(TAB_DIR, "sdid_yearly.csv"))
p22 <- yearly %>% mutate(label = factor(OUTS[outcome], OUTS), post = year >= t0) %>%
  ggplot(aes(year, gap)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = "#0072B2", alpha = 0.18) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_vline(aes(xintercept = t0 - 0.5), linetype = "dashed", colour = "grey60") +
  geom_line(colour = "#0072B2", linewidth = 0.5) + geom_point(aes(shape = post), colour = "#0072B2", size = 1.2) +
  scale_shape_manual(values = c(`FALSE` = 1, `TRUE` = 16), guide = "none") +
  facet_grid(label ~ case, scales = "free", labeller = labeller(label = label_wrap_gen(22))) +
  labs(x = NULL, y = "Sanctioned country minus synthetic DiD control (log points; pp for the share)",
       title = "Synthetic DiD: effect by year with 95% placebo bands",
       caption = paste("Gap after removing the time-weighted pre-period difference; filled points = years after the",
                       "sanction. Band: +/- 1.96 x sd of the yearly gap across placebo runs\n(each donor in turn",
                       "treated as the sanctioned country). Donors and windows as in fig20; see note 01 section A2.")) +
  theme_paper() + theme(strip.text.y = element_text(size = 7.5))
save_figure(p22, "fig22_sdid_yearly_ci", 10, 11)

print(est %>% mutate(across(where(is.double), ~ round(.x, 3))), n = 60)
print(wts %>% filter(type == "unit", weight > 0.05) %>% arrange(case, outcome, desc(weight)) %>%
        mutate(weight = round(weight, 2)) %>% group_by(case, outcome) %>%
        summarise(top = paste(key, weight, collapse = ", "), .groups = "drop"), n = 30)
