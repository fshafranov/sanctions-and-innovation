# 18u_filings_2014.R: the 2014 episode on FILINGS by origin (20 Nov 2026). Did foreign filers start leaving the
# (later-)banned fields in 2014? Base year 2013. Same exposures as 18o, industry map, PPML, field + year FE,
# 35 WIPO fields, SEs clustered by field.
#  (A) 2014 oil-equipment list coverage of 2011-13 Western imports, z-scored; 2010-2021 (stops before 2022 bans)
#  (B) 2022 ban coverage (end-2023), z-scored; 2010-2024
#  Pooled: Ban x 1[2014-2021] and Ban x 1[2022+] vs 2010-13 (B); Ban x 1[2014-17] vs 2010-13 on 2010-17 (A)
# Filings panel from 2010 (23b; pre-2014 application numbers matched after the "/NN" fix). Foreign PCT entries are
# dated by international filing date; 2021 foreign PCT cohort largely missing (note 16).
#  (C) foreign filings by group (AP6), 2022 coverage, base 2013: West, West without Ford, China, West PCT, West
#      direct; and the foreign applicants that cut most in high-coverage fields (top tercile) 2013-14 -> 2019-20.
# Output: empirics/results/tables/filings_2014_es.csv, filings_2014_pooled.csv, filings_foreign_groups_es.csv,
#         filings_foreign_top_applicants.csv; fig61_filings_2014, fig62_foreign_groups
source(here::here("empirics", "scripts", "00_setup.R"))
fp <- read_csv(here("data", "clean", "ru_filings_field_year_origin.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", map == "industry")
expo <- function(ev, yr) cov %>% filter(event == ev, year == yr) %>% transmute(field, ban = as.numeric(scale(coverage)))
mk <- function(o, from, to) fp %>% filter(origin %in% o) %>% group_by(field, year) %>%
  summarise(y = sum(n_frac), .groups = "drop") %>% complete(field = 1:35, year = from:to, fill = list(y = 0)) %>%
  filter(between(year, from, to))
specs <- tribble(~exposure, ~ev, ~yr, ~to,
                 "A. 2014 oil-equipment list", "oil2014", 2014, 2021,
                 "B. 2022 ban coverage", "eu2022", 2023, 2024)
origins <- list(Foreign = "foreign", Domestic = "domestic")

es <- pmap_dfr(specs, function(exposure, ev, yr, to) imap_dfr(origins, function(o, on) {
  d <- mk(o, 2010, to) %>% inner_join(expo(ev, yr), by = "field")
  m <- fepois(y ~ i(year, ban, ref = 2013) | field + year, data = d, cluster = ~field)
  pre_p <- wald(m, keep = "::(2010|2011|2012):", print = FALSE)$p
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
    bind_rows(tibble(year = 2013L, estimate = 0, conf.low = 0, conf.high = 0)) %>%
    mutate(exposure = exposure, origin = on, pre_p = pre_p)
}))
write_csv(es %>% select(exposure, origin, year, estimate, std.error, conf.low, conf.high, pre_p),
          file.path(TAB_DIR, "filings_2014_es.csv"))
print(es %>% select(exposure, origin, year, estimate, conf.low, conf.high) %>% arrange(exposure, origin, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)
print(es %>% distinct(exposure, origin, pre_p))

pooled <- imap_dfr(origins, function(o, on) bind_rows(
  {
    d <- mk(o, 2010, 2017) %>% inner_join(expo("oil2014", 2014), by = "field") %>% mutate(post = as.integer(year >= 2014))
    m <- fepois(y ~ ban:post | field + year, data = d, cluster = ~field)
    tibble(exposure = "A. 2014 oil-equipment list", term = "Ban x 2014-17 (vs 2010-13)", beta = coef(m)[[1]], se = se(m)[[1]])
  },
  {
    d <- mk(o, 2010, 2024) %>% inner_join(expo("eu2022", 2023), by = "field") %>%
      mutate(p14 = as.integer(between(year, 2014, 2021)), p22 = as.integer(year >= 2022))
    m <- fepois(y ~ ban:p14 + ban:p22 | field + year, data = d, cluster = ~field)
    tibble(exposure = "B. 2022 ban coverage", term = c("Ban x 2014-21 (vs 2010-13)", "Ban x 2022-24 (vs 2010-13)"),
           beta = coef(m), se = se(m))
  }) %>% mutate(origin = on)) %>% mutate(p = 2 * pnorm(-abs(beta / se)))
write_csv(pooled, file.path(TAB_DIR, "filings_2014_pooled.csv"))
print(pooled %>% mutate(across(where(is.double), ~ round(., 3))))

p <- ggplot(es, aes(year, estimate, colour = origin, fill = origin)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey50") +
  geom_vline(xintercept = 2021.5, linetype = 3, colour = "grey50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.15, colour = NA) +
  geom_line() + geom_point(size = 1.4) +
  facet_wrap(~exposure, nrow = 1) +
  scale_colour_manual(values = c(Foreign = "#D55E00", Domestic = "#0072B2"), aesthetics = c("colour", "fill")) +
  scale_x_continuous(breaks = seq(2010, 2024, 2)) +
  labs(x = "Filing year", y = "Effect of 1 SD exposure (log points)", colour = NULL, fill = NULL,
       caption = paste("PPML, field + year FE, 35 WIPO fields, base 2013, industry map, 95% CI clustered by field.",
                       "Filings = published applications + fast grants (23b).\nDashed: 2014 sanctions; dotted: 2022 bans.",
                       "Foreign PCT entries dated by international filing date; the 2021 foreign PCT cohort is largely missing.")) +
  theme_paper()
save_figure(p, "fig61_filings_2014", width = 11, height = 4.6)

# (C) foreign groups
fg <- read_csv(here("data", "clean", "ru_filings_foreign_field_year_group.csv"), show_col_types = FALSE)
groups <- list("West" = quote(grp == "west"), "West without Ford" = quote(grp == "west" & !ford),
               "China" = quote(grp == "china"), "West, PCT entries" = quote(grp == "west" & pct),
               "West, direct filings" = quote(grp == "west" & !pct))
ges <- imap_dfr(groups, function(cond, nm) {
  d <- fg %>% filter(!!cond) %>% group_by(field, year) %>% summarise(y = sum(n_frac), .groups = "drop") %>%
    complete(field = 1:35, year = 2010:2024, fill = list(y = 0)) %>% filter(between(year, 2010, 2024)) %>%
    inner_join(expo("eu2022", 2023), by = "field")
  m <- fepois(y ~ i(year, ban, ref = 2013) | field + year, data = d, cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
    bind_rows(tibble(year = 2013L, estimate = 0, conf.low = 0, conf.high = 0)) %>%
    mutate(group = nm, pre_p = wald(m, keep = "::(2010|2011|2012):", print = FALSE)$p)
})
write_csv(ges %>% select(group, year, estimate, std.error, conf.low, conf.high, pre_p),
          file.path(TAB_DIR, "filings_foreign_groups_es.csv"))
print(ges %>% mutate(v = sprintf("%.2f%s", estimate, ifelse(conf.low > 0 | conf.high < 0, "*", ""))) %>%
        select(group, year, v) %>% arrange(year) %>% pivot_wider(names_from = year, values_from = v) %>% as.data.frame())

hi <- cov %>% filter(event == "eu2022", year == 2023) %>% filter(coverage >= quantile(coverage, 2 / 3)) %>% pull(field)
top <- read_csv(here("data", "clean", "ru_filings_foreign_applicant_year.csv"), show_col_types = FALSE) %>%
  filter(field %in% hi) %>% group_by(applicant, year) %>% summarise(n = sum(n_frac), .groups = "drop") %>%
  complete(applicant, year = 2010:2024, fill = list(n = 0)) %>% group_by(applicant) %>%
  summarise(n_2013_14 = mean(n[year %in% 2013:2014]), n_2015_17 = mean(n[year %in% 2015:2017]),
            n_2019_20 = mean(n[year %in% 2019:2020]), n_2022_24 = mean(n[year %in% 2022:2024]),
            drop = n_2013_14 - n_2019_20) %>% arrange(desc(drop))
all_hi <- read_csv(here("data", "clean", "ru_filings_foreign_field_year_group.csv"), show_col_types = FALSE) %>%
  filter(field %in% hi) %>% group_by(year) %>% summarise(n = sum(n_frac))
tot_drop <- mean(all_hi$n[all_hi$year %in% 2013:2014]) - mean(all_hi$n[all_hi$year %in% 2019:2020])
top <- top %>% mutate(share_of_total_drop = drop / tot_drop)
write_csv(top, file.path(TAB_DIR, "filings_foreign_top_applicants.csv"))
print(head(top, 15) %>% mutate(across(where(is.double), ~ round(., 2))), width = 200)
cat(sprintf("Top 15 applicants: %.0f%% of the drop in high-coverage foreign filings 2013-14 -> 2019-20\n",
            100 * sum(head(top$drop, 15)) / tot_drop))

pg <- ggplot(ges, aes(year, estimate)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_vline(xintercept = 2013.5, linetype = 2, colour = "grey50") +
  geom_vline(xintercept = 2021.5, linetype = 3, colour = "grey50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2, fill = "#D55E00") +
  geom_line(colour = "#D55E00") + geom_point(colour = "#D55E00", size = 1.3) +
  facet_wrap(~ factor(group, names(groups)), nrow = 1) +
  scale_x_continuous(breaks = seq(2010, 2024, 4)) +
  labs(x = "Filing year", y = "Effect of 1 SD 2022 ban coverage (log points)",
       caption = paste("Foreign filings by first applicant's country (AP6). PPML, field + year FE, base 2013,",
                       "industry map, 95% CI clustered by field.\nFord = Ford Global Technologies (filing surge",
                       "2015-17, exit 2018). Dashed: 2014 sanctions; dotted: 2022 bans.")) +
  theme_paper()
save_figure(pg, "fig62_foreign_groups", width = 13, height = 4.2)
