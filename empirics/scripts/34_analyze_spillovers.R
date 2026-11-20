# 18j_spillovers.R: technology spillovers of the export bans (session 5; note 13). Official IPC, 2015-2025.
# Neighbour exposure N_i = sum_{j != i} w_ij * Ban_j, with w from pre-war (2010-21) domestic patents (script 25):
#   co-classification (P1) or holder overlap (P2); weights renormalised over neighbours with a coverage value.
# Subclass level also: "rest of field" = coverage of the subclass's WIPO field excluding the subclass itself
#   (import-weighted: sum_{j in field, j != i} cov_j * W_j / sum W_j, W = 2019-21 Western imports mapped to j).
# Model: y_it = b * Ban_i x Post + g * N_i x Post + FE; Ban and N in units of 10 pp of coverage (same scale).
# Fixed specification (decided before running): P1 main, P2 mechanism, rest-of-field simple check; subclasses
# (282, >= 10 patents/yr) with subclass + year and subclass + field x year FE; fields with field + year FE (P1, P2).
# PPML main, OLS log(1+n) alongside; industry map main, product-name map robustness. SEs clustered by unit.
# Output: empirics/results/tables/spillovers.csv, spillovers_corr.csv; fig50_spillovers
source(here::here("empirics", "scripts", "00_setup.R"))
YEARS <- 2015:2025
prox <- read_csv(here("data", "processed", "tech_proximity", "tech_proximity.csv"), show_col_types = FALSE,
                 col_types = cols(i = "c", j = "c", level = "c"))

nb <- function(cv, lvl) {  # cv: unit (chr), cov  -> unit, n_coclass, n_holder
  prox %>% filter(level == lvl) %>% inner_join(cv %>% rename(j = unit, cov_j = cov), by = "j") %>%
    group_by(unit = i) %>%
    summarise(n_coclass = sum(w_coclass * cov_j) / sum(w_coclass), n_holder = sum(w_holder * cov_j) / sum(w_holder),
              .groups = "drop")
}

# ---- subclass panel ----
sp <- read_csv(here("data", "processed", "official_ipc_panels", "ru_domestic_subclass_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS) %>% complete(subclass, year = YEARS, fill = list(n_frac = 0, n_first = 0))
keep <- sp %>% filter(year <= 2021) %>% group_by(subclass) %>% summarise(avg = mean(n_frac)) %>%
  filter(avg >= 10) %>% pull(subclass)
scov <- read_csv(here("data", "processed", "subclass_ban_coverage", "subclass_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(year == 2023, !is.na(field))
sub_panel <- function(mp) {
  cv <- scov %>% filter(map == mp) %>% transmute(unit = subclass, field, cov = coverage, W = west_pre)
  rest <- cv %>% group_by(field) %>% mutate(rest = (sum(cov * W) - cov * W) / (sum(W) - W)) %>% ungroup() %>%
    select(unit, rest)
  cv %>% filter(unit %in% keep) %>% inner_join(nb(select(cv, unit, cov), "subclass"), by = "unit") %>%
    left_join(rest, by = "unit") %>%
    inner_join(sp %>% rename(unit = subclass), by = "unit")
}
fp <- read_csv(here("data", "processed", "official_ipc_panels", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS)
fcov <- read_csv(here("data", "processed", "ban_coverage", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
fld_panel <- function(mp) {
  cv <- fcov %>% filter(map == mp) %>% transmute(unit = as.character(field), field, cov = coverage)
  cv %>% inner_join(nb(select(cv, unit, cov), "field"), by = "unit") %>% mutate(rest = NA_real_) %>%
    inner_join(fp %>% mutate(unit = as.character(field)) %>% select(-field), by = "unit")
}
prep <- function(d) d %>% mutate(post = as.integer(year >= 2022), own = 10 * cov, nco = 10 * n_coclass,
                                  nho = 10 * n_holder, rof = 10 * rest, y = n_frac, ly = log1p(n_frac))

# ---- correlation check ----
corr_tab <- function(d, level, mp) {
  u <- d %>% distinct(unit, field, own, nco, nho, rof)
  w <- u %>% group_by(field) %>% mutate(across(c(own, nco, nho), ~ . - mean(.))) %>% ungroup()
  tibble(level = level, map = mp,
         corr_own_coclass = cor(u$own, u$nco), corr_own_holder = cor(u$own, u$nho),
         corr_own_restfield = if (all(is.na(u$rof))) NA else cor(u$own, u$rof, use = "complete.obs"),
         within_field_corr_own_coclass = if (level == "subclass") cor(w$own, w$nco) else NA,
         within_field_corr_own_holder = if (level == "subclass") cor(w$own, w$nho) else NA,
         sd_own = sd(u$own), sd_coclass = sd(u$nco), sd_holder = sd(u$nho), n_units = nrow(u))
}
panels <- list(subclass = list(industry = prep(sub_panel("industry")), text = prep(sub_panel("text"))),
               field = list(industry = prep(fld_panel("industry")), text = prep(fld_panel("text"))))
ct <- bind_rows(imap(panels, function(pl, lv) imap_dfr(pl, ~ corr_tab(.x, lv, .y))))
write_csv(ct, file.path(TAB_DIR, "spillovers_corr.csv"))
cat("\nOwn vs neighbour exposure, correlations:\n"); print(ct %>% mutate(across(where(is.double), ~ round(., 2))), width = Inf)

# ---- regressions ----
specs <- tribble(
  ~level,     ~fe,                     ~nbr,  ~label,
  "subclass", "unit + year",           "nco", "co-classification",
  "subclass", "unit + year",           "nho", "holder overlap",
  "subclass", "unit + year",           "rof", "rest of field",
  "subclass", "unit + field^year",     "nco", "co-classification",
  "subclass", "unit + field^year",     "nho", "holder overlap",
  "field",    "unit + year",           "nco", "co-classification",
  "field",    "unit + year",           "nho", "holder overlap")
run <- function(level, fe, nbr, label, mp, est) {
  d <- panels[[level]][[mp]]
  lhs <- if (est == "PPML") "y" else "ly"
  f0 <- as.formula(paste(lhs, "~ own:post |", fe))
  f1 <- as.formula(paste0(lhs, " ~ own:post + ", nbr, ":post | ", fe))
  m0 <- if (est == "PPML") fepois(f0, data = d, cluster = ~unit) else feols(f0, data = d, cluster = ~unit)
  m1 <- if (est == "PPML") fepois(f1, data = d, cluster = ~unit) else feols(f1, data = d, cluster = ~unit)
  k <- names(coef(m1))
  tibble(level, fe, neighbour = label, map = mp, est,
         term = c("own (no neighbour term)", "own", "neighbour"),
         beta = c(coef(m0)[[1]], coef(m1)[[k[1]]], coef(m1)[[k[2]]]),
         se = c(se(m0)[[1]], se(m1)[[k[1]]], se(m1)[[k[2]]]),
         se_field = c(se(m0, cluster = ~field)[[1]], se(m1, cluster = ~field)[[k[1]]], se(m1, cluster = ~field)[[k[2]]]),
         n_units = n_distinct(d$unit))
}
res <- pmap_dfr(specs, function(level, fe, nbr, label)
  map_dfr(c("industry", "text"), function(mp) map_dfr(c("PPML", "OLS log(1+n)"), ~ run(level, fe, nbr, label, mp, .x)))) %>%
  mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se, p = 2 * pnorm(-abs(beta / se)),
         fe = recode(fe, "unit + year" = "unit + year FE", "unit + field^year" = "unit + field x year FE"))
write_csv(res, file.path(TAB_DIR, "spillovers.csv"))
cat("\nPPML, industry map (per 10 pp):\n")
print(res %>% filter(map == "industry", est == "PPML") %>% select(level, fe, neighbour, term, beta, se, lo, hi, p, se_field) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf, width = Inf)
cat("\nOther map / estimator, own and neighbour only:\n")
print(res %>% filter(!(map == "industry" & est == "PPML"), term != "own (no neighbour term)") %>%
        select(level, fe, neighbour, map, est, term, beta, se, p) %>% mutate(across(where(is.double), ~ round(., 3))),
      n = Inf, width = Inf)

pd <- res %>% filter(map == "industry") %>%
  mutate(spec = paste0(c(subclass = "Subclasses", field = "Fields")[level], ", ", fe, "\n", neighbour),
         spec = factor(spec, unique(spec)), term = factor(term, c("own (no neighbour term)", "own", "neighbour")))
p <- ggplot(pd, aes(beta, fct_rev(spec), colour = term)) +
  geom_vline(xintercept = 0, colour = "grey40") +
  geom_pointrange(aes(xmin = lo, xmax = hi), position = position_dodge(0.6), size = 0.25) +
  facet_wrap(~est, scales = "free_x") +
  scale_colour_manual(values = c("own (no neighbour term)" = "grey60", own = "#0072B2", neighbour = "#D55E00")) +
  labs(x = "Coefficient x Post, per 10 pp of ban coverage", y = NULL, colour = NULL,
       caption = paste("Neighbour exposure: closeness-weighted ban coverage of other units (pre-war 2010-21 patents: co-classification",
                       "or shared holders) or of the rest of the WIPO field. Industry map; 95% CIs clustered by unit. Official IPC.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig50_spillovers.pdf"), p, width = 12, height = 6)
ggsave(file.path(FIG_DIR, "fig50_spillovers.png"), p, width = 12, height = 6, dpi = 150)

# ---- event studies for the two subclass specs with a neighbour effect (subclass + year FE, PPML, industry map) ----
d <- panels$subclass$industry
es <- map_dfr(c(nco = "co-classification", rof = "rest of field") %>% imap(~ .y), function(v) {
  m <- fepois(as.formula(paste0("y ~ i(year, own, ref = 2021) + i(year, ", v, ", ref = 2021) | unit + year")),
              data = d, cluster = ~unit)
  w_own <- wald(m, keep = "^year::201[5-9]:own$|^year::2020:own$", print = FALSE)$p
  w_nb <- wald(m, keep = paste0("^year::201[5-9]:", v, "$|^year::2020:", v, "$"), print = FALSE)$p
  broom::tidy(m, conf.int = TRUE) %>%
    mutate(year = as.integer(str_extract(term, "\\d{4}")), term = if_else(str_detect(term, ":own$"), "own", "neighbour")) %>%
    bind_rows(tibble(year = 2021L, term = c("own", "neighbour"), estimate = 0, conf.low = 0, conf.high = 0)) %>%
    mutate(neighbour = c(nco = "co-classification", rof = "rest of field")[[v]], pre_p_own = w_own, pre_p_nb = w_nb)
})
write_csv(es, file.path(TAB_DIR, "spillovers_es.csv"))
print(es %>% select(neighbour, term, year, estimate, conf.low, conf.high, pre_p_own, pre_p_nb) %>% arrange(neighbour, term, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf, width = Inf)
pl <- es %>% distinct(neighbour, pre_p_own, pre_p_nb) %>%
  mutate(txt = sprintf("pre-period joint p: own %.2f, neighbour %.2f", pre_p_own, pre_p_nb))
p2 <- ggplot(es, aes(year, estimate, colour = term)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.2) +
  geom_text(data = pl, aes(x = 2015, y = -Inf, label = txt), hjust = 0, vjust = -0.6, size = 3, inherit.aes = FALSE) +
  facet_wrap(~neighbour) + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c(own = "#0072B2", neighbour = "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient, per 10 pp of coverage", colour = NULL,
       caption = "IPC subclasses (>= 10 patents/yr), subclass + year FE, both exposures in one model, base 2021, 95% CIs clustered by subclass. Industry map.") +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig51_spillovers_es.pdf"), p2, width = 11, height = 4.5)
ggsave(file.path(FIG_DIR, "fig51_spillovers_es.png"), p2, width = 11, height = 4.5, dpi = 150)
