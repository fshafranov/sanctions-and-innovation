# 18n_bootstrap_es.R: the main field event study (fig38a) with small-cluster-robust inference (session 5; note 14).
# PPML, 35 WIPO fields, field + year FE, Ban_f z-scored (end-2023 EU coverage), base 2021, official IPC, 2015-2025.
# Pairs cluster bootstrap-t (resample fields with replacement, B = 999): for each coefficient
#   t* = (b* - b) / se*(clustered);  95% CI = [b - q(0.975, t*) * se, b - q(0.025, t*) * se]   (percentile-t)
# and the joint pre-test (2015-2020 = 0) as W* = (b* - b)' V*^-1 (b* - b) / 6 vs the sample W.
# Point estimates are unchanged; only the intervals and the joint p-value differ from fig38a.
# Output: output/tables/bootstrap_es.csv; fig38b_fields_official_es_boot
source(here::here("empirics", "scripts", "00_setup.R"))
set.seed(20261121)
B <- 999
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(between(year, 2015, 2025))
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
f <- n_frac ~ i(year, ban, ref = 2021) | field + year

out <- list(); jp <- list()
for (mp in c("industry", "text")) {
  d <- pat %>% inner_join(cov %>% filter(map == mp) %>% transmute(field, ban = as.numeric(scale(coverage))), by = "field")
  m <- fepois(f, data = d, cluster = ~field)
  b <- coef(m); s <- se(m); pre <- grep("201[5-9]|2020", names(b))
  W0 <- as.numeric(t(b[pre]) %*% solve(vcov(m)[pre, pre], b[pre])) / length(pre)
  fl <- unique(d$field); dl <- split(d, d$field)
  draws <- replicate(B, {
    smp <- sample(fl, replace = TRUE)
    dd <- bind_rows(lapply(seq_along(smp), function(i) dl[[as.character(smp[i])]] %>% mutate(field = i)))
    r <- tryCatch({
      mb <- fepois(f, data = dd, cluster = ~field)
      bb <- coef(mb)[names(b)]; ss <- se(mb)[names(b)]
      W <- as.numeric(t(bb[pre] - b[pre]) %*% solve(vcov(mb)[names(b), names(b)][pre, pre], bb[pre] - b[pre])) / length(pre)
      c((bb - b) / ss, W = W)
    }, error = function(e) rep(NA_real_, length(b) + 1))
    r
  })
  ok <- colSums(is.na(draws)) == 0
  tq <- apply(draws[seq_along(b), ok, drop = FALSE], 1, quantile, probs = c(0.025, 0.975))
  out[[mp]] <- tibble(map = mp, term = names(b), year = as.integer(str_extract(names(b), "\\d{4}")), estimate = b,
                      se = s, lo_cluster = b - 1.96 * s, hi_cluster = b + 1.96 * s,
                      lo_boot = b - tq[2, ] * s, hi_boot = b - tq[1, ] * s)
  jp[[mp]] <- tibble(map = mp, W = W0, p_wald = wald(m, keep = "201[5-9]|2020", print = FALSE)$p,
                     p_boot = mean(draws["W", ok] >= W0), draws_ok = sum(ok))
}
es <- bind_rows(out); jt <- bind_rows(jp)
write_csv(es, file.path(TAB_DIR, "bootstrap_es.csv")); write_csv(jt, file.path(TAB_DIR, "bootstrap_es_pretest.csv"))
print(es %>% select(map, year, estimate, lo_cluster, hi_cluster, lo_boot, hi_boot) %>% mutate(across(where(is.double), ~ round(., 3))), n = Inf)
print(jt)

pd <- es %>% bind_rows(tibble(map = c("industry", "text"), year = 2021L, estimate = 0, lo_boot = 0, hi_boot = 0)) %>%
  mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map"))
sub <- paste0("Joint pre-test (2015-20 = 0), cluster bootstrap-t: p = ",
              sprintf("%.2f", jt$p_boot[jt$map == "industry"]), " (industry map), ",
              sprintf("%.2f", jt$p_boot[jt$map == "text"]), " (product-name map)")
p <- ggplot(pd, aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = lo_boot, ymax = hi_boot), position = position_dodge(0.4), size = 0.3) +
  scale_x_continuous(breaks = 2015:2025) + scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (per SD)", colour = NULL,
       caption = paste0("35 WIPO technology fields, field + year FE, base 2021. 95% CIs: pairs cluster bootstrap-t over fields (",
                        B, " draws).\n", sub, ".\nDomestic invention patents, official IPC (Rospatent API), fractional counts.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig38b_fields_official_es_boot.pdf"), p, width = 8, height = 5.2)
ggsave(file.path(FIG_DIR, "fig38b_fields_official_es_boot.png"), p, width = 8, height = 5.2, dpi = 150)
