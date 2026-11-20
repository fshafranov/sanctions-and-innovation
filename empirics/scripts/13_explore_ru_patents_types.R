# 08_ru_patents_types.R: Russia 2014 within Rospatent, by field and document type (Design D, patents part).
# Data: data/clean/ru_patents_field_year.csv (data/scripts/processing/process_ru_patents_google.py, Google Patents via BigQuery),
#       data/clean/field_dependence.csv (Design A, dep_frontier_z) and ru_patents_e21b_year.csv.
# Questions
#  (1) Did domestic inventions (inv_ru) or utility models (um) shift towards/away from sender-dependent fields
#      after 2014? Event study: log(1+n_kt) ~ sum_t b_t * 1[year = t] * dep_z_k | field + year, base 2013.
#  (2) Substitution through incremental innovation: um relative to inv_ru in dependent fields (triple difference,
#      field x type and year x type and field x year fixed effects).
#  (3) Targeted fields: E21B (oil and gas drilling; 2014 export controls) and food chemistry (field 18; Russia's
#      August 2014 ban on Western food imports) as shares of each type's total.
# Years: filing 2005-2017 for inventions (grant lag p90 4.3 years and Google's RU data end in May 2022, so later
#        filings are truncated); utility models to 2019 (shorter lag). Applications (A) are not used: their number
#        falls from 2014 because fast grants skip the A publication, not because filings fall.
source(here::here("empirics", "scripts", "00_setup.R"))

dep <- read_csv(here("data", "clean", "field_dependence.csv"), show_col_types = FALSE) %>%
  select(field, dep_z = dep_frontier_z)
p <- read_csv(here("data", "clean", "ru_patents_field_year.csv"), show_col_types = FALSE) %>%
  left_join(dep, by = "field") %>%
  filter((type == "inv_ru" & between(year, 2005, 2017)) | (type == "um" & between(year, 2005, 2019)))
TYPE_LAB <- c(inv_ru = "Inventions, Russian holders", um = "Utility models")

# (1) event study by type ---------------------------------------------------------------------------------------
es_one <- function(ty, est) {
  d <- filter(p, type == ty)
  m <- if (est == "OLS log(1+n)") feols(log1p(n) ~ i(year, dep_z, ref = 2013) | field + year, d, cluster = ~field)
       else fepois(n ~ i(year, dep_z, ref = 2013) | field + year, d, cluster = ~field)
  broom::tidy(m, conf.int = TRUE) %>%
    mutate(year = as.integer(str_extract(term, "\\d{4}")), type = ty, est = est)
}
es <- crossing(ty = c("inv_ru", "um"), est = c("OLS log(1+n)", "PPML")) %>% pmap_dfr(~ es_one(..1, ..2)) %>%
  bind_rows(crossing(type = c("inv_ru", "um"), est = c("OLS log(1+n)", "PPML")) %>%
              mutate(year = 2013L, estimate = 0, conf.low = 0, conf.high = 0))
write_csv(es, file.path(TAB_DIR, "ru_types_eventstudy.csv"))

p9 <- ggplot(es, aes(year, estimate)) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_vline(xintercept = 2013.5, linetype = "dashed", colour = "grey60") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2) + geom_line() + geom_point(size = 1) +
  facet_grid(est ~ type, labeller = labeller(type = TYPE_LAB), scales = "free_y") +
  labs(x = "Filing year", y = "Coefficient on dependence (per SD) x year, 2013 = 0",
       title = "Russian patenting by sender dependence of the field, around 2014",
       caption = paste("Rospatent documents via Google Patents (BigQuery), WIPO 35 fields, fractional counts; mass filers dropped.",
                       "Field and year fixed effects;\n95% intervals clustered by field.",
                       "Dependence: share of 2008-13 world PCT filings from 2014 senders (Design A).")) +
  theme_paper()
save_figure(p9, "fig9_ru_types_eventstudy", 8, 5.5)

# (2) utility models relative to inventions ----------------------------------------------------------------------
tri <- p %>% filter(year <= 2017) %>% mutate(um = as.integer(type == "um"), dep_um = dep_z * um)
m_tri <- feols(log1p(n) ~ i(year, dep_um, ref = 2013) | field^type + year^type + field^year, tri, cluster = ~field)
m_tri_post <- feols(log1p(n) ~ dep_um:I(year >= 2014) | field^type + year^type + field^year, tri, cluster = ~field)
tri_tab <- bind_rows(broom::tidy(m_tri, conf.int = TRUE) %>% mutate(model = "event study"),
                     broom::tidy(m_tri_post, conf.int = TRUE) %>% mutate(model = "pooled post"))
write_csv(tri_tab, file.path(TAB_DIR, "ru_types_triple.csv"))
print(tri_tab %>% select(model, term, estimate, std.error, p.value), n = 30)

# (3) targeted fields: shares of each type's total --------------------------------------------------------------
tot <- read_csv(here("data", "clean", "ru_patents_field_year.csv"), show_col_types = FALSE) %>%
  group_by(year, type) %>% summarise(total = sum(n), food = sum(n[field == 18]), .groups = "drop")
e21b <- read_csv(here("data", "clean", "ru_patents_e21b_year.csv"), show_col_types = FALSE)
sh <- tot %>% left_join(e21b, by = c("year", "type")) %>%
  filter(type %in% c("inv_ru", "um", "inv_foreign"), between(year, 2005, 2019)) %>%
  transmute(year, type, `Food chemistry (field 18)` = 100 * food / total,
            `Oil and gas drilling (IPC E21B)` = 100 * n_e21b / total) %>%
  pivot_longer(-c(year, type), names_to = "target", values_to = "share")
write_csv(sh, file.path(TAB_DIR, "ru_targeted_shares.csv"))
p10 <- ggplot(sh, aes(year, share, colour = type)) +
  geom_vline(xintercept = 2013.5, linetype = "dashed", colour = "grey60") +
  geom_line() + geom_point(size = 1) +
  facet_wrap(~target, scales = "free_y") +
  scale_colour_manual(values = c(inv_ru = "#0072B2", um = "#009E73", inv_foreign = "#E69F00"),
                      labels = c(inv_ru = "Inventions, Russian holders", um = "Utility models",
                                 inv_foreign = "Inventions, foreign holders")) +
  labs(x = "Filing year", y = "% of all documents of the type", colour = NULL,
       title = "Fields targeted in 2014: export controls (drilling) and Russia's food import ban",
       caption = paste("E21B: whole counts (any E21B code); food chemistry: fractional WIPO field counts.\n",
                       "Inventions after 2017 and utility models after 2019 truncated by grant lags (not shown).")) +
  theme_paper()
save_figure(p10, "fig10_ru_targeted_shares", 8, 4)
