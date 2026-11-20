# 01_descriptives.R: raw series for the main sanctioned countries, with Western sanction timing.
# fig0a: resident vs non-resident patent applications; fig0b: publications and international co-authorship.
source(here::here("empirics", "scripts", "00_setup.R"))

KEY <- c(RUS = "Russia", IRN = "Iran", CHN = "China", BLR = "Belarus", VEN = "Venezuela", SYR = "Syria")
panel <- read_panel() %>% filter(iso3 %in% names(KEY), year %in% 1995:2024) %>%
  mutate(country = factor(KEY[iso3], levels = KEY))

# years with a Western economic case in force (shaded), onset years of new cases (ticks)
in_force <- panel %>% filter(n_active_west_econ > 0) %>% select(country, year)
onsets   <- panel %>% filter(new_west_econ == 1) %>% select(country, year)
onsets_p <- panel %>% filter(new_west_placebo == 1) %>% select(country, year)

sanction_layers <- function(keep = KEY) list(
  geom_tile(data = in_force %>% filter(country %in% keep), aes(x = year, y = 1, height = Inf), inherit.aes = FALSE, width = 1,
            fill = "grey85", alpha = 0.6),
  geom_rug(data = onsets %>% filter(country %in% keep), aes(x = year), inherit.aes = FALSE, sides = "b", colour = "#0072B2", linewidth = 0.7,
           length = unit(0.06, "npc")),
  geom_rug(data = onsets_p %>% filter(country %in% keep), aes(x = year), inherit.aes = FALSE, sides = "t", colour = "#E69F00", linewidth = 0.7,
           length = unit(0.06, "npc")))

sanction_caption <- paste0(
  "Grey: years with a Western economic sanction case in force (GSDB V4). Blue ticks (bottom): a new Western economic case ",
  "begins; orange ticks (top): a new arms/travel-only case begins.\n")

pat <- panel %>% select(country, year, Residents = pat_res, `Non-residents` = pat_nres) %>%
  pivot_longer(-c(country, year), names_to = "applicant", values_to = "applications") %>% filter(!is.na(applications))
p0a <- ggplot(pat, aes(year, applications, colour = applicant)) +
  sanction_layers() + geom_line(linewidth = 0.6) + geom_point(size = 0.6) +
  facet_wrap(~ country, scales = "free_y", nrow = 2) +
  scale_y_log10(labels = scales::label_comma()) +
  scale_colour_manual(values = c(Residents = "#D55E00", `Non-residents` = "#009E73"), name = NULL) +
  labs(title = "Patent applications at the national office: residents and non-residents",
       x = NULL, y = "Applications (log scale)",
       caption = paste0(sanction_caption, "Source: WIPO via World Bank WDI (IP.PAT.RESD, IP.PAT.NRES). ",
                        "Non-residents = foreign applicants filing in the country.")) +
  theme_paper()
save_figure(p0a, "fig0a_patents_key_countries", 10, 6)

pubs <- panel %>%
  transmute(country, year, `Articles and reviews (OpenAlex, log scale)` = works_oa,
            `Share internationally co-authored, %` = intl_share) %>%
  pivot_longer(-c(country, year), names_to = "series", values_to = "value") %>% filter(!is.na(value))
p0b <- ggplot(pubs %>% filter(year <= 2024), aes(year, value)) +
  sanction_layers() + geom_line(linewidth = 0.6, colour = "grey20") + geom_point(size = 0.6, colour = "grey20") +
  facet_grid(series ~ country, scales = "free_y", labeller = label_wrap_gen(22)) +
  scale_y_continuous(trans = "identity") +
  labs(title = "Publications and international co-authorship",
       x = NULL, y = NULL,
       caption = paste0(sanction_caption, "Source: OpenAlex, articles and reviews by institution country, full counting. ",
                        "Counts partly reflect OpenAlex indexing of national journals.")) +
  theme_paper() + theme(strip.text.y = element_text(angle = 0))
# log scale only for the counts row
p0b <- p0b %+% (pubs %>% mutate(value = ifelse(str_detect(series, "OpenAlex"), log10(value), value),
                                series = str_replace(series, "\\(OpenAlex, log scale\\)", "(OpenAlex, log10)")))
save_figure(p0b, "fig0b_publications_key_countries", 12, 5.5)

# fig0c: TFP (PWT 11.0 rtfpna, 2021 = 1) for the key countries that PWT covers
tfp_key <- read_panel() %>% filter(iso3 %in% c("RUS", "IRN", "VEN", "CHN"), year %in% 1995:2023, !is.na(tfp)) %>%
  mutate(country = droplevels(factor(KEY[iso3], levels = KEY)))
p0c <- ggplot(tfp_key, aes(year, tfp)) +
  sanction_layers(levels(droplevels(tfp_key$country))) + geom_hline(yintercept = 1, colour = "grey60", linewidth = 0.3, linetype = "dashed") +
  geom_line(linewidth = 0.6, colour = "grey20") + geom_point(size = 0.6, colour = "grey20") +
  facet_wrap(~ country, scales = "free_y", nrow = 1, drop = TRUE) +
  labs(title = "Total factor productivity at constant national prices", x = NULL, y = "TFP (2021 = 1)",
       caption = paste0(sanction_caption, "Source: Penn World Table 11.0 (rtfpna) via FRED. ",
                        "PWT has no TFP for Belarus or Syria. TFP is the residual of GDP after capital and labour input.")) +
  theme_paper()
save_figure(p0c, "fig0c_tfp_key_countries", 11, 3.8)
