# 16c_patents_2014.R: EXPLORATORY. The field design of notes/11 applied to 2014 (notes/11 §2014).
#   (A) 2014 oil-equipment list (Annex II) coverage of 2011-13 Western imports, event study 2008-2019, base 2013.
#   (B) 2022 ban coverage over the long window 2008-2025, base 2013: what did the fields later banned do around 2014
#       (devaluation, counter-sanctions, import-substitution programmes from 2015)?
#   (C) pooled pre/post for (A) and (B) around 2014: Post = 2014-2017, window 2009-2017.
# PPML, domestic invention patents (n_top), field and year FE, SEs clustered by field; both product->field maps.
# Output: output/tables/patents_2014_eventstudy.csv, patents_2014_pooled.csv; fig32_patents_2014_eventstudy
source(here::here("empirics", "scripts", "00_setup.R"))
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>% filter(sample == "manuf")

expo <- function(ev, yr, mp) cov %>% filter(event == ev, year == yr, map == mp) %>%
  transmute(field, ban = as.numeric(scale(coverage)))
specs <- tribble(~label, ~ev, ~yr, ~from, ~to,
                 "(A) 2014 oil-equipment list", "oil2014", 2014, 2008, 2019,
                 "(B) 2022 ban coverage, long window", "eu2022", 2023, 2008, 2025)

es <- pmap_dfr(specs, function(label, ev, yr, from, to) map_dfr(c("industry", "text"), function(mp) {
  d <- pat %>% filter(between(year, from, to)) %>% select(field, year, y = n_top) %>% inner_join(expo(ev, yr, mp), by = "field")
  m <- fepois(y ~ i(year, ban, ref = 2013) | field + year, data = d, cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
    bind_rows(tibble(year = 2013L, estimate = 0, conf.low = 0, conf.high = 0)) %>% mutate(spec = label, map = mp)
}))
write_csv(es, file.path(TAB_DIR, "patents_2014_eventstudy.csv"))

pooled <- pmap_dfr(specs, function(label, ev, yr, from, to) map_dfr(c("industry", "text"), function(mp) {
  d <- pat %>% filter(between(year, 2009, 2017)) %>% select(field, year, y = n_top) %>%
    inner_join(expo(ev, yr, mp), by = "field") %>% mutate(post = as.integer(year >= 2014))
  m <- fepois(y ~ ban:post | field + year, data = d, cluster = ~field)
  tibble(spec = label, map = mp, beta = coef(m)[[1]], se = se(m)[[1]])
})) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
write_csv(pooled, file.path(TAB_DIR, "patents_2014_pooled.csv"))
print(pooled %>% mutate(across(c(beta, se, lo, hi), ~ round(., 3))), width = Inf)
print(es %>% filter(map == "industry") %>% select(spec, year, estimate, conf.low, conf.high) %>%
        mutate(across(c(estimate, conf.low, conf.high), ~ round(., 3))), n = 40)

p <- es %>% mutate(map = recode(map, industry = "Industry map", text = "Product-name map")) %>%
  ggplot(aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = c(2013.5, 2021.5), linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.2) +
  facet_wrap(~ spec, ncol = 1, scales = "free") +
  scale_x_continuous(breaks = seq(2008, 2025, 1)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on exposure (SD), log points", colour = NULL,
       caption = "Domestic invention patents by WIPO field (35), field and year FE, base 2013. 95% CIs clustered by field.") +
  theme_paper() + theme(legend.position = "top", axis.text.x = element_text(size = 7))
ggsave(file.path(FIG_DIR, "fig32_patents_2014_eventstudy.pdf"), p, width = 9, height = 7)
ggsave(file.path(FIG_DIR, "fig32_patents_2014_eventstudy.png"), p, width = 9, height = 7, dpi = 150)
