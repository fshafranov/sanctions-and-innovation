# 16_patents_ban_test.R: main test, pre-registered in notes/11_patents_ban_test.md (do not change the main spec).
#   P_ft = exp(beta * Ban_f * Post_t + field FE + year FE), PPML, 35 fields x 2015-2025, Post = 2022+,
#   Ban_f = EU ban coverage end-2023 (industry map, manufactured goods), z-scored; SEs clustered by field;
#   main p-value: randomization inference (2,000 permutations of Ban_f across fields).
# Output: output/tables/patents_ban_test.csv, patents_ban_eventstudy.csv; fig30_patents_ban_eventstudy, fig31_ri
source(here::here("scripts", "analysis", "00_setup.R"))
set.seed(20261112)

pat <- read_csv(here("data", "clean", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE)
hol <- read_csv(here("data", "clean", "ru_domestic_field_year_holder.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
val <- read_csv(here("data", "logs", "14_title_classifier_validation.csv"), show_col_types = FALSE)
weak <- val %>% filter(str_starts(metric, "recall_field_"), value < 0.5) %>%
  mutate(field = as.integer(str_extract(metric, "\\d+$"))) %>% pull(field)
cat("weak fields (recall < 0.5):", weak, "\n")

ban <- function(mp, var = "coverage") cov %>% filter(map == mp) %>%
  transmute(field, ban = as.numeric(scale(.data[[var]])))

panel <- function(y = "n_top", mp = "industry", var = "coverage", years = 2015:2025, drop = integer(0),
                  data = pat) {
  data %>% filter(year %in% years, !field %in% drop) %>% select(field, year, y = all_of(y)) %>%
    inner_join(ban(mp, var), by = "field") %>% mutate(post = as.integer(year >= 2022))
}
did <- function(d) {
  m <- fepois(y ~ ban:post | field + year, data = d, cluster = ~field)
  tibble(beta = coef(m)[["ban:post"]], se = se(m)[["ban:post"]], n_fields = n_distinct(d$field), n = nobs(m))
}
ri <- function(d, R = 2000) {
  b0 <- did(d)$beta
  f <- distinct(d, field, ban)
  perm <- replicate(R, {
    s <- f %>% mutate(ban = sample(ban))
    coef(fepois(y ~ ban:post | field + year, data = select(d, -ban) %>% inner_join(s, by = "field")))[[1]]
  })
  list(p = mean(abs(perm) >= abs(b0)), perm = perm, beta = b0)
}

# ---- main ------------------------------------------------------------------------------------------------------
d0 <- panel()
main <- did(d0)
r0 <- ri(d0)
main <- main %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se, p_ri = r0$p, spec = "MAIN")
print(main)

# ---- pre-specified robustness ----------------------------------------------------------------------------------
hp <- function(type) hol %>% filter(holder_type == type) %>% rename(n_type = n)
rob <- bind_rows(
  did(panel(mp = "text")) %>% mutate(spec = "1 product-name map"),
  did(panel(drop = weak)) %>% mutate(spec = "2 drop weak fields"),
  did(panel(y = "n_type", data = hp("firm"))) %>% mutate(spec = "3a firms"),
  did(panel(y = "n_type", data = hp("university"))) %>% mutate(spec = "3b universities"),
  did(panel(y = "n_type", data = hp("research"))) %>% mutate(spec = "3c research institutes"),
  did(panel(y = "n_hybrid")) %>% mutate(spec = "4 IPC where matched (n_hybrid)"),
  did(panel(years = 2015:2024)) %>% mutate(spec = "5 years 2015-2024"),
  did(panel(var = "coverage_noex")) %>% mutate(spec = "6 coverage without ex-codes")
) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
res <- bind_rows(main, rob)
write_csv(res, file.path(TAB_DIR, "patents_ban_test.csv"))
print(res %>% mutate(across(c(beta, se, lo, hi), ~ round(., 3))), width = Inf)

# ---- event study -----------------------------------------------------------------------------------------------
es <- map_dfr(c("industry", "text"), function(mp) {
  d <- panel(mp = mp)
  m <- fepois(y ~ i(year, ban, ref = 2021) | field + year, data = d, cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}")), map = mp) %>%
    bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0, map = mp))
})
write_csv(es, file.path(TAB_DIR, "patents_ban_eventstudy.csv"))
p <- es %>% mutate(map = recode(map, industry = "Ban coverage, industry map (main)",
                                text = "Ban coverage, product-name map")) %>%
  ggplot(aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.25) +
  scale_x_continuous(breaks = 2015:2025) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (SD), log points", colour = NULL,
       caption = paste0("Domestic invention patents by WIPO field (35), field and year FE, base 2021. ",
                        "95% CIs clustered by field. 2025 filings incomplete.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig30_patents_ban_eventstudy.pdf"), p, width = 8, height = 5)
ggsave(file.path(FIG_DIR, "fig30_patents_ban_eventstudy.png"), p, width = 8, height = 5, dpi = 150)

p2 <- ggplot(tibble(b = r0$perm), aes(b)) +
  geom_histogram(bins = 60, fill = "grey70", colour = "white") +
  geom_vline(xintercept = r0$beta, colour = "#D55E00", linewidth = 0.8) +
  labs(x = "beta with Ban_f permuted across fields (2,000 draws)", y = NULL,
       caption = sprintf("Actual beta = %.3f; randomization p = %.3f", r0$beta, r0$p)) +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig31_patents_ban_ri.pdf"), p2, width = 6, height = 4)
ggsave(file.path(FIG_DIR, "fig31_patents_ban_ri.png"), p2, width = 6, height = 4, dpi = 150)
