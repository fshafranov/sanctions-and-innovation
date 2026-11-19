# 18p_dualuse_2014.R: the 2014 sanctions as treatment, with dual-use exposure (rule DU1; session 5; note 11 end).
# (A) 2014 event studies, 2005-2021 (stops before the 2022 bans), base 2013, PPML, 35 fields, field + year FE,
#     SEs clustered by field; joint pre-test 2005-2012: clustered Wald and pairs cluster bootstrap-t (B draws).
#     Exposure (z-scored): dual-use broad (main), dual-use narrow, dual-use broad + oil list in one model.
#     Pooled: Exposure x 1[2014-2017] and Exposure x 1[2018-2021] vs 2005-2013.
# (B) Does 2014 exposure explain the 2015-21 drift of the main 2022 design? 2015-2025, base 2021, Ban2022 event study
#     with and without dual-use-broad x year; joint pre-test (Ban x 2015-2020) clustered and bootstrap-t.
# Output: output/tables/dualuse_2014_es.csv, dualuse_2014_tests.csv; fig56_dualuse_2014
source(here::here("scripts", "analysis", "00_setup.R"))
set.seed(20261122)
B <- 499
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE)
du <- read_csv(here("data", "clean", "field_dualuse_2014.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>% filter(sample == "manuf")
expo <- function(mp) du %>% filter(map == mp) %>%
  inner_join(cov %>% filter(map == mp, event == "oil2014", year == 2014) %>% select(field, oil = coverage), by = "field") %>%
  inner_join(cov %>% filter(map == mp, event == "eu2022", year == 2023) %>% select(field, ban = coverage), by = "field") %>%
  mutate(across(c(du_broad, du_narrow, oil, ban), ~ as.numeric(scale(.))))

boot_pre <- function(d, f, var, pre) {
  m <- fepois(f, data = d, cluster = ~field)
  k <- grep(paste0("^year::(", paste(pre, collapse = "|"), "):", var, "$"), names(coef(m)))
  b <- coef(m)[k]; W0 <- as.numeric(t(b) %*% solve(vcov(m)[k, k], b)) / length(k)
  fl <- unique(d$field); dl <- split(d, d$field)
  Ws <- replicate(B, {
    s <- sample(fl, replace = TRUE)
    dd <- bind_rows(lapply(seq_along(s), function(i) dl[[as.character(s[i])]] %>% mutate(field = i)))
    tryCatch({
      mb <- fepois(f, data = dd, cluster = ~field); kb <- match(names(b), names(coef(mb)))
      if (anyNA(kb)) NA_real_ else { db <- coef(mb)[kb] - b; as.numeric(t(db) %*% solve(vcov(mb)[kb, kb], db)) / length(kb) }
    }, error = function(e) NA_real_)
  })
  list(m = m, p_wald = wald(m, keep = paste0("^year::(", paste(pre, collapse = "|"), "):", var, "$"), print = FALSE)$p,
       p_boot = mean(Ws >= W0, na.rm = TRUE))
}

# ---- (A) 2014 ----
specsA <- list("dual-use (broad)" = "du_broad", "dual-use (narrow)" = "du_narrow", "dual-use (broad) + oil list" = c("du_broad", "oil"))
esA <- list(); tests <- list(); pooled <- list()
for (mp in c("industry", "text")) {
  d <- pat %>% filter(between(year, 2005, 2021)) %>% inner_join(expo(mp), by = "field") %>%
    mutate(p1 = as.integer(between(year, 2014, 2017)), p2 = as.integer(between(year, 2018, 2021)))
  for (sn in names(specsA)) {
    v <- specsA[[sn]]
    f <- as.formula(paste("n_frac ~", paste0("i(year, ", v, ", ref = 2013)", collapse = " + "), "| field + year"))
    r <- boot_pre(d, f, v[1], 2005:2012)
    esA[[length(esA) + 1]] <- broom::tidy(r$m, conf.int = TRUE) %>% filter(str_detect(term, paste0(":", v[1], "$"))) %>%
      mutate(year = as.integer(str_extract(term, "\\d{4}")), map = mp, spec = sn)
    fp <- as.formula(paste("n_frac ~", paste0(v, ":p1 + ", v, ":p2", collapse = " + "), "| field + year"))
    mp0 <- fepois(fp, data = d, cluster = ~field)
    k <- grep(paste0("^", v[1], ":p"), names(coef(mp0)))
    pooled[[length(pooled) + 1]] <- tibble(part = "A", map = mp, spec = sn, term = c("2014-2017", "2018-2021"),
                                           beta = coef(mp0)[k], se = se(mp0)[k])
    tests[[length(tests) + 1]] <- tibble(part = "A", map = mp, spec = sn, pre_window = "2005-2012",
                                         p_wald = r$p_wald, p_boot = r$p_boot)
    cat("A", mp, sn, "done\n")
  }
}

# ---- (B) main 2022 design with 2014 dual-use exposure x year ----
esB <- list()
for (mp in c("industry", "text")) {
  d <- pat %>% filter(between(year, 2015, 2025)) %>% inner_join(expo(mp), by = "field")
  for (sn in c("Ban 2022 alone", "Ban 2022 + dual-use 2014 x year")) {
    f <- if (sn == "Ban 2022 alone") n_frac ~ i(year, ban, ref = 2021) | field + year else
      n_frac ~ i(year, ban, ref = 2021) + i(year, du_broad, ref = 2021) | field + year
    r <- boot_pre(d, f, "ban", 2015:2020)
    esB[[length(esB) + 1]] <- broom::tidy(r$m, conf.int = TRUE) %>% filter(str_detect(term, ":ban$")) %>%
      mutate(year = as.integer(str_extract(term, "\\d{4}")), map = mp, spec = sn)
    mpool <- fepois(update(f, . ~ . ), data = d %>% mutate(post = as.integer(year >= 2022)), cluster = ~field)
    tests[[length(tests) + 1]] <- tibble(part = "B", map = mp, spec = sn, pre_window = "2015-2020",
                                         p_wald = r$p_wald, p_boot = r$p_boot)
    cat("B", mp, sn, "done\n")
  }
}
es <- bind_rows(bind_rows(esA) %>% mutate(part = "A"), bind_rows(esB) %>% mutate(part = "B"))
tests <- bind_rows(tests)
pooled <- bind_rows(pooled) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se, p = 2 * pnorm(-abs(beta / se)))
write_csv(es %>% select(part, map, spec, year, estimate, std.error, conf.low, conf.high), file.path(TAB_DIR, "dualuse_2014_es.csv"))
write_csv(bind_rows(tests, pooled), file.path(TAB_DIR, "dualuse_2014_tests.csv"))
print(tests %>% mutate(across(where(is.double), ~ round(., 3))), width = Inf)
print(pooled %>% mutate(across(where(is.double), ~ round(., 3))), width = Inf)
print(es %>% select(part, map, spec, year, estimate, conf.low, conf.high) %>% arrange(part, map, spec, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf, width = Inf)

base <- tibble(year = c(2013L, 2021L), part = c("A", "B"))
pd <- es %>% bind_rows(expand_grid(map = c("industry", "text"), spec = names(specsA)) %>% mutate(part = "A", year = 2013L),
                       expand_grid(map = c("industry", "text"), spec = c("Ban 2022 alone", "Ban 2022 + dual-use 2014 x year")) %>%
                         mutate(part = "B", year = 2021L)) %>%
  mutate(estimate = coalesce(estimate, 0), conf.low = coalesce(conf.low, 0), conf.high = coalesce(conf.high, 0),
         map = recode(map, industry = "industry map", text = "product-name map"),
         panel = if_else(part == "A", paste0("A. 2014 dual-use exposure, ", map), paste0("B. 2022 ban coverage, ", map)))
lab <- tests %>% mutate(map = recode(map, industry = "industry map", text = "product-name map"),
                        panel = if_else(part == "A", paste0("A. 2014 dual-use exposure, ", map), paste0("B. 2022 ban coverage, ", map))) %>%
  group_by(panel) %>% summarise(txt = paste(sprintf("%s: pre p boot %.2f", spec, p_boot), collapse = "\n"))
p <- ggplot(pd, aes(year, estimate, colour = spec)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(data = tibble(panel = unique(pd$panel)) %>% mutate(x = if_else(str_starts(panel, "A"), 2013.5, 2021.5)),
             aes(xintercept = x), linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.6), size = 0.15) +
  geom_text(data = lab, aes(x = -Inf, y = -Inf, label = txt), hjust = -0.02, vjust = -0.2, size = 2.6, inherit.aes = FALSE) +
  facet_wrap(~panel, scales = "free", ncol = 2) + scale_x_continuous(breaks = scales::breaks_width(2)) +
  scale_colour_manual(values = c("dual-use (broad)" = "#0072B2", "dual-use (narrow)" = "#56B4E9",
                                 "dual-use (broad) + oil list" = "#009E73", "Ban 2022 alone" = "grey55",
                                 "Ban 2022 + dual-use 2014 x year" = "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient (per SD of exposure)", colour = NULL,
       caption = paste("35 WIPO fields, field + year FE; A: 2005-2021, base 2013; B: 2015-2025, base 2021. 95% CIs clustered by field;",
                       "pre-test p from a pairs cluster bootstrap-t. Official IPC.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig56_dualuse_2014.pdf"), p, width = 12, height = 8)
ggsave(file.path(FIG_DIR, "fig56_dualuse_2014.png"), p, width = 12, height = 8, dpi = 150)
