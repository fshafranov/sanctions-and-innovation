# 18q_industry_design.R: the main test at the industry level (rule IND1; session 5; note 15).
# Unit: NACE Rev. 2 3-digit manufacturing industry (>= 10 patents/yr 2015-19, positive Western imports; script 28).
# Outcome: domestic invention patents assigned to industries through the Dorner-Harhoff IPC subclass -> industry table.
# Treatment: EU ban coverage (end-2023) of the industry's 2019-21 Western imports (HS -> ISIC -> NACE), z-scored.
# PPML, 2015-2025, base 2021, SEs clustered by industry. FE: industry + year (main); industry + division x year.
# Pooled Ban x Post with randomization inference (1,000 permutations of coverage across industries); event study
# with pairs cluster bootstrap-t joint pre-test (B draws).
# Output: empirics/results/tables/industry_design.csv, industry_design_es.csv; fig57_industry_es
source(here::here("empirics", "scripts", "00_setup.R"))
set.seed(20261123)
B <- 499; R <- 1000
pat <- read_csv(here("data", "clean", "industry_year_patents.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "industry_ban_coverage.csv"), show_col_types = FALSE)
keep <- pat %>% filter(between(year, 2015, 2019)) %>% group_by(nace3) %>% summarise(pre = mean(n)) %>% filter(pre >= 10)
d0 <- pat %>% filter(between(year, 2015, 2025)) %>% complete(nace3, year = 2015:2025, fill = list(n = 0)) %>%
  inner_join(cov %>% filter(west_imports > 0, nace3 %in% keep$nace3), by = "nace3") %>%
  mutate(ban = as.numeric(scale(coverage)), post = as.integer(year >= 2022))
cat("industries:", n_distinct(d0$nace3), "| divisions:", n_distinct(d0$division), "| SD coverage:", round(sd(distinct(d0, nace3, coverage)$coverage), 3), "\n")

FES <- c("industry + year" = "nace3 + year", "industry + division x year" = "nace3 + division^year")
boot_pre <- function(d, f) {
  m <- fepois(f, data = d, cluster = ~nace3)
  k <- grep("^year::(201[5-9]|2020):ban$", names(coef(m)))
  b <- coef(m)[k]; W0 <- as.numeric(t(b) %*% solve(vcov(m)[k, k], b)) / length(k)
  ul <- unique(d$nace3); dl <- split(d, d$nace3)
  Ws <- replicate(B, {
    s <- sample(ul, replace = TRUE)
    dd <- bind_rows(lapply(seq_along(s), function(i) dl[[as.character(s[i])]] %>% mutate(nace3 = i)))
    tryCatch({
      mb <- fepois(f, data = dd, cluster = ~nace3); kb <- match(names(b), names(coef(mb)))
      if (anyNA(kb)) NA_real_ else { db <- coef(mb)[kb] - b; as.numeric(t(db) %*% solve(vcov(mb)[kb, kb], db)) / length(kb) }
    }, error = function(e) NA_real_)
  })
  list(m = m, p_wald = wald(m, keep = "^year::(201[5-9]|2020):ban$", print = FALSE)$p, p_boot = mean(Ws >= W0, na.rm = TRUE))
}
ri <- function(d, fe, b0) {
  u <- distinct(d, nace3, ban)
  bs <- replicate(R, {
    perm <- u %>% mutate(ban = sample(ban))
    dd <- d %>% select(-ban) %>% inner_join(perm, by = "nace3")
    tryCatch(coef(fepois(as.formula(paste("n ~ ban:post |", fe)), data = dd))[[1]], error = function(e) NA_real_)
  })
  mean(abs(bs) >= abs(b0), na.rm = TRUE)
}
res <- list(); esl <- list()
for (nm in names(FES)) {
  fe <- FES[[nm]]
  mp <- fepois(as.formula(paste("n ~ ban:post |", fe)), data = d0, cluster = ~nace3)
  r <- boot_pre(d0, as.formula(paste("n ~ i(year, ban, ref = 2021) |", fe)))
  pri <- ri(d0, fe, coef(mp)[[1]])  # computed outside tibble(): inside it, `fe` would refer to the new column
  res[[nm]] <- tibble(fe = nm, beta = coef(mp)[[1]], se = se(mp)[[1]], p = pvalue(mp)[[1]], p_ri = pri,
                      pre_p_wald = r$p_wald, pre_p_boot = r$p_boot, n_ind = n_distinct(d0$nace3))
  esl[[nm]] <- broom::tidy(r$m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}")), fe = nm)
  cat(nm, "done\n")
}
# robustness (same FE as main): OLS log(1+n); leave-one-division-out range
ols <- feols(log1p(n) ~ ban:post | nace3 + year, data = d0, cluster = ~nace3)
lodo <- map_dfr(unique(d0$division), function(dv) {
  dd <- d0 %>% filter(division != dv) %>% mutate(ban = as.numeric(scale(coverage)))
  m <- fepois(n ~ ban:post | nace3 + year, data = dd, cluster = ~nace3)
  tibble(dropped_division = dv, beta = coef(m)[[1]], se = se(m)[[1]])
})
out <- bind_rows(res) %>% bind_rows(tibble(fe = "OLS log(1+n), industry + year", beta = coef(ols)[[1]], se = se(ols)[[1]],
                                           p = pvalue(ols)[[1]], n_ind = n_distinct(d0$nace3)))
es <- bind_rows(esl) %>% bind_rows(tibble(fe = names(FES), year = 2021L, estimate = 0, conf.low = 0, conf.high = 0))
write_csv(out, file.path(TAB_DIR, "industry_design.csv")); write_csv(es, file.path(TAB_DIR, "industry_design_es.csv"))
write_csv(lodo, file.path(TAB_DIR, "industry_design_lodo.csv"))
print(out %>% mutate(across(where(is.double), ~ round(., 4))), width = Inf)
print(es %>% select(fe, year, estimate, conf.low, conf.high) %>% arrange(fe, year) %>% mutate(across(where(is.double), ~ round(., 3))), n = Inf)
cat("leave-one-division-out: range", round(range(lodo$beta), 3), "| all CI below 0:", all(lodo$beta + 1.96 * lodo$se < 0), "\n")
print(lodo %>% arrange(beta) %>% mutate(across(where(is.double), ~ round(., 3))) %>% slice(c(1:3, (n() - 2):n())))

lab <- out %>% filter(fe %in% names(FES)) %>%
  mutate(txt = sprintf("%s: %.3f (SE %.3f), RI p = %.3f; pre-test p (bootstrap) = %.2f", fe, beta, se, p_ri, pre_p_boot))
p <- ggplot(es, aes(year, estimate, colour = fe)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.3) +
  scale_x_continuous(breaks = 2015:2025) + scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (per SD)", colour = "Fixed effects:",
       caption = paste0(n_distinct(d0$nace3), " NACE 3-digit manufacturing industries; patents assigned via Dorner-Harhoff IPC -> industry ",
                        "table; base 2021; 95% CIs clustered by industry.\nPooled post-2022: ", paste(lab$txt, collapse = "\n"))) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig57_industry_es.pdf"), p, width = 9, height = 5.6)
ggsave(file.path(FIG_DIR, "fig57_industry_es.png"), p, width = 9, height = 5.6, dpi = 150)
