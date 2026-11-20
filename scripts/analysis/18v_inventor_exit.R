# 18v_inventor_exit.R: do inventors leave the banned fields? Extensive vs intensive margin of the ban result, and
# inventor continuation (20 Nov 2026; emigration/exit channel, note 17). Data: script 31 (domestic RU inventors,
# filings = applications + fast grants, 2010-2025). Exposure: Ban_f (EU coverage end-2023, industry map, z-scored).
# (A) Field x year, 2015-2024, PPML, field + year FE, clustered by field, event study base 2021:
#     active inventors (fractional by field shares), entrants (first filing), incumbents, applications; and
#     OLS log(applications per active inventor).
# (B) Inventor cohorts: inventors active in year t (2012-2022); cont = files again in t+1 or t+2 (window ends 2024).
#     Exposure_i,t = field-share-weighted Ban of their year-t applications; field_i = modal field in t.
#     LPM: cont ~ i(t, Ban, ref = 2019) | t + field, clustered by field (cohort 2019's window 2020-21 is pre-war;
#     cohort 2020 straddles; cohorts 2021-22 are post). Pooled: Ban x 1[t >= 2021], cohort 2020 dropped, on all
#     cohorts 2012-22 and on 2016-22 (older cohorts sit on a mild downward pre-trend).
#     By holder type; and without common surnames (homonym check, IV2).
# Output: output/tables/inventor_field_es.csv, inventor_field_pooled.csv, inventor_cont_es.csv,
#         inventor_cont_pooled.csv; fig63_inventor_margins, fig64_inventor_continuation
source(here::here("scripts", "analysis", "00_setup.R"))
iy <- read_csv(here("data", "clean", "inventor_year_field.csv.gz"), show_col_types = FALSE)
fa <- read_csv(here("data", "clean", "inventor_app_field_year.csv"), show_col_types = FALSE)
ban <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023, map == "industry") %>%
  transmute(field, ban = as.numeric(scale(coverage)))

# ---- (A) field x year margins
iy <- iy %>% group_by(name, year) %>% mutate(share = w / sum(w)) %>% ungroup()
first <- iy %>% group_by(name) %>% summarise(first = min(year))
fy <- iy %>% left_join(first, by = "name") %>% group_by(field, year) %>%
  summarise(inventors = sum(share), entrants = sum(share[year == first]), incumbents = sum(share[year > first]),
            .groups = "drop")
fy <- fy %>% full_join(fa, by = c("field", "year")) %>% filter(between(year, 2015, 2024)) %>%
  complete(field = 1:35, year = 2015:2024, fill = list(inventors = 0, entrants = 0, incumbents = 0, applications = 0)) %>%
  inner_join(ban, by = "field") %>% mutate(post = as.integer(year >= 2022), per_inv = applications / inventors)
outs <- c("applications", "inventors", "entrants", "incumbents")
fpool <- map_dfr(outs, function(o) {
  m <- fepois(as.formula(paste(o, "~ ban:post | field + year")), data = fy, cluster = ~field)
  tibble(outcome = o, beta = coef(m)[[1]], se = se(m)[[1]])
}) %>% bind_rows({
  m <- feols(log(per_inv) ~ ban:post | field + year, data = fy, cluster = ~field)
  tibble(outcome = "log applications per inventor (OLS)", beta = coef(m)[[1]], se = se(m)[[1]])
}) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
fes <- map_dfr(outs, function(o) {
  m <- fepois(as.formula(paste(o, "~ i(year, ban, ref = 2021) | field + year")), data = fy, cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>% mutate(outcome = o)
}) %>% bind_rows(broom::tidy(feols(log(per_inv) ~ i(year, ban, ref = 2021) | field + year, data = fy, cluster = ~field),
                             conf.int = TRUE) %>% mutate(outcome = "log applications per inventor (OLS)")) %>%
  mutate(year = as.integer(str_extract(term, "\\d{4}")))
fes <- fes %>% bind_rows(distinct(fes, outcome) %>% mutate(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0))
write_csv(fpool, file.path(TAB_DIR, "inventor_field_pooled.csv"))
write_csv(fes %>% select(outcome, year, estimate, std.error, conf.low, conf.high), file.path(TAB_DIR, "inventor_field_es.csv"))
print(fpool %>% mutate(across(where(is.double), ~ round(., 3))))

# ---- (B) inventor cohorts
iv <- iy %>% inner_join(ban, by = "field") %>% group_by(name, year) %>%
  summarise(expo = sum(share * ban), field = field[which.max(w)], ht = first(holder_type_mode),
            common = first(common), .groups = "drop")
act <- iy %>% distinct(name, year)
nxt <- act %>% transmute(name, t = year - 1L, f1 = TRUE) %>%
  full_join(act %>% transmute(name, t = year - 2L, f2 = TRUE), by = c("name", "t")) %>%
  transmute(name, year = t, cont = TRUE) %>% distinct()
co <- iv %>% filter(between(year, 2012, 2022)) %>% left_join(nxt, by = c("name", "year")) %>%
  mutate(cont = as.integer(!is.na(cont)))
cat("Raw continuation rate by cohort:\n")
print(co %>% mutate(terc = ntile(expo, 3)) %>% group_by(year, terc) %>% summarise(r = round(mean(cont), 3), .groups = "drop") %>%
        pivot_wider(names_from = terc, values_from = r, names_prefix = "ban_tercile_") %>%
        left_join(co %>% group_by(year) %>% summarise(all = round(mean(cont), 3), n = n()), by = "year"))
ces_fit <- function(d) feols(cont ~ i(year, expo, ref = 2019) | year + field, data = d, cluster = ~field)
cpool_fit <- function(d) feols(cont ~ expo:post | year + field, cluster = ~field,
                               data = d %>% filter(year != 2020) %>% mutate(post = as.integer(year >= 2021)))
samples <- list("All" = co, "Without common surnames" = filter(co, !common),
                "University" = filter(co, ht == "university"), "Research institute" = filter(co, ht == "research"),
                "Firm" = filter(co, ht == "firm"), "Individual" = filter(co, ht == "individual"))
cpool <- imap_dfr(samples, function(d, nm) map_dfr(c(2012, 2016), function(y0) {
  m <- cpool_fit(filter(d, year >= y0))
  tibble(sample = nm, cohorts = paste0(y0, "-2022"), beta = coef(m)[[1]], se = se(m)[[1]], n = nobs(m),
         base_rate = mean(d$cont[d$year %in% 2016:2019]))
})) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
ces <- imap_dfr(samples[1:2], function(d, nm) broom::tidy(ces_fit(d), conf.int = TRUE) %>% mutate(sample = nm)) %>%
  mutate(year = as.integer(str_extract(term, "\\d{4}")))
ces <- ces %>% bind_rows(distinct(ces, sample) %>% mutate(year = 2019L, estimate = 0, conf.low = 0, conf.high = 0))
write_csv(cpool, file.path(TAB_DIR, "inventor_cont_pooled.csv"))
write_csv(ces %>% select(sample, year, estimate, std.error, conf.low, conf.high), file.path(TAB_DIR, "inventor_cont_es.csv"))
print(cpool %>% mutate(across(where(is.double), ~ round(., 4))))
print(ces %>% filter(sample == "All") %>% arrange(year) %>% select(year, estimate, conf.low, conf.high) %>%
        mutate(across(where(is.double), ~ round(., 4))))

# ---- figures
lab <- c(applications = "Applications", inventors = "Active inventors", entrants = "New inventors",
         incumbents = "Returning inventors", "log applications per inventor (OLS)" = "Applications per inventor (log, OLS)")
p1 <- ggplot(fes %>% mutate(o = factor(lab[outcome], lab)), aes(year, estimate)) +
  geom_hline(yintercept = 0, colour = "grey50") + geom_vline(xintercept = 2021.5, linetype = 2, colour = "grey50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2, fill = "#0072B2") +
  geom_line(colour = "#0072B2") + geom_point(colour = "#0072B2", size = 1.3) + facet_wrap(~o, nrow = 1) +
  scale_x_continuous(breaks = seq(2015, 2024, 3)) +
  labs(x = "Filing year", y = "Effect of 1 SD ban coverage",
       caption = paste("Domestic filings (applications + fast grants), RU inventors identified by full name with patronymic.",
                       "PPML (OLS for per inventor), field + year FE,\n35 WIPO fields, base 2021, 95% CI clustered by field.",
                       "Inventors counted fractionally by their field shares in the year.")) + theme_paper()
save_figure(p1, "fig63_inventor_margins", width = 13, height = 4)
p2 <- ggplot(ces, aes(year, estimate, colour = sample, fill = sample)) +
  geom_hline(yintercept = 0, colour = "grey50") + geom_vline(xintercept = 2019.5, linetype = 3, colour = "grey50") +
  geom_vline(xintercept = 2020.5, linetype = 2, colour = "grey50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.12, colour = NA) + geom_line() + geom_point(size = 1.3) +
  scale_colour_manual(values = c("All" = "#0072B2", "Without common surnames" = "#E69F00"), aesthetics = c("colour", "fill")) +
  scale_x_continuous(breaks = 2012:2022) +
  labs(x = "Cohort: inventors active in year t", y = "Effect of 1 SD exposure on P(files again in t+1 or t+2)",
       colour = NULL, fill = NULL,
       caption = paste("LPM, cohort + modal-field FE, base cohort 2019 (window 2020-21), 95% CI clustered by field.",
                       "Cohort 2020 straddles the war (window 2021-22);\ncohorts 2021-22 are fully post-war.",
                       "Exposure = field-share-weighted ban coverage of the inventor's year-t applications.")) + theme_paper()
save_figure(p2, "fig64_inventor_continuation", width = 8, height = 4.6)
