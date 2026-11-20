# 16d_patents_staggered.R: EXPLORATORY (notes/11 §Staggered). Domestic invention patents (n_top) by field x year.
# (1) Continuous, time-varying dose over both episodes, 2008-2025:
#       Oil_ft = 2014 oil-list coverage of 2011-13 Western imports for t >= 2014 (0 before);
#       EU_ft  = EU ban coverage of 2019-21 Western imports at the end of year t for t >= 2022 (0 before).
#     PPML: y ~ Oil_ft + EU_ft | field + year (and EU only). Coefficients per 10 percentage points of coverage.
# (2) Staggered binary within 2022-2025: field treated from the first year its EU coverage reaches 50% (cohorts
#     2023/2024/2025; never by 2025 = control). Plain TWFE PPML, Sun-Abraham (fixest sunab, PPML), and
#     Callaway-Sant'Anna (did; log(1 + n), never-treated and not-yet-treated controls). Window 2015-2025.
#     Robustness: threshold 60%.
# Caveat: Annex VII electronics bans enter only via Annex XL (Dec 2023), so electronics cohorts are dated too late.
# Output: empirics/results/tables/patents_staggered.csv, patents_staggered_es.csv; fig33_patents_staggered
source(here::here("empirics", "scripts", "00_setup.R"))
suppressPackageStartupMessages(library(did))
set.seed(20261112)

pat <- read_csv(here("data", "processed", "title_fields", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE) %>%
  select(field, field_en, year, y = n_top)
cov <- read_csv(here("data", "processed", "ban_coverage", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", map == "industry")
oil <- cov %>% filter(event == "oil2014") %>% select(field, oil = coverage)
eu  <- cov %>% filter(event == "eu2022") %>% select(field, year, eu = coverage)

# ---- (1) continuous dose ---------------------------------------------------------------------------------------
d1 <- pat %>% filter(between(year, 2008, 2025)) %>% left_join(oil, by = "field") %>%
  left_join(eu, by = c("field", "year")) %>%
  mutate(oil_ft = if_else(year >= 2014, oil, 0), eu_ft = if_else(year >= 2022, coalesce(eu, 0), 0),
         across(c(oil_ft, eu_ft), ~ . * 10))  # per 10 pp
m1a <- fepois(y ~ oil_ft + eu_ft | field + year, data = d1, cluster = ~field)
m1b <- fepois(y ~ eu_ft | field + year, data = filter(d1, year >= 2015), cluster = ~field)
m1c <- fepois(y ~ oil_ft | field + year, data = filter(d1, year <= 2021), cluster = ~field)
dose <- bind_rows(
  broom::tidy(m1a, conf.int = TRUE) %>% mutate(spec = "(1a) dose, both episodes, 2008-2025"),
  broom::tidy(m1b, conf.int = TRUE) %>% mutate(spec = "(1b) dose, EU only, 2015-2025"),
  broom::tidy(m1c, conf.int = TRUE) %>% mutate(spec = "(1c) dose, oil list only, 2008-2021"))

# ---- (2) staggered binary --------------------------------------------------------------------------------------
cohorts <- function(th) eu %>% filter(eu >= th) %>% group_by(field) %>% summarise(g = min(year)) %>%
  right_join(distinct(pat, field), by = "field") %>% mutate(g = coalesce(g, 0L))
stag <- map_dfr(c(0.5, 0.6), function(th) {
  co <- cohorts(th)
  cat(sprintf("threshold %.0f%%: cohorts %s\n", 100 * th, paste(names(table(co$g)), table(co$g), sep = ":", collapse = " ")))
  d <- pat %>% filter(between(year, 2015, 2025)) %>% inner_join(co, by = "field") %>%
    mutate(treat = as.integer(g > 0 & year >= g), g_sa = if_else(g == 0, 10000L, g), ly = log1p(y))
  twfe <- fepois(y ~ treat | field + year, data = d, cluster = ~field)
  sa <- fepois(y ~ sunab(g_sa, year) | field + year, data = d, cluster = ~field)
  sa_att <- summary(sa, agg = "ATT")
  cs <- map_dfr(c("nevertreated", "notyettreated"), function(cg) {
    a <- att_gt(yname = "ly", tname = "year", idname = "field", gname = "g", data = as.data.frame(d),
                control_group = cg, base_period = "universal", bstrap = TRUE, cband = FALSE)
    s <- aggte(a, type = "simple", na.rm = TRUE)
    tibble(term = paste0("CS ATT (log), ", cg), estimate = s$overall.att, std.error = s$overall.se)
  })
  bind_rows(
    tibble(term = "TWFE PPML", estimate = coef(twfe)[[1]], std.error = se(twfe)[[1]]),
    tibble(term = "Sun-Abraham PPML ATT", estimate = coef(sa_att)[["ATT"]], std.error = se(sa_att)[["ATT"]]),
    cs) %>% mutate(spec = sprintf("(2) staggered, threshold %.0f%%", 100 * th))
}) %>% mutate(conf.low = estimate - 1.96 * std.error, conf.high = estimate + 1.96 * std.error)

res <- bind_rows(dose, stag) %>% select(spec, term, estimate, std.error, conf.low, conf.high)
write_csv(res, file.path(TAB_DIR, "patents_staggered.csv"))
print(res %>% mutate(across(where(is.numeric), ~ round(., 3))), n = 30, width = Inf)

# ---- event study by relative time (threshold 50%) --------------------------------------------------------------
co <- cohorts(0.5)
d <- pat %>% filter(between(year, 2015, 2025)) %>% inner_join(co, by = "field") %>%
  mutate(g_sa = if_else(g == 0, 10000L, g), ly = log1p(y))
sa <- fepois(y ~ sunab(g_sa, year) | field + year, data = d, cluster = ~field)
es_sa <- broom::tidy(sa, conf.int = TRUE) %>% mutate(e = as.integer(str_extract(term, "-?\\d+$")),
                                                     est = "Sun-Abraham (PPML)")
a <- att_gt(yname = "ly", tname = "year", idname = "field", gname = "g", data = as.data.frame(d),
            control_group = "notyettreated", base_period = "universal", bstrap = TRUE, cband = FALSE)
ev <- aggte(a, type = "dynamic", na.rm = TRUE)
es_cs <- tibble(e = ev$egt, estimate = ev$att.egt, std.error = ev$se.egt) %>%
  mutate(conf.low = estimate - 1.96 * std.error, conf.high = estimate + 1.96 * std.error,
         est = "Callaway-Sant'Anna (log, not-yet-treated)")
es <- bind_rows(es_sa %>% select(e, estimate, conf.low, conf.high, est),
                tibble(e = -1L, estimate = 0, conf.low = 0, conf.high = 0, est = "Sun-Abraham (PPML)"),
                es_cs %>% select(e, estimate, conf.low, conf.high, est)) %>% filter(between(e, -7, 2))
write_csv(es, file.path(TAB_DIR, "patents_staggered_es.csv"))
p <- ggplot(es, aes(e, estimate, colour = est)) +
  geom_hline(yintercept = 0, colour = "grey40") + geom_vline(xintercept = -0.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.25) +
  scale_x_continuous(breaks = -7:2) + scale_colour_manual(values = c("#009E73", "#0072B2")) +
  labs(x = "Years relative to the year the field's EU ban coverage reached 50%", y = "Effect on domestic patents, log points",
       colour = NULL, caption = paste("Cohorts 2023/2024/2025; never by 2025 = medical tech, pharma, analysis of biol.",
                                      "materials, textile machines, other consumer goods. 95% CIs clustered by field.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig33_patents_staggered.pdf"), p, width = 8, height = 5)
ggsave(file.path(FIG_DIR, "fig33_patents_staggered.png"), p, width = 8, height = 5, dpi = 150)
