# 18f_raw_lines.R: raw time series behind the continuous-treatment design, no regression (session 5).
# Domestic invention patents with official IPC (fractional field counts), 2010-2025, 35 WIPO fields grouped into
# quarters of EU ban coverage (end-2023, industry map).
#  fig45 (A) patents per quarter of fields, indexed to the 2019-21 average = 100 (log scale)
#        (B) raw gap: log(Q4) - log(Q1) and log(Q3) - log(Q1), demeaned over 2019-21
#  fig46 every field's series (log index, 2019-21 = 0), coloured by coverage
source(here::here("empirics", "scripts", "00_setup.R"))
YEARS <- 2010:2025
pat <- read_csv(here("data", "clean", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023, map == "industry") %>% select(field, coverage) %>%
  mutate(bin = cut(coverage, quantile(coverage, 0:4 / 4), include.lowest = TRUE,
                   labels = c("Q1 lowest coverage (8-43%)", "Q2 (45-52%)", "Q3 (56-59%)", "Q4 highest coverage (59-67%)")))
g <- pat %>% inner_join(cov, by = "field") %>% group_by(bin, year) %>% summarise(n = sum(n_frac), .groups = "drop") %>%
  group_by(bin) %>% mutate(idx = 100 * n / mean(n[year %in% 2019:2021])) %>% ungroup()
print(g %>% filter(year %in% c(2010, 2015, 2019, 2021, 2022, 2023, 2024, 2025)) %>%
        mutate(n = round(n), idx = round(idx)) %>% pivot_wider(id_cols = year, names_from = bin, values_from = idx))
cols <- c("#009E73", "grey55", "#E69F00", "#D55E00")
pA <- ggplot(g, aes(year, idx, colour = bin)) +
  annotate("rect", xmin = 2018.5, xmax = 2021.5, ymin = -Inf, ymax = Inf, alpha = 0.08) +
  geom_hline(yintercept = 100, colour = "grey60") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_line(linewidth = 0.9) + geom_point(size = 1.3) +
  scale_y_log10(breaks = c(70, 80, 90, 100, 110, 120, 130, 140)) + scale_x_continuous(breaks = seq(2010, 2025, 3)) +
  scale_colour_manual(values = cols) +
  labs(title = "A. Patents by quarter of fields (2019-21 average = 100)", x = NULL, y = "Index (log scale)", colour = NULL) +
  theme_paper() + theme(legend.position = "top")
gap <- g %>% select(bin, year, n) %>% pivot_wider(names_from = bin, values_from = n) %>%
  transmute(year, `Q4 minus Q1` = log(.[[5]]) - log(.[[2]]), `Q3 minus Q1` = log(.[[4]]) - log(.[[2]]),
            `Q2 minus Q1` = log(.[[3]]) - log(.[[2]])) %>%
  pivot_longer(-year, names_to = "gap", values_to = "v") %>% group_by(gap) %>%
  mutate(v = v - mean(v[year %in% 2019:2021])) %>% ungroup()
pB <- ggplot(gap, aes(year, v, colour = gap)) +
  annotate("rect", xmin = 2018.5, xmax = 2021.5, ymin = -Inf, ymax = Inf, alpha = 0.08) +
  geom_hline(yintercept = 0, colour = "grey60") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_line(linewidth = 0.9) + geom_point(size = 1.3) + scale_x_continuous(breaks = seq(2010, 2025, 3)) +
  scale_colour_manual(values = c("grey55", "#E69F00", "#D55E00")) +
  labs(title = "B. Raw gap to the lowest-coverage quarter (log points, 2019-21 = 0)", x = NULL, y = "log difference", colour = NULL) +
  theme_paper() + theme(legend.position = "top")
p <- patchwork::wrap_plots(pA, pB, nrow = 1) +
  patchwork::plot_annotation(caption = paste("Domestic invention patents, official IPC (Rospatent API, 1994-2026), fractional",
                                             "WIPO field counts; 8-9 fields per quarter. Shaded: 2019-21 reference. 2025 filings incomplete."))
ggsave(file.path(FIG_DIR, "fig45_raw_lines_quarters.pdf"), p, width = 12, height = 5)
ggsave(file.path(FIG_DIR, "fig45_raw_lines_quarters.png"), p, width = 12, height = 5, dpi = 150)
print(gap %>% filter(gap == "Q4 minus Q1") %>% mutate(v = round(v, 3)) %>% select(year, v), n = Inf)

f <- pat %>% inner_join(cov, by = "field") %>% group_by(field) %>%
  mutate(li = log(n_frac / mean(n_frac[year %in% 2019:2021]))) %>% ungroup()
p2 <- ggplot(f, aes(year, li, group = field, colour = coverage)) +
  geom_hline(yintercept = 0, colour = "grey60") + geom_vline(xintercept = 2021.5, linetype = "dotted") +
  geom_line(alpha = 0.8) +
  stat_summary(aes(group = bin, linetype = bin), fun = median, geom = "line", colour = "black", linewidth = 0.6,
               data = f %>% filter(bin %in% levels(bin)[c(1, 4)])) +
  scale_colour_viridis_c(option = "plasma", end = 0.9, labels = scales::percent) +
  scale_x_continuous(breaks = seq(2010, 2025, 3)) + coord_cartesian(ylim = c(-0.8, 0.6)) +
  labs(x = "Filing year", y = "log patents, 2019-21 average = 0", colour = "Ban coverage", linetype = "Median of",
       caption = "Each line is one WIPO field; black lines: median of the lowest and highest coverage quarters. Official IPC.") +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig46_raw_lines_fields.pdf"), p2, width = 9, height = 5.5)
ggsave(file.path(FIG_DIR, "fig46_raw_lines_fields.png"), p2, width = 9, height = 5.5, dpi = 150)
