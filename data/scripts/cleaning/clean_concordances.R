# 16a_export_concordances.R: product concordances from the R package `concordance` (Liao, Wang, Kim, Steinwender;
# version 2.1.0 from insongkim.r-universe.dev; CRAN 2.0.0 lacks the ISIC tables) -> CSV for 16_hs_field_maps.py.
#   concord_hs22_hs07.csv : HS 2022 6-digit -> HS 2007 6-digit (TN VED product names are HS 2022 based; BACI is HS07)
#   concord_hs_isic4.csv  : HS 6-digit (all vintages pooled, as in the package) -> ISIC Rev.4 4-digit
suppressPackageStartupMessages(library(concordance))
out <- here::here("data", "clean")
data(hs6_hs3); data(hs_isic4)
write.csv(unique(hs6_hs3[, c("HS6_6d", "HS3_6d")]), file.path(out, "concord_hs22_hs07.csv"), row.names = FALSE)
write.csv(unique(hs_isic4[, c("HS_6d", "ISIC4_4d")]), file.path(out, "concord_hs_isic4.csv"), row.names = FALSE)
cat("hs22->hs07 rows:", nrow(unique(hs6_hs3[, c("HS6_6d", "HS3_6d")])),
    " hs->isic4 rows:", nrow(unique(hs_isic4[, c("HS_6d", "ISIC4_4d")])), "\n")
# for 18_parse_eu_bans.py: HS 2012 / 2017 / 2022 6-digit -> HS 2007 (CN codes in the EU annexes follow the HS vintage
# in force: HS2012 until 2016, HS2017 2017-21, HS2022 from 2022)
data(hs4_hs3); data(hs5_hs3)

conc <- rbind(
  data.frame(vintage = "HS2012", src = hs4_hs3$HS4_6d, hs07 = hs4_hs3$HS3_6d),
  data.frame(vintage = "HS2017", src = hs5_hs3$HS5_6d, hs07 = hs5_hs3$HS3_6d),
  data.frame(vintage = "HS2022", src = hs6_hs3$HS6_6d, hs07 = hs6_hs3$HS3_6d))
write.csv(unique(conc), file.path(out, "concord_hsvintage_hs07.csv"), row.names = FALSE)
cat("vintage -> hs07 rows:", nrow(unique(conc)), "\n")
