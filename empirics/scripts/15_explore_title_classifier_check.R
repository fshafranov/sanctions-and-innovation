# 13_title_classifier_check.R: does the title-based field imputation (data/scripts/processing/process_title_fields.py)
# reproduce IPC-based field counts? Domestic Rospatent inventions (no mass filers), by filing year.
# Predicted counts in 2010-2021 are out-of-fold (cross-fitted), so the overlap is a fair test.
# Output: fig25_title_classifier_fields.{pdf,png}
source(here::here("empirics", "scripts", "00_setup.R"))

fy <- read_csv(here("data", "clean", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE) %>%
  filter(year >= 2010, year <= 2025)

d <- bind_rows(
  fy %>% transmute(field_en, year, n = n_top, measure = "Predicted from title (top field)"),
  fy %>% filter(year <= 2020) %>% transmute(field_en, year, n = n_obs, measure = "IPC (Google Patents)")
)

p <- ggplot(d, aes(year, n, colour = measure)) +
  geom_vline(xintercept = c(2014, 2022), linetype = "dotted", colour = "grey50") +
  geom_line() +
  facet_wrap(~ field_en, scales = "free_y", ncol = 5, labeller = label_wrap_gen(28)) +
  scale_colour_manual(values = c("grey20", "#D55E00")) +
  labs(x = NULL, y = "Domestic invention patents, by filing year", colour = NULL,
       caption = paste("IPC shown 2010-2020 (match rate >= 70%). Predicted counts 2010-2021 are out-of-fold.",
                       "2025 filings incomplete (grant lag).")) +
  theme_paper() + theme(legend.position = "top", strip.text = element_text(size = 7),
                        axis.text = element_text(size = 6))

ggsave(file.path(FIG_DIR, "fig25_title_classifier_fields.pdf"), p, width = 11, height = 12)
ggsave(file.path(FIG_DIR, "fig25_title_classifier_fields.png"), p, width = 11, height = 12, dpi = 150)
