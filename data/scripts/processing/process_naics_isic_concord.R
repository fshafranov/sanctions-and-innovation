# 29b_naics_isic_concord.R: NAICS 2017 -> ISIC Rev. 4 (4-digit) weights for the NAICS codes BEA lists (rule IN1).
# R package `concordance`; codes of 2-6 digits passed as listed; weights from the package (all = TRUE).
# Input: data/clean/bea_detail_naics.csv; Output: data/clean/concord_naics17_isic4.csv  naics, isic4, w
library(concordance); library(readr); library(dplyr); library(purrr)
b <- read_csv(here::here("data", "clean", "bea_detail_naics.csv"), col_types = "cc")
codes <- unique(b$naics)
out <- map_dfr(codes, function(cd) {
  r <- tryCatch(concord_naics_isic(cd, origin = "NAICS2017", destination = "ISIC4", dest.digit = 4, all = TRUE),
                error = function(e) NULL)
  if (is.null(r) || is.null(r[[1]]$match) || all(is.na(r[[1]]$match))) return(tibble(naics = cd, isic4 = NA_character_, w = NA_real_))
  tibble(naics = cd, isic4 = r[[1]]$match, w = r[[1]]$weight)
})
write_csv(out, here::here("data", "clean", "concord_naics17_isic4.csv"))
cat("NAICS codes:", length(codes), "| unmatched:", sum(is.na(out$isic4)), "\n")
