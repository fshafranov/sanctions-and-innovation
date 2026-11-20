# 18g_leave_one_out.R: influence of single fields on the main estimate (session 5). Official IPC, 35 WIPO fields,
# PPML, field + year FE, 2015-2025, Ban_f z-scored (recomputed on the remaining fields), SEs clustered by field.
#  (1) leave one field out (35 re-estimates), both maps
#  (2) drop blocks: life sciences (pharma, biotech, medical technology, analysis of biological materials, organic
#      fine chemistry), the 5 largest fields, telecom/digital/semiconductors/computers (electronics core)
# Output: empirics/results/tables/leave_one_out.csv; fig47_leave_one_out
source(here::here("empirics", "scripts", "00_setup.R"))
pat <- read_csv(here("data", "processed", "official_ipc_panels", "ru_domestic_field_year_official.csv"), show_col_types = FALSE) %>%
  filter(between(year, 2015, 2025))
nm <- read_csv(here("data", "processed", "title_fields", "ru_domestic_field_year_imputed.csv"), show_col_types = FALSE) %>% distinct(field, field_en)
cov <- read_csv(here("data", "processed", "ban_coverage", "field_ban_coverage.csv"), show_col_types = FALSE) %>%
  filter(sample == "manuf", event == "eu2022", year == 2023)
est <- function(mp, drop = integer(0)) {
  b <- cov %>% filter(map == mp, !field %in% drop) %>% transmute(field, ban = as.numeric(scale(coverage)))
  d <- pat %>% inner_join(b, by = "field") %>% mutate(post = as.integer(year >= 2022))
  m <- fepois(n_frac ~ ban:post | field + year, data = d, cluster = ~field)
  tibble(beta = coef(m)[[1]], se = se(m)[[1]], n_fields = n_distinct(d$field))
}
loo <- map_dfr(c("industry", "text"), function(mp) map_dfr(1:35, ~ est(mp, .x) %>% mutate(dropped = .x)) %>% mutate(map = mp)) %>%
  left_join(nm, by = c("dropped" = "field"))
size <- pat %>% filter(year %in% 2019:2021) %>% group_by(field) %>% summarise(n = mean(n_frac)) %>% arrange(desc(n))
blocks <- list("life sciences (5 fields)" = c(11, 13, 14, 15, 16), "5 largest fields" = head(size$field, 5),
               "electronics core: telecom, digital comm., computers, semiconductors" = c(3, 4, 6, 8))
blk <- map_dfr(c("industry", "text"), function(mp) imap_dfr(blocks, ~ est(mp, .x) %>% mutate(dropped_block = .y)) %>% mutate(map = mp))
full <- map_dfr(c("industry", "text"), ~ est(.x) %>% mutate(map = .x))
res <- bind_rows(full %>% mutate(what = "all 35 fields"), loo %>% mutate(what = paste("drop", field_en)),
                 blk %>% mutate(what = paste("drop", dropped_block))) %>%
  mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se)
write_csv(res, file.path(TAB_DIR, "leave_one_out.csv"))
cat("\nLeave-one-out range:\n")
print(loo %>% group_by(map) %>% summarise(min = min(beta), max = max(beta), median = median(beta),
                                          all_ci_below_0 = all(beta + 1.96 * se < 0)) %>% mutate(across(where(is.double), ~ round(., 3))))
cat("\nMost influential fields (industry map):\n")
print(loo %>% filter(map == "industry") %>% mutate(shift = beta - full$beta[full$map == "industry"]) %>%
        arrange(desc(abs(shift))) %>% head(6) %>% select(field_en, beta, se, shift) %>% mutate(across(where(is.double), ~ round(., 3))))
cat("\nBlocks:\n"); print(bind_rows(full %>% mutate(dropped_block = "none"), blk) %>%
                            mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se) %>%
                            select(map, dropped_block, n_fields, beta, lo, hi) %>% mutate(across(where(is.double), ~ round(., 3))), width = Inf)
pd <- loo %>% filter(map == "industry") %>% mutate(lo = beta - 1.96 * se, hi = beta + 1.96 * se,
                                                   field_en = fct_reorder(field_en, beta))
p <- ggplot(pd, aes(beta, field_en)) +
  geom_vline(xintercept = 0, colour = "grey40") +
  geom_vline(xintercept = full$beta[full$map == "industry"], linetype = "dashed", colour = "#D55E00") +
  geom_pointrange(aes(xmin = lo, xmax = hi), size = 0.2, colour = "#0072B2") +
  labs(x = "Estimate without this field (PPML, per SD of ban coverage)", y = "Field dropped",
       caption = "Official IPC, field + year FE, 2015-2025, industry map; dashed: estimate with all 35 fields; 95% CIs clustered by field.") +
  theme_paper()
ggsave(file.path(FIG_DIR, "fig47_leave_one_out.pdf"), p, width = 8, height = 8)
ggsave(file.path(FIG_DIR, "fig47_leave_one_out.png"), p, width = 8, height = 8, dpi = 150)
