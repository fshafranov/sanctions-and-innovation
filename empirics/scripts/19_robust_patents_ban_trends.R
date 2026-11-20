# 16b_patents_ban_trends.R: EXPLORATORY trend checks for the main test (not pre-registered; notes/11 §Exploratory).
# The pre-period of the main event study drifts down for high-coverage fields (2015 +0.06 -> 2021 0).
#   (a) field-specific linear trends, 2015-2025;  (b) trend in Ban_f x year estimated on 2015-2021 only and
#   extrapolated (beta = average post deviation from the extrapolated pre-trend); (c) short window 2019-2025.
# Output: empirics/results/tables/patents_ban_trends.csv
source(here::here("empirics", "scripts", "00_setup.R"))
pat <- read_csv(here("data", "processed", "title_fields", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "processed", "ban_coverage", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
out <- map_dfr(c("industry", "text"), function(mp) {
  d <- pat %>% filter(between(year, 2015, 2025)) %>% select(field, year, y = n_top) %>%
    inner_join(cov %>% filter(map == mp) %>% transmute(field, ban = as.numeric(scale(coverage))), by = "field") %>%
    mutate(post = as.integer(year >= 2022), tr = year - 2021)
  a <- fepois(y ~ ban:post | field[tr] + year, data = d, cluster = ~field)
  # (b) linear pre-trend in the ban gradient: ban x tr on 2015-2021, then post deviation from it
  b <- fepois(y ~ ban:tr + ban:post + ban:post:tr | field + year, data = d, cluster = ~field)
  c <- fepois(y ~ ban:post | field + year, data = filter(d, year >= 2019), cluster = ~field)
  bind_rows(
    tibble(spec = "(a) field-specific linear trends", beta = coef(a)[["ban:post"]], se = se(a)[["ban:post"]]),
    tibble(spec = "(b) common pre-trend in ban gradient: post shift", beta = coef(b)[["ban:post"]],
           se = se(b)[["ban:post"]]),
    tibble(spec = "(b) pre-trend slope per year", beta = coef(b)[["ban:tr"]], se = se(b)[["ban:tr"]]),
    tibble(spec = "(b) change in slope after 2022", beta = coef(b)[["ban:tr:post"]], se = se(b)[["ban:tr:post"]]),
    tibble(spec = "(c) window 2019-2025", beta = coef(c)[[1]], se = se(c)[[1]])) %>% mutate(map = mp)
}) %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
write_csv(out, file.path(TAB_DIR, "patents_ban_trends.csv"))
print(out %>% mutate(across(c(beta, se, lo, hi), ~ round(., 3))), width = Inf)
