# 09_regions_openalex.R: Russian regions around 2022, publications (Design D, first regional look).
# Data: data/raw/openalex/regions/region_year.csv (scripts/data/09_get_openalex_regions.py).
# Exposure E_r (knowledge channel): share of the region's 2019-21 articles co-authored with the 2022 coalition.
# Capacity C_r: region's 2019-21 article output (log), split at the median ("large" vs "small" science base).
# Outcomes 2015-2025: log articles (all); coalition co-authored share (pp); China co-authored share (pp).
# Event study: y_rt ~ sum_t b_t 1[year = t] E_z | region + year, base 2021; and the 2x2 version with
#   1[year = t] x E_z x Large added (does exposure matter differently where capacity is large?).
# Sample: regions with at least 200 articles a year on average in 2019-21. Inference: clustered by region, plus
# a permutation of exposure across regions for the pooled post-2022 coefficient.
source(here::here("scripts", "analysis", "00_setup.R"))
set.seed(20261112)

raw <- read_csv(here("data", "raw", "openalex", "regions", "region_year.csv"), show_col_types = FALSE)

# teams = "all": all articles; "small": articles with <= 50 authors (drops CERN/JINR-type mega-collaborations,
# which carry much of the coalition and China co-authorship). Outputs get the suffix "" or "_small".
run <- function(teams) {
suf <- if (teams == "small") "_small" else ""
r <- raw %>% filter(str_detect(partner, "_small$") == (teams == "small")) %>%
  mutate(partner = str_remove(partner, "_small$")) %>%
  filter(between(year, 2015, 2025)) %>%
  pivot_wider(names_from = partner, values_from = works, values_fill = 0) %>%
  mutate(sh_coal = 100 * coalition / all, sh_china = 100 * china / all)
base <- r %>% filter(between(year, 2019, 2021)) %>% group_by(region) %>%
  summarise(all_pre = mean(all), E = sum(coalition) / sum(all), .groups = "drop") %>%
  filter(all_pre >= 200) %>%
  mutate(E_z = (E - mean(E)) / sd(E), large = as.integer(all_pre >= median(all_pre)))
d <- r %>% inner_join(base, by = "region") %>% mutate(E_large = E_z * large)
cat(n_distinct(d$region), "regions; exposure range", round(range(100 * base$E), 1), "%\n")
write_csv(base, file.path(TAB_DIR, paste0("regions_exposure", suf, ".csv")))

OUT <- c(la = "log articles", sh_coal = "Coalition co-authored, %", sh_china = "China co-authored, %")
d <- d %>% mutate(la = log(all))
es <- map_dfr(names(OUT), function(y) {
  m1 <- feols(as.formula(paste(y, "~ i(year, E_z, ref = 2021) | region + year")), d, cluster = ~region)
  m2 <- feols(as.formula(paste(y, "~ i(year, E_z, ref = 2021) + i(year, E_large, ref = 2021) +",
                               "i(year, large, ref = 2021) | region + year")), d, cluster = ~region)
  bind_rows(broom::tidy(m1, conf.int = TRUE) %>% mutate(model = "exposure"),
            broom::tidy(m2, conf.int = TRUE) %>% filter(str_detect(term, "E_")) %>% mutate(model = "2x2")) %>%
    mutate(outcome = y)
}) %>%
  mutate(year = as.integer(str_extract(term, "\\d{4}")),
         coef = case_when(model == "exposure" ~ "Exposure (all regions)",
                          str_detect(term, "E_large") ~ "Exposure x large science base",
                          TRUE ~ "Exposure (small science base)"))
es <- bind_rows(es, distinct(es, outcome, coef, model) %>% mutate(year = 2021L, estimate = 0, conf.low = 0,
                                                                     conf.high = 0))
write_csv(es, file.path(TAB_DIR, paste0("regions_eventstudy", suf, ".csv")))

p11 <- ggplot(es, aes(year, estimate)) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_vline(xintercept = 2021.5, linetype = "dashed", colour = "grey60") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2) + geom_line() + geom_point(size = 1) +
  facet_grid(outcome ~ coef, scales = "free_y", labeller = labeller(outcome = OUT)) +
  scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  labs(x = "Publication year", y = "Coefficient x year, 2021 = 0",
       title = paste("Russian regions by pre-2022 exposure to coalition co-authors", if (teams == "small") "(teams <= 50 authors)" else "(all articles)"),
       caption = paste("OpenAlex articles and reviews, region of the authors' institutions; exposure = 2019-21",
                       "coalition co-authored share (z-score).\nRegion and year fixed effects; 95% intervals",
                       "clustered by region. Large = above-median 2019-21 output.")) +
  theme_paper()
save_figure(p11, paste0("fig11_regions_eventstudy", suf), 9, 7)

# pooled post-2022 and permutation of exposure across regions -------------------------------------------------
pooled <- function(dd) map_dbl(names(OUT), function(y)
  coef(feols(as.formula(paste(y, "~ E_z:I(year >= 2022) | region + year")), dd, cluster = ~region))[1])
obs <- pooled(d)
perm <- replicate(500, {
  sh <- base %>% mutate(E_z = sample(E_z))
  pooled(r %>% inner_join(sh, by = "region") %>% mutate(la = log(all)))
})
perm_tab <- tibble(outcome = names(OUT), estimate = obs,
                   p_perm = map_dbl(seq_along(obs), ~ mean(abs(perm[.x, ]) >= abs(obs[.x]))))
write_csv(perm_tab, file.path(TAB_DIR, paste0("regions_pooled_perm", suf, ".csv")))
print(perm_tab)
print(es %>% filter(year >= 2017) %>% select(outcome, coef, year, estimate, conf.low, conf.high) %>%
        mutate(across(where(is.double), ~ round(.x, 3))) %>% arrange(outcome, coef, year), n = 120)
}
run("all")
run("small")
