# 18r_input_exposure.R: output vs input ban exposure at the industry level (rule IN1; session 5; note 15).
# Same 55 NACE 3-digit industries, outcome and estimator as 18q (PPML, industry + year FE, 2015-2025, base 2021,
# SEs clustered by industry). Output exposure = banned share of what the industry MAKES (script 28); input exposure =
# banned share of what it BUYS (BEA 2017 detailed use table, script 29c); variant without its own product group.
# Specs (each z-scored): output alone; input alone; input excl. own; output + input in one model.
# Pooled with RI (1,000 permutations; for the joint model the two exposures are permuted together across industries);
# event studies with pairs cluster bootstrap-t joint pre-test (B draws).
# Output: empirics/results/tables/input_exposure.csv, input_exposure_es.csv; fig58_input_exposure_es
source(here::here("empirics", "scripts", "00_setup.R"))
set.seed(20261124)
B <- 499; R <- 1000
pat <- read_csv(here("data", "clean", "industry_year_patents.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "industry_ban_coverage.csv"), show_col_types = FALSE)
inp <- read_csv(here("data", "clean", "industry_input_exposure.csv"), show_col_types = FALSE)
keep <- pat %>% filter(between(year, 2015, 2019)) %>% group_by(nace3) %>% summarise(pre = mean(n)) %>% filter(pre >= 10)
d0 <- pat %>% filter(between(year, 2015, 2025)) %>% complete(nace3, year = 2015:2025, fill = list(n = 0)) %>%
  inner_join(cov %>% filter(west_imports > 0, nace3 %in% keep$nace3), by = "nace3") %>%
  inner_join(inp, by = "nace3") %>%
  mutate(out = as.numeric(scale(coverage)), inp = as.numeric(scale(input_cov)), inx = as.numeric(scale(input_cov_exown)),
         post = as.integer(year >= 2022))
u0 <- distinct(d0, nace3, out, inp, inx)
cat("industries:", nrow(u0), "| corr(out, inp) =", round(cor(u0$out, u0$inp), 2), "\n")

SPECS <- list("output exposure alone" = "out", "input exposure alone" = "inp", "input exposure (excl. own products)" = "inx",
              "output + input together" = c("out", "inp"))
pooled_fml <- function(v) as.formula(paste("n ~", paste0(v, ":post", collapse = " + "), "| nace3 + year"))
es_fml <- function(v) as.formula(paste("n ~", paste0("i(year, ", v, ", ref = 2021)", collapse = " + "), "| nace3 + year"))
boot_pre <- function(d, f, var) {
  m <- fepois(f, data = d, cluster = ~nace3)
  rx <- paste0("^year::(201[5-9]|2020):", var, "$")
  k <- grep(rx, names(coef(m))); b <- coef(m)[k]
  W0 <- as.numeric(t(b) %*% solve(vcov(m)[k, k], b)) / length(k)
  ul <- unique(d$nace3); dl <- split(d, d$nace3)
  Ws <- replicate(B, {
    s <- sample(ul, replace = TRUE)
    dd <- bind_rows(lapply(seq_along(s), function(i) dl[[as.character(s[i])]] %>% mutate(nace3 = i)))
    tryCatch({
      mb <- fepois(f, data = dd, cluster = ~nace3); kb <- match(names(b), names(coef(mb)))
      if (anyNA(kb)) NA_real_ else { db <- coef(mb)[kb] - b; as.numeric(t(db) %*% solve(vcov(mb)[kb, kb], db)) / length(kb) }
    }, error = function(e) NA_real_)
  })
  list(m = m, p_wald = wald(m, keep = rx, print = FALSE)$p, p_boot = mean(Ws >= W0, na.rm = TRUE))
}
ri <- function(d, v, b0) {
  bs <- replicate(R, {
    perm <- u0[sample(nrow(u0)), v, drop = FALSE] %>% mutate(nace3 = u0$nace3)
    dd <- d %>% select(-all_of(v)) %>% inner_join(perm, by = "nace3")
    tryCatch(coef(fepois(pooled_fml(v), data = dd))[seq_along(v)], error = function(e) rep(NA_real_, length(v)))
  })
  bs <- matrix(bs, nrow = length(v))
  sapply(seq_along(v), function(j) mean(abs(bs[j, ]) >= abs(b0[j]), na.rm = TRUE))
}
rows <- list(); esl <- list()
for (sn in names(SPECS)) {
  v <- SPECS[[sn]]
  mp <- fepois(pooled_fml(v), data = d0, cluster = ~nace3)
  pri <- ri(d0, v, coef(mp))
  for (j in seq_along(v)) {
    r <- boot_pre(d0, es_fml(v), v[j])
    rows[[length(rows) + 1]] <- tibble(spec = sn, term = v[j], beta = coef(mp)[[j]], se = se(mp)[[j]], p = pvalue(mp)[[j]],
                                       p_ri = pri[j], pre_p_wald = r$p_wald, pre_p_boot = r$p_boot)
    esl[[length(esl) + 1]] <- broom::tidy(r$m, conf.int = TRUE) %>% filter(str_detect(term, paste0(":", v[j], "$"))) %>%
      mutate(year = as.integer(str_extract(term, "\\d{4}")), spec = sn, var = v[j])
  }
  cat(sn, "done\n")
}
res <- bind_rows(rows) %>% mutate(term = recode(term, out = "output exposure", inp = "input exposure", inx = "input exposure (excl. own)"))
es <- bind_rows(esl) %>% mutate(var = recode(var, out = "output exposure", inp = "input exposure", inx = "input exposure (excl. own)"))
write_csv(res, file.path(TAB_DIR, "input_exposure.csv")); write_csv(es, file.path(TAB_DIR, "input_exposure_es.csv"))
print(res %>% mutate(across(where(is.double), ~ round(., 4))), width = Inf)
print(es %>% select(spec, var, year, estimate, conf.low, conf.high) %>% arrange(spec, var, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf, width = Inf)

pd <- es %>% filter(spec %in% c("output exposure alone", "input exposure alone", "output + input together")) %>%
  mutate(lab = if_else(spec == "output + input together", paste0("together: ", var), paste0("alone: ", var))) %>%
  bind_rows(tibble(lab = c("alone: output exposure", "alone: input exposure", "together: output exposure", "together: input exposure"),
                   year = 2021L, estimate = 0, conf.low = 0, conf.high = 0)) %>%
  mutate(panel = if_else(str_starts(lab, "alone"), "A. Each exposure on its own", "B. Both exposures in one model"),
         var = str_remove(lab, "^(alone|together): "))
txt <- res %>% filter(term != "input exposure (excl. own)") %>%
  mutate(panel = if_else(spec == "output + input together", "B. Both exposures in one model", "A. Each exposure on its own")) %>%
  group_by(panel) %>% summarise(t = paste(sprintf("%s: %.3f (SE %.3f), RI p %.3f, pre p (boot) %.2f", term, beta, se, p_ri, pre_p_boot), collapse = "\n"))
p <- ggplot(pd, aes(year, estimate, colour = var)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.45), size = 0.22) +
  geom_text(data = txt, aes(x = 2014.6, y = -Inf, label = t), hjust = 0, vjust = -0.3, size = 2.7, inherit.aes = FALSE) +
  facet_wrap(~panel) + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("output exposure" = "#0072B2", "input exposure" = "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient (per SD of exposure)", colour = NULL,
       caption = paste("55 NACE 3-digit manufacturing industries, industry + year FE, base 2021, 95% CIs clustered by industry.",
                       "Output exposure: banned share of what the industry makes;\ninput exposure: banned share of what it buys",
                       "(BEA 2017 detailed use table as proxy for input structure). Official IPC, Dorner-Harhoff IPC -> industry.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig58_input_exposure_es.pdf"), p, width = 12, height = 5.6)
ggsave(file.path(FIG_DIR, "fig58_input_exposure_es.png"), p, width = 12, height = 5.6, dpi = 150)
