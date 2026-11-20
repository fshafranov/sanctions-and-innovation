# 15_ban_first_stage.R: first stage with EU ban coverage as exposure (notes/10_ban_coverage.md).
#   PPML: imports_{f,t} ~ sum_k beta_k * BanCoverage_f(z) * 1{t = k} + field FE + year FE, SEs clustered by field.
#   Main exposure: coverage at end-2023 of 2019-21 Western imports (manufactured goods); 2014: oil list (Annex II).
# Output: fig28_ban_first_stage.{pdf,png}, fig29_ban_coverage_vs_drop.{pdf,png}, empirics/results/tables/ban_first_stage.csv
source(here::here("empirics", "scripts", "00_setup.R"))

imp <- read_csv(here("data", "clean", "field_imports_year.csv"), show_col_types = FALSE) %>% filter(sample == "manuf")
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>% filter(sample == "manuf")
ex  <- read_csv(here("data", "clean", "field_exposure.csv"), show_col_types = FALSE) %>% filter(sample == "manuf")

spec <- tribble(~event, ~list, ~cov_year, ~ref, ~from, ~to,
                2022, "eu2022", 2023, 2021, 2015, 2024,
                2014, "oil2014", 2014, 2013, 2008, 2019)

fit <- function(d, y, ref) {
  m <- fepois(as.formula(paste0(y, " ~ i(year, expo, ref = ", ref, ") | field + year")), data = d, cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}")))
}

est <- pmap_dfr(spec, function(event, list, cov_year, ref, from, to) {
  map_dfr(c("text", "industry"), function(mp) {
    e <- cov %>% filter(map == mp, event == !!list, year == cov_year) %>%
      transmute(field, expo = as.numeric(scale(coverage)))
    d <- imp %>% filter(map == mp, between(year, from, to)) %>% inner_join(e, by = "field") %>%
      mutate(total = west + china + other)
    map_dfr(c("west", "china", "other", "total"), function(y) fit(d, y, ref) %>% mutate(outcome = y)) %>%
      bind_rows(tibble(year = ref, estimate = 0, conf.low = 0, conf.high = 0,
                       outcome = c("west", "china", "other", "total"))) %>%
      mutate(map = mp, event = event)
  })
})
write_csv(est, file.path(TAB_DIR, "ban_first_stage.csv"))

lab <- c(west = "Imports from the West", china = "Imports from China", other = "Imports from others",
         total = "All imports")
p <- est %>%
  mutate(outcome = factor(lab[outcome], levels = lab),
         map = recode(map, text = "Map: product names (classifier)", industry = "Map: industry (Dorner-Harhoff)"),
         event = recode(as.character(event), `2022` = "2022: EU ban coverage at end-2023",
                        `2014` = "2014: oil-equipment list (Annex II)")) %>%
  ggplot(aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.2) +
  facet_grid(outcome ~ event, scales = "free") +
  scale_x_continuous(breaks = seq(2008, 2024, 2)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = NULL, y = "PPML coefficient on ban coverage (SD), log points", colour = NULL,
       caption = paste("Russia's imports of manufactured goods (HS 28-97) mapped to 35 technology fields.",
                       "95% CIs, clustered by field (35).")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig28_ban_first_stage.pdf"), p, width = 9, height = 9)
ggsave(file.path(FIG_DIR, "fig28_ban_first_stage.png"), p, width = 9, height = 9, dpi = 150)

# cross-section: coverage vs realised change 2019-21 -> 2023-24
cs <- cov %>% filter(event == "eu2022", year == 2023) %>% select(map, field, field_en, coverage) %>%
  inner_join(ex %>% filter(period == 2022) %>% select(map, field, west_share, dlog_west, dlog_china, dlog_total),
             by = c("map", "field"))
print(cs %>% group_by(map) %>% summarise(r_west = cor(coverage, dlog_west), r_china = cor(coverage, dlog_china),
                                         r_total = cor(coverage, dlog_total),
                                         r_share = cor(coverage, west_share)), width = Inf)
p2 <- cs %>% pivot_longer(c(dlog_west, dlog_total), names_to = "what", values_to = "dlog") %>%
  mutate(what = recode(what, dlog_west = "Imports from the West", dlog_total = "All imports"),
         map = recode(map, text = "Product-name map", industry = "Industry map")) %>%
  ggplot(aes(coverage, dlog)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_smooth(method = "lm", formula = y ~ x, colour = "grey50", fill = "grey85") +
  geom_point(colour = "grey20", size = 1) +
  ggrepel::geom_text_repel(aes(label = field_en), size = 1.9, max.overlaps = 8, colour = "grey35") +
  facet_grid(what ~ map, scales = "free_y") +
  labs(x = "EU ban coverage at end-2023 (share of 2019-21 Western imports)",
       y = "Log change, 2019-21 to 2023-24") +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig29_ban_coverage_vs_drop.pdf"), p2, width = 10, height = 8)
ggsave(file.path(FIG_DIR, "fig29_ban_coverage_vs_drop.png"), p2, width = 10, height = 8, dpi = 150)
