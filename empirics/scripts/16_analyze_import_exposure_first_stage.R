# 14_import_exposure_first_stage.R: first stage of the import-substitution design (notes/09_import_exposure.md).
# Did technology fields with a higher pre-period Western share of Russia's imports lose more Western imports after
# 2014 and 2022, and did China (or others) fill the gap?
#   PPML: imports_{f,t} ~ sum_k beta_k * WestShare_f(z) * 1{t = k} + field FE + year FE, SEs clustered by field.
#   Exposure fixed in 2011-13 (2014 event, ref 2013) or 2019-21 (2022 event, ref 2021); manufactured goods (E2).
# Output: fig26_import_first_stage.{pdf,png}, fig27_exposure_maps_agree.{pdf,png},
#         empirics/results/tables/import_first_stage.csv
source(here::here("empirics", "scripts", "00_setup.R"))

imp <- read_csv(here("data", "clean", "field_imports_year.csv"), show_col_types = FALSE)
ex  <- read_csv(here("data", "clean", "field_exposure.csv"), show_col_types = FALSE)

events <- tribble(~event, ~ref, ~from, ~to,
                  2014,   2013, 2008,  2019,
                  2022,   2021, 2015,  max(imp$year))

est <- pmap_dfr(events, function(event, ref, from, to) {
  map_dfr(c("text", "industry"), function(mp) {
    e <- ex %>% filter(map == mp, sample == "manuf", period == event) %>%
      transmute(field, expo = as.numeric(scale(west_share)))
    d <- imp %>% filter(map == mp, sample == "manuf", between(year, from, to)) %>%
      inner_join(e, by = "field") %>% mutate(total = west + china + other)
    map_dfr(c("west", "china", "other", "total"), function(y) {
      m <- fepois(as.formula(paste0(y, " ~ i(year, expo, ref = ", ref, ") | field + year")), data = d,
                  cluster = ~field)
      broom::tidy(m, conf.int = TRUE) %>%
        mutate(year = as.integer(str_extract(term, "\\d{4}")), outcome = y, map = mp, event = event)
    }) %>% bind_rows(tibble(year = ref, estimate = 0, conf.low = 0, conf.high = 0, outcome = c("west", "china",
                     "other", "total"), map = mp, event = event))
  })
})
write_csv(est, file.path(TAB_DIR, "import_first_stage.csv"))

lab <- c(west = "Imports from the West", china = "Imports from China", other = "Imports from others",
         total = "All imports")
p <- est %>%
  mutate(outcome = factor(lab[outcome], levels = lab),
         map = recode(map, text = "Map: product names (classifier)", industry = "Map: industry (Dorner-Harhoff)"),
         event = paste("Event", event)) %>%
  ggplot(aes(year, estimate, colour = map)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.2) +
  facet_grid(outcome ~ event, scales = "free_x") +
  scale_x_continuous(breaks = seq(2008, 2024, 2)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = NULL, y = "PPML coefficient on Western import share (SD), log points", colour = NULL,
       caption = paste("Russia's imports of manufactured goods (HS 28-97) mapped to 35 technology fields;",
                       "exposure fixed 2011-13 / 2019-21. 95% CIs, clustered by field (35).")) +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig26_import_first_stage.pdf"), p, width = 9, height = 9)
ggsave(file.path(FIG_DIR, "fig26_import_first_stage.png"), p, width = 9, height = 9, dpi = 150)

# agreement of the two maps on the exposure measure
a <- ex %>% filter(sample == "manuf") %>% select(map, period, field, field_en, west_share) %>%
  pivot_wider(names_from = map, values_from = west_share)
print(a %>% group_by(period) %>% summarise(corr = cor(text, industry)))
p2 <- ggplot(a, aes(industry, text)) +
  geom_abline(colour = "grey60", linetype = "dashed") +
  geom_point(colour = "grey20") +
  ggrepel::geom_text_repel(aes(label = field_en), size = 2.2, max.overlaps = 12, colour = "grey30") +
  facet_wrap(~ paste("Pre-period for", period)) +
  labs(x = "Western share of imports, industry map", y = "Western share of imports, product-name map") +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig27_exposure_maps_agree.pdf"), p2, width = 10, height = 5.5)
ggsave(file.path(FIG_DIR, "fig27_exposure_maps_agree.png"), p2, width = 10, height = 5.5, dpi = 150)
