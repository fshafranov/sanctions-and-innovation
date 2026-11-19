# 18b_official_raw_series.R: descriptive companion to 18 (session 5). Domestic invention patents with official
# IPC (fractional field counts), summed over fields in terciles of EU ban coverage (end-2023, industry map),
# indexed 2021 = 100, by holder type. No regression. Output: fig39_official_raw_series
source(here::here("scripts", "analysis", "00_setup.R"))
YEARS <- 2012:2025
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023, map == "industry") %>%
  transmute(field, grp = cut(coverage, quantile(coverage, c(0, 1/3, 2/3, 1)), include.lowest = TRUE,
                             labels = c("Low coverage (12 fields)", "Middle", "High coverage")))
all <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  mutate(holder_type = "All domestic")
hol <- read_csv(here("data", "clean", "ru_domestic_field_year_holder_official.csv"), show_col_types = FALSE) %>%
  filter(holder_type %in% c("firm", "university", "research")) %>%
  mutate(holder_type = recode(holder_type, firm = "Firms", university = "Universities", research = "Research institutes"))
d <- bind_rows(all, hol) %>% filter(year %in% YEARS) %>% inner_join(cov, by = "field") %>%
  group_by(holder_type, grp, year) %>% summarise(n = sum(n_frac), .groups = "drop") %>%
  group_by(holder_type, grp) %>% mutate(idx = 100 * n / n[year == 2021]) %>% ungroup() %>%
  mutate(holder_type = factor(holder_type, c("All domestic", "Firms", "Universities", "Research institutes")))
print(d %>% filter(year %in% c(2019, 2021, 2023, 2025)) %>% select(holder_type, grp, year, n, idx) %>%
        mutate(across(c(n, idx), round)), n = Inf)
p <- ggplot(d, aes(year, idx, colour = grp)) +
  geom_hline(yintercept = 100, colour = "grey60") +
  geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_line(linewidth = 0.8) + geom_point(size = 1.2) +
  facet_wrap(~holder_type, nrow = 1) + scale_x_continuous(breaks = seq(2012, 2025, 3)) +
  scale_colour_manual(values = c("#009E73", "grey50", "#D55E00")) +
  labs(x = "Filing year", y = "Patents, 2021 = 100", colour = "Fields by EU ban coverage (terciles)",
       caption = "Domestic invention patents, official IPC (Rospatent API, 1994-2026), fractional field counts. 2025 filings incomplete.") +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig39_official_raw_series.pdf"), p, width = 11, height = 4.5)
ggsave(file.path(FIG_DIR, "fig39_official_raw_series.png"), p, width = 11, height = 4.5, dpi = 150)
