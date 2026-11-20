# Check (20 Nov 2026, note 15): does UNbanned Western input access predict more patenting? banned (dep) and unbanned
# (west - dep) Western inputs in one PPML model, industry + year FE, SEs clustered by Rosstat column; sample exclusions.
source(here::here("empirics", "scripts", "00_setup.R"))
pat <- read_csv(here("data", "clean", "industry_year_patents.csv"), show_col_types = FALSE)
cov <- read_csv(here("data", "clean", "industry_ban_coverage.csv"), show_col_types = FALSE)
ru <- read_csv(here("data", "clean", "industry_input_exposure_ru.csv"), show_col_types = FALSE)
keep <- pat %>% filter(between(year, 2015, 2019)) %>% group_by(nace3) %>% summarise(pre = mean(n)) %>% filter(pre >= 10)
base <- pat %>% filter(between(year, 2015, 2025)) %>% complete(nace3, year = 2015:2025, fill = list(n = 0)) %>%
  inner_join(cov %>% filter(west_imports > 0, nace3 %in% keep$nace3), by = "nace3") %>% inner_join(ru, by = "nace3") %>%
  mutate(unb = west - dep, post = as.integer(year >= 2022))
run <- function(d, lab) {
  d <- d %>% mutate(dep_z = as.numeric(scale(dep)), unb_z = as.numeric(scale(unb)))
  m <- fepois(n ~ dep_z:post + unb_z:post | nace3 + year, data = d, cluster = ~rs_col)
  tibble(sample = lab, n_ind = n_distinct(d$nace3), term = c("banned Western inputs", "UNbanned Western inputs"),
         beta = round(coef(m), 3), se = round(se(m), 3), p = round(pvalue(m), 3))
}
u <- distinct(base, nace3, rs_col, dep, unb)
cat("corr(banned, unbanned Western inputs) =", round(cor(u$dep, u$unb), 2), "\n")
print(u %>% arrange(desc(unb)) %>% head(6) %>% mutate(across(c(dep, unb), ~ round(., 3))))
print(bind_rows(run(base, "all 55"),
                run(filter(base, !nace3 %in% c(211, 212)), "without pharma"),
                run(filter(base, !nace3 %in% c(211, 212, 325, 266)), "without pharma, medical instr., electromedical"),
                run(filter(base, nace3 %/% 10 != 10), "without food (division 10)")), width = Inf)
