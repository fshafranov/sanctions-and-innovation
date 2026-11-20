# 18s_rosstat_input_exposure.R: Russia-specific input exposure (Rosstat 2021 input-output tables) at the industry
# level (rule RU1; session 5; note 15). Same 55 NACE 3-digit industries and outcome as 18q; PPML, industry + year FE,
# 2015-2025, base 2021, exposures z-scored.
#   dep  = share of the industry's manufactured inputs that were Western imports later banned (main)
#   sh   = banned share of its Western imported inputs (variant)
#   west = Western import dependence regardless of bans (control)
#   out  = output exposure (banned share of what it makes; script 28)
# Treatment varies at the level of 32 Rosstat industry columns: SEs clustered by column (main) and by industry;
# RI permutes column-level exposure across columns (1,000 draws); bootstrap pre-test resamples columns (B draws).
# Output: empirics/results/tables/rosstat_input.csv, rosstat_input_es.csv; fig59_rosstat_input_es
source(here::here("empirics", "scripts", "00_setup.R"))
set.seed(20261125)
B <- 499; R <- 1000
pat <- read_csv(here("data", "clean", "industry_year_patents.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "industry_ban_coverage.csv"), show_col_types = FALSE)
ru <- read_csv(here("data", "clean", "industry_input_exposure_ru.csv"), show_col_types = FALSE)
keep <- pat %>% filter(between(year, 2015, 2019)) %>% group_by(nace3) %>% summarise(pre = mean(n)) %>% filter(pre >= 10)
d0 <- pat %>% filter(between(year, 2015, 2025)) %>% complete(nace3, year = 2015:2025, fill = list(n = 0)) %>%
  inner_join(cov %>% filter(west_imports > 0, nace3 %in% keep$nace3), by = "nace3") %>%
  inner_join(ru, by = "nace3") %>%
  mutate(out = as.numeric(scale(coverage)), dep = as.numeric(scale(dep)), sh = as.numeric(scale(sh)),
         west = as.numeric(scale(west)), post = as.integer(year >= 2022), col = as.integer(factor(rs_col)))
cat("industries:", n_distinct(d0$nace3), "| Rosstat columns (clusters):", n_distinct(d0$col), "\n")

SPECS <- list("dep alone (main)" = "dep", "sh alone" = "sh", "dep + west" = c("dep", "west"), "dep + output exposure" = c("dep", "out"))
pf <- function(v) as.formula(paste("n ~", paste0(v, ":post", collapse = " + "), "| nace3 + year"))
ef <- function(v) as.formula(paste("n ~", paste0("i(year, ", v, ", ref = 2021)", collapse = " + "), "| nace3 + year"))
colvars <- c("dep", "sh", "west")
boot_pre <- function(f, var) {
  m <- fepois(f, data = d0, cluster = ~col)
  rx <- paste0("^year::(201[5-9]|2020):", var, "$"); k <- grep(rx, names(coef(m))); b <- coef(m)[k]
  W0 <- as.numeric(t(b) %*% solve(vcov(m)[k, k], b)) / length(k)
  cl <- unique(d0$col); dl <- split(d0, d0$col)
  Ws <- replicate(B, {
    s <- sample(cl, replace = TRUE)
    dd <- bind_rows(lapply(seq_along(s), function(i) dl[[as.character(s[i])]] %>% mutate(col = i, nace3 = nace3 * 1000 + i)))
    tryCatch({
      mb <- fepois(f, data = dd, cluster = ~col); kb <- match(names(b), names(coef(mb)))
      if (anyNA(kb)) NA_real_ else { db <- coef(mb)[kb] - b; as.numeric(t(db) %*% solve(vcov(mb)[kb, kb], db)) / length(kb) }
    }, error = function(e) NA_real_)
  })
  list(m = m, p_wald = wald(m, keep = rx, print = FALSE)$p, p_boot = mean(Ws >= W0, na.rm = TRUE))
}
ri <- function(v, b0) {
  uc <- distinct(d0, col, across(all_of(intersect(v, colvars))))
  bs <- replicate(R, {
    dd <- d0
    if (nrow(uc) > 0 && length(intersect(v, colvars))) {
      perm <- uc[sample(nrow(uc)), intersect(v, colvars), drop = FALSE] %>% mutate(col = uc$col)
      dd <- dd %>% select(-all_of(intersect(v, colvars))) %>% inner_join(perm, by = "col")
    }
    tryCatch(coef(fepois(pf(v), data = dd))[seq_along(v)], error = function(e) rep(NA_real_, length(v)))
  })
  bs <- matrix(bs, nrow = length(v))
  sapply(seq_along(v), function(j) if (v[j] %in% colvars) mean(abs(bs[j, ]) >= abs(b0[j]), na.rm = TRUE) else NA_real_)
}
rows <- list(); esl <- list()
for (sn in names(SPECS)) {
  v <- SPECS[[sn]]
  mp <- fepois(pf(v), data = d0, cluster = ~col)
  pri <- ri(v, coef(mp))
  for (j in seq_along(v)) {
    r <- boot_pre(ef(v), v[j])
    rows[[length(rows) + 1]] <- tibble(spec = sn, term = v[j], beta = coef(mp)[[j]], se_col = se(mp)[[j]],
      se_ind = se(mp, cluster = ~nace3)[[j]], p_col = pvalue(mp)[[j]], p_ri = pri[j], pre_p_wald = r$p_wald, pre_p_boot = r$p_boot)
    esl[[length(esl) + 1]] <- broom::tidy(r$m, conf.int = TRUE) %>% filter(str_detect(term, paste0(":", v[j], "$"))) %>%
      mutate(year = as.integer(str_extract(term, "\\d{4}")), spec = sn, var = v[j])
  }
  cat(sn, "done\n")
}
res <- bind_rows(rows); es <- bind_rows(esl)
write_csv(res, file.path(TAB_DIR, "rosstat_input.csv")); write_csv(es, file.path(TAB_DIR, "rosstat_input_es.csv"))
print(res %>% mutate(across(where(is.double), ~ round(., 4))), width = Inf)
print(es %>% select(spec, var, year, estimate, conf.low, conf.high) %>% arrange(spec, var, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf, width = Inf)

lab <- c(dep = "Western banned inputs (share of all inputs)", sh = "banned share of Western inputs",
         west = "Western import dependence", out = "output exposure")
pd <- es %>% filter(spec %in% c("dep alone (main)", "dep + west")) %>%
  bind_rows(tibble(spec = c("dep alone (main)", "dep + west", "dep + west"), var = c("dep", "dep", "west"), year = 2021L,
                   estimate = 0, conf.low = 0, conf.high = 0)) %>%
  mutate(var = lab[var], spec = recode(spec, "dep alone (main)" = "A. Banned Western inputs alone",
                                       "dep + west" = "B. With Western import dependence as control"))
txt <- res %>% filter(spec %in% c("dep alone (main)", "dep + west")) %>%
  mutate(spec = recode(spec, "dep alone (main)" = "A. Banned Western inputs alone", "dep + west" = "B. With Western import dependence as control")) %>%
  group_by(spec) %>% summarise(t = paste(sprintf("%s: %.3f (SE %.3f), RI p %.3f, pre p (boot) %.2f", lab[term], beta, se_col, p_ri, pre_p_boot), collapse = "\n"))
p <- ggplot(pd, aes(year, estimate, colour = var)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.45), size = 0.22) +
  geom_text(data = txt, aes(x = 2014.6, y = -Inf, label = t), hjust = 0, vjust = -0.3, size = 2.7, inherit.aes = FALSE) +
  facet_wrap(~spec) + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("#D55E00", "grey50")) +
  labs(x = "Filing year", y = "PPML coefficient (per SD of exposure)", colour = NULL,
       caption = paste("55 NACE 3-digit manufacturing industries, industry + year FE, base 2021; 95% CIs clustered by the", n_distinct(d0$col), "Rosstat",
                       "industry columns. Exposure from Rosstat's 2021 input-output tables\n(imported and domestic inputs by industry),",
                       "Russia's 2019-21 imports by origin, and the EU ban lists (end-2023). Official IPC.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig59_rosstat_input_es.pdf"), p, width = 12, height = 5.6)
ggsave(file.path(FIG_DIR, "fig59_rosstat_input_es.png"), p, width = 12, height = 5.6, dpi = 150)
