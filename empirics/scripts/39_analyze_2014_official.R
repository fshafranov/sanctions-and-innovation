# 18o_2014_official.R: the 2014 episode with official IPC codes and a long pre-period (session 5; supersedes 16c,
# which used title-predicted fields). PPML, 35 WIPO fields, field + year FE, SEs clustered by field, both maps.
#  (A) 2014 oil-equipment list (EU Annex II) coverage of 2011-13 Western imports, z-scored; 2005-2021, base 2013
#      (stops before the 2022 bans)
#  (B) 2022 ban coverage (end-2023), z-scored, over 2005-2025 with base 2013: when did the later-banned fields start
#      to drift? (2014 sanctions/devaluation/import-substitution programmes vs a long-run trend)
#  (C) pooled: (A) Post = 2014-2017 on 2009-2017; (B) three-period version on 2005-2025:
#      Ban x 1[2014-2021] and Ban x 1[2022+], base 2005-2013
# Output: empirics/results/tables/patents_2014_official.csv, patents_2014_official_pooled.csv; fig55_2014_official
source(here::here("empirics", "scripts", "00_setup.R"))
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>% filter(sample == "manuf")
expo <- function(ev, yr, mp) cov %>% filter(event == ev, year == yr, map == mp) %>% transmute(field, ban = as.numeric(scale(coverage)))
specs <- tribble(~label, ~ev, ~yr, ~from, ~to,
                 "A. 2014 oil-equipment list (2005-2021)", "oil2014", 2014, 2005, 2021,
                 "B. 2022 ban coverage, long window (2005-2025)", "eu2022", 2023, 2005, 2025)
es <- pmap_dfr(specs, function(label, ev, yr, from, to) map_dfr(c("industry", "text"), function(mp) {
  d <- pat %>% filter(between(year, from, to)) %>% inner_join(expo(ev, yr, mp), by = "field")
  m <- fepois(n_frac ~ i(year, ban, ref = 2013) | field + year, data = d, cluster = ~field)
  w <- wald(m, keep = paste0("::(", paste(from:2012, collapse = "|"), "):"), print = FALSE)$p
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
    bind_rows(tibble(year = 2013L, estimate = 0, conf.low = 0, conf.high = 0)) %>% mutate(spec = label, map = mp, pre_p = w)
}))
write_csv(es %>% select(spec, map, year, estimate, std.error, conf.low, conf.high, pre_p), file.path(TAB_DIR, "patents_2014_official.csv"))
print(es %>% select(spec, map, year, estimate, conf.low, conf.high) %>% arrange(spec, map, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)
print(es %>% distinct(spec, map, pre_p))

pooled <- bind_rows(
  map_dfr(c("industry", "text"), function(mp) {
    d <- pat %>% filter(between(year, 2009, 2017)) %>% inner_join(expo("oil2014", 2014, mp), by = "field") %>%
      mutate(post = as.integer(year >= 2014))
    m <- fepois(n_frac ~ ban:post | field + year, data = d, cluster = ~field)
    tibble(spec = "A. oil list, 2014-17 vs 2009-13", map = mp, term = "Ban x Post2014", beta = coef(m)[[1]], se = se(m)[[1]])
  }),
  map_dfr(c("industry", "text"), function(mp) {
    d <- pat %>% filter(between(year, 2005, 2025)) %>% inner_join(expo("eu2022", 2023, mp), by = "field") %>%
      mutate(p14 = as.integer(between(year, 2014, 2021)), p22 = as.integer(year >= 2022))
    m <- fepois(n_frac ~ ban:p14 + ban:p22 | field + year, data = d, cluster = ~field)
    tibble(spec = "B. 2022 coverage, periods vs 2005-13", map = mp, term = c("Ban x 2014-2021", "Ban x 2022+"),
           beta = unname(coef(m)), se = unname(se(m)))
  })) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se, p = 2 * pnorm(-abs(beta / se)))
write_csv(pooled, file.path(TAB_DIR, "patents_2014_official_pooled.csv"))
print(pooled %>% mutate(across(where(is.double), ~ round(., 3))), width = Inf)

pd <- es %>% mutate(map = recode(map, industry = "Industry map (main)", text = "Product-name map"))
lab <- es %>% distinct(spec, map, pre_p) %>% group_by(spec) %>%
  summarise(txt = paste0("pre-2013 joint p: ", paste(sprintf("%.2f", pre_p), collapse = " / ")))
p <- ggplot(pd, aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = 2013.5, linetype = "dotted") + geom_vline(xintercept = 2021.5, linetype = "dashed", colour = "grey60") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.18) +
  geom_text(data = lab, aes(x = 2005, y = -Inf, label = txt), hjust = 0, vjust = -0.6, size = 3, inherit.aes = FALSE) +
  facet_wrap(~spec, scales = "free") + scale_x_continuous(breaks = seq(2005, 2025, 4)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on coverage (per SD)", colour = NULL,
       caption = paste("35 WIPO fields, field + year FE, base 2013, 95% CIs clustered by field. Dotted: 2014 sanctions; dashed: 2022 bans.",
                       "Joint p: industry / product-name map. Official IPC.")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig55_2014_official.pdf"), p, width = 12, height = 5)
ggsave(file.path(FIG_DIR, "fig55_2014_official.png"), p, width = 12, height = 5, dpi = 150)
