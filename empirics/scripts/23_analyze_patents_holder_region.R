# 16f_patents_holder_region.R: EXPLORATORY (session 5). Two extensions of the main test (note 11):
# (A) Holder-type heterogeneity: field x holder type x year panel (firm, university, research institute,
#     individual). PPML with field x holder FE and holder x year FE (+ sector x year x holder variant), Ban_f x
#     Post interacted with holder type; event studies by holder type; Wald test of equal effects.
# (B) Region x field x year: 84 regions x 35 fields x 2015-2025 (zeros filled). PPML with region x field FE and
#     region x year FE (+ sector x year), Ban_f x Post; SEs clustered by field (treatment level) and, as a
#     variant, two-way by field and region.
# Ban_f = EU ban coverage end-2023, industry map (main) and product-name map, manufactured goods, z-scored.
# Output: empirics/results/tables/patents_holder.csv, patents_holder_es.csv, patents_region.csv;
#         fig35_patents_holder_es, fig36_patents_region_es
source(here::here("empirics", "scripts", "00_setup.R"))

cov <- read_csv(here("data", "clean", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
ban <- function(mp) cov %>% filter(map == mp) %>% transmute(field, ban = as.numeric(scale(coverage)))
sector_of <- function(f) cut(f, c(0, 8, 13, 24, 32, 35),
                             labels = c("Electrical", "Instruments", "Chemistry", "Mechanical", "Other"))
YEARS <- 2015:2025
tidy_es <- function(m, ...) broom::tidy(m, conf.int = TRUE) %>% mutate(...)

# ---- (A) holder types ------------------------------------------------------------------------------------------
hol <- read_csv(here("data", "clean", "ru_domestic_field_year_holder.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS, holder_type %in% c("firm", "university", "research", "individual")) %>%
  complete(field = 1:35, year = YEARS, holder_type, fill = list(n = 0))

resA <- map_dfr(c("industry", "text"), function(mp) {
  d <- hol %>% inner_join(ban(mp), by = "field") %>%
    mutate(post = as.integer(year >= 2022), sector = sector_of(field), h = holder_type)
  map_dfr(c("h^year", "h^sector^year"), function(fe) {
    m <- fepois(as.formula(paste("n ~ ban:post:i(h) | field^h +", fe)), data = d, cluster = ~field)
    m0 <- fepois(as.formula(paste("n ~ ban:post | field^h +", fe)), data = d, cluster = ~field)
    tidy_es(m, map = mp, fe = fe) %>%
      mutate(h = str_extract(term, "(firm|university|research|individual)"),
             pooled = coef(m0)[[1]], pooled_se = se(m0)[[1]])
  })
})
write_csv(resA, file.path(TAB_DIR, "patents_holder.csv"))
print(resA %>% select(map, fe, h, estimate, conf.low, conf.high, pooled) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)

# difference university/research vs firm (industry map, year FE): coefficient on ban:post:public
dd <- hol %>% inner_join(ban("industry"), by = "field") %>%
  mutate(post = as.integer(year >= 2022), public = as.integer(holder_type %in% c("university", "research")))
mdiff <- fepois(n ~ ban:post + ban:post:public | field^holder_type + holder_type^year,
                data = filter(dd, holder_type != "individual"), cluster = ~field)
cat("\nUniversities + research institutes minus firms (industry map, year FE):\n"); print(coeftable(mdiff))

esA <- map_dfr(c("firm", "university", "research", "individual"), function(h0) {
  d <- hol %>% filter(holder_type == h0) %>% inner_join(ban("industry"), by = "field") %>%
    mutate(sector = sector_of(field))
  map_dfr(c("year", "sector^year"), function(fe) {
    m <- fepois(as.formula(paste("n ~ i(year, ban, ref = 2021) | field +", fe)), data = d, cluster = ~field)
    tidy_es(m, h = h0, fe = fe) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
      bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0, h = h0, fe = fe))
  })
})
write_csv(esA, file.path(TAB_DIR, "patents_holder_es.csv"))
p <- esA %>% mutate(fe = recode(fe, year = "Field + year FE", `sector^year` = "Field + sector x year FE"),
                    h = factor(h, c("firm", "university", "research", "individual"),
                               c("Firms", "Universities", "Research institutes", "Individuals"))) %>%
  ggplot(aes(year, estimate, colour = fe)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.5), size = 0.2) +
  facet_wrap(~h, nrow = 1) + scale_x_continuous(breaks = seq(2015, 2025, 2)) +
  scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (SD)", colour = NULL,
       caption = "Domestic invention patents by WIPO field and holder type, industry map, base 2021, 95% CIs clustered by field.") +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig35_patents_holder_es.pdf"), p, width = 11, height = 4.5)
ggsave(file.path(FIG_DIR, "fig35_patents_holder_es.png"), p, width = 11, height = 4.5, dpi = 150)

# ---- (B) region x field x year ---------------------------------------------------------------------------------
reg <- read_csv(here("data", "clean", "ru_domestic_region_field_year_imputed.csv"), show_col_types = FALSE) %>%
  filter(year %in% YEARS, !is.na(region)) %>% group_by(region, field, year) %>%
  summarise(n = sum(n_top), .groups = "drop") %>%
  complete(region, field = 1:35, year = YEARS, fill = list(n = 0))
cat("\nregion panel:", nrow(reg), "cells,", n_distinct(reg$region), "regions; share zero", round(mean(reg$n == 0), 2), "\n")

resB <- map_dfr(c("industry", "text"), function(mp) {
  d <- reg %>% inner_join(ban(mp), by = "field") %>% mutate(post = as.integer(year >= 2022), sector = sector_of(field))
  specs <- list(
    "region x field + region x year FE"                 = "region^field + region^year",
    "region x field + region x year + sector x year FE" = "region^field + region^year + sector^year")
  imap_dfr(specs, function(fe, nm) {
    m <- fepois(as.formula(paste("n ~ ban:post |", fe)), data = d)
    tibble(map = mp, spec = nm, beta = coef(m)[[1]], se_field = se(m, cluster = ~field)[[1]],
           se_twoway = se(m, cluster = ~field + region)[[1]], n = nobs(m))
  })
}) %>% mutate(lo = beta - 1.96 * se_field, hi = beta + 1.96 * se_field)
write_csv(resB, file.path(TAB_DIR, "patents_region.csv"))
print(resB %>% mutate(across(where(is.double), ~ round(., 3))), width = Inf)

dB <- reg %>% inner_join(ban("industry"), by = "field") %>% mutate(sector = sector_of(field))
esB <- map_dfr(c("region^year", "region^year + sector^year"), function(fe) {
  m <- fepois(as.formula(paste("n ~ i(year, ban, ref = 2021) | region^field +", fe)), data = dB, cluster = ~field)
  tidy_es(m, fe = fe) %>% mutate(year = as.integer(str_extract(term, "\\d{4}"))) %>%
    bind_rows(tibble(year = 2021L, estimate = 0, conf.low = 0, conf.high = 0, fe = fe))
})
write_csv(esB, file.path(TAB_DIR, "patents_region_es.csv"))
print(esB %>% select(fe, year, estimate, conf.low, conf.high) %>% arrange(fe, year) %>%
        mutate(across(where(is.double), ~ round(., 3))), n = Inf)
p <- esB %>% mutate(fe = recode(fe, `region^year` = "Region x field + region x year FE",
                                `region^year + sector^year` = "... + sector x year FE")) %>%
  ggplot(aes(year, estimate, colour = fe)) +
  geom_hline(yintercept = 0, colour = "grey40") +
  geom_vline(xintercept = 2021.5, linetype = "dotted", colour = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), position = position_dodge(0.4), size = 0.25) +
  scale_x_continuous(breaks = YEARS) + scale_colour_manual(values = c("#0072B2", "#D55E00")) +
  labs(x = "Filing year", y = "PPML coefficient on ban coverage (SD)", colour = NULL,
       caption = "Domestic invention patents, 84 regions x 35 fields, industry map, base 2021, 95% CIs clustered by field.") +
  theme_paper() + theme(legend.position = "top")
ggsave(file.path(FIG_DIR, "fig36_patents_region_es.pdf"), p, width = 8, height = 5)
ggsave(file.path(FIG_DIR, "fig36_patents_region_es.png"), p, width = 8, height = 5, dpi = 150)
