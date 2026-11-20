# 18m_prewar_controls.R: pre-war field characteristics x year as controls, and small-cluster-robust joint pre-tests
# (session 5; note 14). Specification fixed before estimation (rule PC1, notes/data_decisions.md).
# Main model: PPML, 35 WIPO fields, field + year FE, Ban_f (end-2023 EU coverage, z-scored), official IPC, 2015-2025,
# SEs clustered by field. Controls (z-scored, each interacted with year dummies, base 2021; script 26):
#   univ_share (2015-19), west_share (Western share of total imports 2019-21, same map as Ban), foreign_share
#   (2015-19), size (log patents 2015-19); each alone and all four together.
# Joint pre-test (Ban x 2015..2020 = 0), three versions:
#   (1) standard clustered Wald (PPML)
#   (2) PPML pairs cluster bootstrap-t: resample fields, W* = (b* - b)' V*^-1 (b* - b) / 6, p = share of W* >= W
#   (3) OLS log(1 + n): standard Wald and wild cluster restricted bootstrap (null imposed, Webb weights by field)
# Output: empirics/results/tables/prewar_controls.csv, prewar_controls_es.csv; fig54_prewar_controls_es
source(here::here("empirics", "scripts", "00_setup.R"))
set.seed(20261120)
B <- 499
pat <- read_csv(here("data", "processed", "official_ipc_panels", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(between(year, 2015, 2025))
cov <- read_csv(here("data", "processed", "ban_coverage", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023) %>% select(field, map, coverage)
chr <- read_csv(here("data", "processed", "prewar_characteristics", "field_prewar_characteristics.csv"), show_col_types = FALSE)
CTRL <- c("univ_share", "west_share", "foreign_share", "size")
SPECS <- list("no controls" = character(0), "university share" = "univ_share", "Western import share" = "west_share",
              "foreign-holder share" = "foreign_share", "size" = "size", "all four" = CTRL)
PRE <- 2015:2020; POST <- 2022:2025

panel <- function(mp) {
  x <- cov %>% filter(map == mp) %>% inner_join(chr %>% filter(map == mp) %>% select(-map), by = "field") %>%
    mutate(ban = as.numeric(scale(coverage)), across(all_of(CTRL), ~ as.numeric(scale(.))))
  pat %>% inner_join(x, by = "field") %>% mutate(post = as.integer(year >= 2022), ly = log1p(n_frac))
}
ctrl_terms <- function(cs) if (length(cs)) paste0(" + ", paste0("i(year, ", cs, ", ref = 2021)", collapse = " + ")) else ""
pre_idx <- function(m) grep(paste0("^year::(", paste(PRE, collapse = "|"), "):ban$"), names(coef(m)))
wald_pre <- function(m, b0 = 0) {
  k <- pre_idx(m); b <- coef(m)[k] - b0; V <- vcov(m)[k, k]
  as.numeric(t(b) %*% solve(V, b)) / length(k)
}

boot_ppml <- function(d, f, W0, b_hat) {
  fl <- unique(d$field); dl <- split(d, d$field)
  Ws <- replicate(B, {
    s <- sample(fl, replace = TRUE)
    dd <- bind_rows(lapply(seq_along(s), function(i) dl[[as.character(s[i])]] %>% mutate(field = i)))
    tryCatch({
      m <- fepois(f, data = dd, cluster = ~field)
      if (length(pre_idx(m)) < length(PRE)) NA_real_ else wald_pre(m, b_hat)
    }, error = function(e) NA_real_)
  })
  c(p = mean(Ws >= W0, na.rm = TRUE), n_ok = sum(!is.na(Ws)))
}
webb <- c(-sqrt(1.5), -1, -sqrt(0.5), sqrt(0.5), 1, sqrt(1.5))
wcr_ols <- function(d, cs) {
  for (k in POST) d[[paste0("bp", k)]] <- d$ban * (d$year == k)
  fu <- as.formula(paste0("ly ~ i(year, ban, ref = 2021)", ctrl_terms(cs), " | field + year"))
  fr <- as.formula(paste0("ly ~ ", paste0("bp", POST, collapse = " + "), ctrl_terms(cs), " | field + year"))
  mu <- feols(fu, data = d, cluster = ~field); W0 <- wald_pre(mu)
  mr <- feols(fr, data = d)
  fit_r <- fitted(mr); e_r <- resid(mr); g <- match(d$field, unique(d$field))
  Ws <- replicate(B, {
    w <- sample(webb, length(unique(g)), replace = TRUE)
    d$ly <- fit_r + w[g] * e_r
    wald_pre(feols(fu, data = d, cluster = ~field))
  })
  c(p_std = wald(mu, keep = paste0("^year::(", paste(PRE, collapse = "|"), "):ban$"), print = FALSE)$p,
    p_wcr = mean(Ws >= W0))
}

rows <- list(); esl <- list()
for (mp in c("industry", "text")) {
  d <- panel(mp)
  for (sn in names(SPECS)) {
    cs <- SPECS[[sn]]
    fp <- as.formula(paste0("n_frac ~ ban:post", ctrl_terms(cs), " | field + year"))
    fe <- as.formula(paste0("n_frac ~ i(year, ban, ref = 2021)", ctrl_terms(cs), " | field + year"))
    mp0 <- fepois(fp, data = d, cluster = ~field)
    me <- fepois(fe, data = d, cluster = ~field)
    W0 <- wald_pre(me)
    w_std <- wald(me, keep = paste0("^year::(", paste(PRE, collapse = "|"), "):ban$"), print = FALSE)$p
    bt <- boot_ppml(d, fe, W0, coef(me)[pre_idx(me)])
    ol <- wcr_ols(d, cs)
    k <- grep("ban:post", names(coef(mp0)))
    rows[[length(rows) + 1]] <- tibble(map = mp, controls = sn, beta = coef(mp0)[[k]], se = se(mp0)[[k]],
      p = pvalue(mp0)[[k]], pre_p_ppml_wald = w_std, pre_p_ppml_boot_t = bt[["p"]], boot_ok = bt[["n_ok"]],
      pre_p_ols_wald = ol[["p_std"]], pre_p_ols_wcr = ol[["p_wcr"]])
    esl[[length(esl) + 1]] <- broom::tidy(me, conf.int = TRUE) %>% filter(str_detect(term, ":ban$")) %>%
      mutate(year = as.integer(str_extract(term, "\\d{4}")), map = mp, controls = sn)
    cat(mp, "|", sn, "done\n")
  }
}
res <- bind_rows(rows)
es <- bind_rows(esl) %>% bind_rows(expand_grid(map = c("industry", "text"), controls = names(SPECS)) %>%
                                     mutate(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0))
write_csv(res, file.path(TAB_DIR, "prewar_controls.csv"))
write_csv(es %>% select(map, controls, year, estimate, std.error, conf.low, conf.high), file.path(TAB_DIR, "prewar_controls_es.csv"))
print(res %>% mutate(across(where(is.double), ~ round(., 3))), n = Inf, width = Inf)
print(es %>% filter(controls %in% c("no controls", "university share", "all four")) %>%
        select(map, controls, year, estimate, conf.low, conf.high) %>% arrange(map, controls, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)

lab <- res %>% mutate(txt = sprintf("pre-test p: Wald %.3f, bootstrap %.2f", pre_p_ppml_wald, pre_p_ppml_boot_t))
pd <- es %>% filter(controls %in% c("no controls", "university share", "Western import share", "all four")) %>%
  mutate(controls = factor(controls, c("no controls", "university share", "Western import share", "all four")),
         map = recode(map, industry = "Industry map (main)", text = "Product-name map"))
p <- ggplot(pd, aes(year, estimate, colour = controls)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.6), size = 0.18) +
  facet_wrap(~map) + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("grey55", "#009E73", "#E69F00", "#0072B2")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (per SD)", colour = "Pre-war controls x year:",
       caption = paste("35 WIPO fields, field + year FE, base 2021, 95% CIs clustered by field; controls z-scored and interacted",
                       "with year dummies. Official IPC.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig54_prewar_controls_es.pdf"), p, width = 12, height = 5)
ggsave(file.path(FIG_DIR, "fig54_prewar_controls_es.png"), p, width = 12, height = 5, dpi = 150)
