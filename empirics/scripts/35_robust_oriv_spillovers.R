# 18k_oriv_spillovers.R: own vs neighbour exposure with BOTH terms corrected for map noise by ORIV (session 5; note 13).
# Question: does the subclass's own ban coverage lose the horse race against neighbour exposure only because it is
# measured with more noise (two maps agree 0.25 within fields) while neighbour exposure averages the noise out?
# Each exposure exists in two versions (industry map, product-name map). Stacked ORIV (Gillen, Snowberg & Yariv 2019):
#   copy A: endogenous own_ind, nbr_ind; instruments own_txt, nbr_txt
#   copy B: endogenous own_txt, nbr_txt; instruments own_ind, nbr_ind
# FE interacted with the copy; SEs clustered by subclass. Outcome OLS log(1 + n_frac) (linear IV), per 10 pp.
# Neighbour: rest of field (main; flat pre-trend in 18j) and co-classification. Subclass + year FE.
# Compared with naive OLS (industry map; average of maps). Event-study version for rest of field.
# Output: empirics/results/tables/oriv_spillovers.csv, oriv_spillovers_es.csv; fig52_oriv_spillovers_es
source(here::here("empirics", "scripts", "00_setup.R"))
YEARS <- 2015:2025
prox <- read_csv(here("data", "processed", "tech_proximity", "tech_proximity.csv"), show_col_types = FALSE,
                 col_types = cols(i = "c", j = "c", level = "c")) %>% filter(level == "subclass")
sp <- read_csv(here("data", "processed", "official_ipc_panels", "ru_domestic_subclass_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS) %>% complete(subclass, year = YEARS, fill = list(n_frac = 0, n_first = 0))
keep <- sp %>% filter(year <= 2021) %>% group_by(subclass) %>% summarise(avg = mean(n_frac)) %>%
  filter(avg >= 10) %>% pull(subclass)
scov <- read_csv(here("data", "processed", "subclass_ban_coverage", "subclass_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(year == 2023, !is.na(field))

expo <- function(mp) {
  cv <- scov %>% filter(map == mp) %>% transmute(unit = subclass, field, cov = coverage, W = west_pre)
  rest <- cv %>% group_by(field) %>% mutate(rest = (sum(cov * W) - cov * W) / (sum(W) - W)) %>% ungroup() %>% select(unit, rest)
  nco <- prox %>% inner_join(cv %>% select(j = unit, cov_j = cov), by = "j") %>% group_by(unit = i) %>%
    summarise(nco = sum(w_coclass * cov_j) / sum(w_coclass), .groups = "drop")
  cv %>% filter(unit %in% keep) %>% left_join(rest, by = "unit") %>% inner_join(nco, by = "unit") %>%
    transmute(unit, field, own = 10 * cov, rof = 10 * rest, nco = 10 * nco)
}
e <- inner_join(expo("industry"), expo("text"), by = c("unit", "field"), suffix = c("_ind", "_txt")) %>% drop_na()
d <- sp %>% rename(unit = subclass) %>% inner_join(e, by = "unit") %>%
  mutate(post = as.integer(year >= 2022), ly = log1p(n_frac))
cat("subclasses with both maps:", n_distinct(d$unit), "\n")
u <- distinct(d, unit, own_ind, own_txt, rof_ind, rof_txt, nco_ind, nco_txt)
cat("map agreement: own", round(cor(u$own_ind, u$own_txt), 2), "; rest of field", round(cor(u$rof_ind, u$rof_txt), 2),
    "; co-class", round(cor(u$nco_ind, u$nco_txt), 2), "\n")

stack <- function(d, nb) bind_rows(
  d %>% mutate(s = "A", own = own_ind, nbr = .data[[paste0(nb, "_ind")]], own_z = own_txt, nbr_z = .data[[paste0(nb, "_txt")]]),
  d %>% mutate(s = "B", own = own_txt, nbr = .data[[paste0(nb, "_txt")]], own_z = own_ind, nbr_z = .data[[paste0(nb, "_ind")]])) %>%
  mutate(own_p = own * post, nbr_p = nbr * post, own_zp = own_z * post, nbr_zp = nbr_z * post)

pooled <- function(nb, label) {
  st <- stack(d, nb)
  m <- feols(ly ~ 1 | unit^s + year^s | own_p + nbr_p ~ own_zp + nbr_zp, data = st, cluster = ~unit)
  m1 <- feols(ly ~ 1 | unit^s + year^s | own_p ~ own_zp, data = st, cluster = ~unit)  # own alone, ORIV
  fs <- fitstat(m, "ivwald")
  dd <- d %>% mutate(own_a = (own_ind + own_txt) / 2, nbr_a = (.data[[paste0(nb, "_ind")]] + .data[[paste0(nb, "_txt")]]) / 2,
                     own_i = own_ind, nbr_i = .data[[paste0(nb, "_ind")]])
  ni <- feols(ly ~ own_i:post + nbr_i:post | unit + year, data = dd, cluster = ~unit)
  na <- feols(ly ~ own_a:post + nbr_a:post | unit + year, data = dd, cluster = ~unit)
  tidy2 <- function(mod, est) tibble(est = est, term = c("own", "neighbour"), beta = unname(coef(mod)[1:2]), se = unname(se(mod)[1:2]))
  bind_rows(
    tibble(est = "ORIV, own alone", term = "own", beta = coef(m1)[[1]], se = se(m1)[[1]]),
    tidy2(ni, "naive OLS, industry map"), tidy2(na, "naive OLS, average of maps"),
    tidy2(m, "ORIV, both terms") %>% mutate(first_stage_F = c(fs[[1]]$stat, fs[[2]]$stat))) %>%
    mutate(neighbour = label, lo = beta - 1.96 * se, hi = beta + 1.96 * se, p = 2 * pnorm(-abs(beta / se)))
}
res <- bind_rows(pooled("rof", "rest of field"), pooled("nco", "co-classification"))
write_csv(res, file.path(TAB_DIR, "oriv_spillovers.csv"))
print(res %>% select(neighbour, est, term, beta, se, lo, hi, p, first_stage_F) %>% mutate(across(where(is.double), ~ round(., 3))),
      n = Inf, width = Inf)

# event study, rest of field, ORIV both terms
ys <- setdiff(YEARS, 2021)
st <- stack(d, "rof")
for (k in ys) {
  st[[paste0("o_", k)]] <- st$own * (st$year == k); st[[paste0("n_", k)]] <- st$nbr * (st$year == k)
  st[[paste0("oz_", k)]] <- st$own_z * (st$year == k); st[[paste0("nz_", k)]] <- st$nbr_z * (st$year == k)
}
endo <- c(paste0("o_", ys), paste0("n_", ys)); inst <- c(paste0("oz_", ys), paste0("nz_", ys))
m <- feols(as.formula(paste("ly ~ 1 | unit^s + year^s |", paste(endo, collapse = "+"), "~", paste(inst, collapse = "+"))),
           data = st, cluster = ~unit)
pre <- function(pfx) wald(m, keep = paste0("^fit_", pfx, "_(201[5-9]|2020)$"), print = FALSE)$p
es <- broom::tidy(m, conf.int = TRUE) %>%
  mutate(year = as.integer(str_extract(term, "\\d{4}")), term = if_else(str_detect(term, "^fit_o_"), "own", "rest of field")) %>%
  bind_rows(tibble(year = 2021L, term = c("own", "rest of field"), estimate = 0, conf.low = 0, conf.high = 0)) %>%
  mutate(pre_p = if_else(term == "own", pre("o"), pre("n")))
write_csv(es, file.path(TAB_DIR, "oriv_spillovers_es.csv"))
print(es %>% select(term, year, estimate, conf.low, conf.high, pre_p) %>% arrange(term, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)
lab <- es %>% distinct(term, pre_p) %>% summarise(txt = paste(sprintf("%s pre-period joint p = %.2f", term, pre_p), collapse = "; "))
p <- ggplot(es, aes(year, estimate, colour = term)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.25) +
  scale_x_continuous(breaks = 2015:2025) + scale_colour_manual(values = c(own = "#0072B2", `rest of field` = "#D55E00")) +
  labs(x = "Filing year", y = "OLS log(1 + patents), per 10 pp of coverage", colour = NULL,
       subtitle = lab$txt,
       caption = paste("ORIV for both terms (each map instruments the other), IPC subclasses, subclass + year FE (interacted with the copy),",
                       "base 2021, 95% CIs clustered by subclass. Official IPC.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig52_oriv_spillovers_es.pdf"), p, width = 9, height = 5)
ggsave(file.path(FIG_DIR, "fig52_oriv_spillovers_es.png"), p, width = 9, height = 5, dpi = 150)
