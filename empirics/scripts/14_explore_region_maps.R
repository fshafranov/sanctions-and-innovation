# 10_region_maps.R: maps of Russian regions' exposure to the West and of changes in patents and papers after 2022
# (Design D). Data: data/processed/region_panel/region_exposure.csv, region_year_panel.csv (data/scripts/processing/process_region_panel.py);
# boundaries: GADM 4.1 level 1 (data/raw/gadm; 83 regions, Crimea not included).
# Exposure (pre-2022): X1 science = coalition co-authored share of small-team articles 2019-21;
#                      X2 invention = share of Russian-holder patents filed 2012-21 with a coalition co-inventor or
#                      co-holder. Trade exposure not built (regional customs data by partner not accessible).
# Change: log(2022-24 / 2019-21) minus the national log change; domestic invention grants by filing year (mass
#   filers dropped) and small-team articles. Regions with < 30 in 2019-21 are left blank.
# Event study: domestic patents (PPML) and articles by year x exposure (z), region and year FE, base = year before.
# Two episodes: 2022 (pre 2019-21, post 2022-24) and 2014 (pre 2011-13, post 2014-16; outputs suffixed _2014).
source(here::here("empirics", "scripts", "00_setup.R"))
suppressPackageStartupMessages({ library(sf); library(patchwork) })
sf_use_s2(FALSE)

# GADM HASC -> ISO 3166-2 (GADM labels Moscow Oblast "Moskva" and leaves Moscow city without a HASC code)
HASC <- c(AD = "AD", AL = "ALT", AM = "AMU", AR = "ARK", AS = "AST", BK = "BA", BL = "BEL", BR = "BRY", BU = "BU",
          CN = "CE", CL = "CHE", CK = "CHU", CV = "CU", SP = "SPE", DA = "DA", GA = "AL", IN = "IN", IK = "IRK",
          IV = "IVA", KB = "KB", KN = "KGD", KL = "KL", KG = "KLU", KQ = "KAM", KC = "KC", KI = "KR", KE = "KEM",
          KH = "KHA", KK = "KK", KM = "KHM", KV = "KIR", KO = "KO", KT = "KOS", KD = "KDA", KX = "KYA", KU = "KGN",
          KS = "KRS", LN = "LEN", LP = "LIP", MG = "MAG", ME = "ME", MR = "MO", MS = "MOS", MM = "MUR", NN = "NEN",
          NZ = "NIZ", NO = "SE", NG = "NGR", NS = "NVS", OM = "OMS", OL = "ORL", OB = "ORE", PZ = "PNZ", PE = "PER",
          PR = "PRI", PS = "PSK", RO = "ROS", RZ = "RYA", SK = "SA", SL = "SAK", SA = "SAM", SR = "SAR", SM = "SMO",
          ST = "STA", SV = "SVE", TB = "TAM", TT = "TA", TO = "TOM", TL = "TUL", TU = "TY", TV = "TVE", TY = "TYU",
          UD = "UD", UL = "ULY", VL = "VLA", VG = "VGG", VO = "VLG", VR = "VOR", YN = "YAN", YS = "YAR", YV = "YEV",
          ZB = "ZAB")
CRS <- "+proj=aea +lat_1=52 +lat_2=64 +lat_0=0 +lon_0=100 +datum=WGS84 +units=m"
geo <- st_read(here("data", "raw", "gadm", "gadm41_RUS_1.json"), quiet = TRUE) %>%
  mutate(h = str_remove(HASC_1, "^RU\\."),
         iso = if_else(NAME_1 == "MoscowCity", "RU-MOW", paste0("RU-", HASC[h]))) %>%
  st_make_valid() %>% st_transform(CRS) %>% st_simplify(dTolerance = 2000, preserveTopology = TRUE) %>% select(iso, NAME_1)
stopifnot(!anyDuplicated(geo$iso), !any(str_detect(geo$iso, "NA")), nrow(geo) == 83)

EPISODES <- list(
  list(ep = 2022, suf = "", pre_l = "2019-21", post_l = "2022-24", sci_l = "2019-21", link_l = "2012-21",
       cmp_pat = "Filed 2022-24 vs 2019-21", cmp_pub = "Published 2022-24 vs 2019-21", base = 2021,
       es_from = 2015, es_to = 2025, es_pat_to = 2024,
       note = "Grants up to Oct 2026; 2022-24 filings nearly complete."),
  list(ep = 2014, suf = "_2014", pre_l = "2011-13", post_l = "2014-16", sci_l = "2012-13", link_l = "2006-13",
       cmp_pat = "Filed 2014-16 vs 2011-13", cmp_pub = "Published 2014-16 vs 2012-13", base = 2013,
       es_from = 2008, es_to = 2019, es_pat_to = 2019,
       note = "Articles: OpenAlex indexing of Russian journals grew fast in these years; read with care."))

run_episode <- function(E) {
  ex <- read_csv(here("data", "processed", "region_panel", paste0("region_exposure", E$suf, ".csv")), show_col_types = FALSE)
  stopifnot(all(geo$iso %in% ex$iso))
  ex <- ex %>% mutate(name_en = str_replace_all(name_en, "\u2013", "-"), pat_pc_pre = na_if(pat_pc_pre, 0),
                # thin bases are left blank: < 300 small-team articles, < 100 Russian-held patents in the exposure window
                across(c(x_science, x_china_sci), ~ if_else(pub_all_small_pre >= 300, .x, NA_real_)),
                x_invent = if_else(n_ruh_pat_link >= 100, x_invent, NA_real_))
  m <- geo %>% left_join(ex, by = "iso")

  cap_src <- paste("Boundaries: GADM 4.1 (Crimea not shown). Patents: Rospatent open register of granted inventions",
                   "(2 Nov 2026), region from the postal code of the correspondence address.\nArticles: OpenAlex,",
                   "articles and reviews with <= 50 authors, region of the institution. 2022 coalition = EU, US, UK,",
                   "Canada, Japan, Korea, Taiwan, Singapore, Australia, NZ, CH, NO, IS, LI.")

  map_theme <- function() theme_void(base_size = 10) +
    theme(legend.position = "bottom", legend.key.width = unit(1.4, "cm"), legend.key.height = unit(0.25, "cm"),
          plot.title = element_text(face = "bold", size = 10), plot.subtitle = element_text(size = 8.5, colour = "grey30"),
          plot.caption = element_text(hjust = 0, size = 7, colour = "grey30"), plot.caption.position = "plot",
          legend.title = element_text(size = 8), legend.text = element_text(size = 7.5))
  seq_map <- function(var, title, sub, lab, pct = TRUE, trans = "identity") {
    ggplot(m) + geom_sf(aes(fill = .data[[var]]), colour = "white", linewidth = 0.1) +
      scale_fill_distiller(palette = "Blues", direction = 1, na.value = "grey85", trans = trans,
                           labels = if (pct) scales::label_percent(accuracy = 0.1) else scales::label_comma(),
                           name = lab, guide = guide_colourbar(title.position = "top")) +
      labs(title = title, subtitle = sub) + map_theme()
  }
  div_map <- function(var, title, sub, lim = 0.6) {
    ggplot(m) + geom_sf(aes(fill = pmax(pmin(.data[[var]], lim), -lim)), colour = "white", linewidth = 0.1) +
      scale_fill_gradient2(low = "#B2182B", mid = "grey93", high = "#2166AC", midpoint = 0, limits = c(-lim, lim),
                           na.value = "grey80", name = "log change relative to Russia (capped at +/-0.6)",
                           guide = guide_colourbar(title.position = "top")) +
      labs(title = title, subtitle = sub) + map_theme()
  }

  # fig12: exposure ------------------------------------------------------------------------------------------------
  p12 <- (seq_map("x_science", "A. Science: co-authorship with the 2022 coalition",
                  paste0("Share of articles with a coalition co-author, ", E$sci_l, " (grey: < 300 articles)"), "share of articles") |
          seq_map("x_invent", "B. Invention: co-invention with the 2022 coalition",
                  paste0("Share of Russian-held patents filed ", E$link_l, " with a coalition co-inventor or co-holder (grey: < 100)"),
                  "share of patents")) /
         (seq_map("x_china_sci", "C. For comparison: co-authorship with China",
                  paste0("Share of the region's articles with a Chinese co-author, ", E$sci_l), "share of articles") |
          seq_map("pat_pc_pre", "D. Capacity: domestic patents per million people",
                  paste0("Granted inventions filed ", E$pre_l, ", per year"), "patents per million", pct = FALSE, trans = "log10")) +
    plot_annotation(title = paste("Russian regions' exposure to the West before", E$ep), caption = cap_src,
                    theme = theme(plot.title = element_text(face = "bold", size = 12),
                                  plot.caption = element_text(hjust = 0, size = 7, colour = "grey30")))
  save_figure(p12, paste0("fig12_region_exposure_maps", E$suf), 12, 8.5)

  # fig13: changes -------------------------------------------------------------------------------------------------
  p13 <- (div_map("dlog_pat", "A. Domestic patents (all holders)", E$cmp_pat) |
          div_map("dlog_pat_firm", "B. Domestic patents held by firms", E$cmp_pat)) /
         (div_map("dlog_pat_university", "C. Domestic patents held by universities", E$cmp_pat) |
          div_map("dlog_pub_all_small", "D. Articles (teams <= 50 authors)", E$cmp_pub)) +
    plot_annotation(title = paste("Where Russian inventing and publishing grew or shrank after", E$ep),
                    subtitle = paste0("Blue = grew faster than Russia as a whole; red = slower. Grey = fewer than 30 in ", E$pre_l,
                                      ". Patents by filing year. ", E$note),
                    caption = cap_src,
                    theme = theme(plot.title = element_text(face = "bold", size = 12),
                                  plot.subtitle = element_text(size = 9, colour = "grey30"),
                                  plot.caption = element_text(hjust = 0, size = 7, colour = "grey30")))
  save_figure(p13, paste0("fig13_region_change_maps", E$suf), 12, 8.5)

  # fig14: ranking of regions (Moscow and St Petersburg are too small to see on a map) ----------------------------
  rk <- ex %>% filter(!is.na(dlog_pat)) %>%
    transmute(name_en, district, pat_pre, Patents = dlog_pat, `Firm patents` = dlog_pat_firm,
              Articles = dlog_pub_all_small) %>%
    mutate(name_en = fct_reorder(paste0(name_en, " (", scales::comma(pat_pre), ")"), Patents)) %>%
    pivot_longer(c(Patents, `Firm patents`, Articles), names_to = "outcome") %>%
    mutate(outcome = factor(outcome, c("Patents", "Firm patents", "Articles")))
  p14 <- ggplot(rk, aes(value, name_en)) +
    geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_segment(aes(x = 0, xend = value, yend = name_en), colour = "grey70", linewidth = 0.3) +
    geom_point(aes(colour = value > 0), size = 1.6, show.legend = FALSE) +
    scale_colour_manual(values = c(`TRUE` = "#2166AC", `FALSE` = "#B2182B")) +
    facet_wrap(~outcome, nrow = 1) +
    labs(x = paste("log change", E$post_l, "vs", E$pre_l, "relative to Russia"), y = NULL,
         title = paste("Regions ranked by the change in domestic patents after", E$ep),
         subtitle = paste0("Regions with >= 30 domestic patents filed ", E$pre_l, " (number in brackets); firm patents shown where >= 30"),
         caption = cap_src) +
    theme_paper() + theme(axis.text.y = element_text(size = 6.5))
  save_figure(p14, paste0("fig14_region_change_ranking", E$suf), 10, 11)

  # fig15: exposure vs change --------------------------------------------------------------------------------------
  sc <- ex %>% filter(!is.na(dlog_pat)) %>%
    select(name_en, x_science, x_invent, pat_pre, dlog_pat, dlog_pat_firm, dlog_pub_all_small) %>%
    pivot_longer(c(dlog_pat, dlog_pat_firm, dlog_pub_all_small), names_to = "outcome", values_to = "change") %>%
    pivot_longer(c(x_science, x_invent), names_to = "exposure", values_to = "x") %>%
    filter(!is.na(change)) %>%
    mutate(outcome = recode(outcome, dlog_pat = "Patents", dlog_pat_firm = "Firm patents",
                            dlog_pub_all_small = "Articles"),
           exposure = recode(exposure, x_science = "Science exposure (co-authorship)",
                             x_invent = "Invention exposure (co-invention)"))
  slopes <- sc %>% group_by(exposure, outcome) %>%
    group_modify(~ broom::tidy(lm(change ~ x, data = .x, weights = log(pat_pre)), conf.int = TRUE) %>%
                   filter(term == "x")) %>% ungroup()
  write_csv(slopes, file.path(TAB_DIR, paste0("region_exposure_change_slopes", E$suf, ".csv")))
  lab <- sc %>% group_by(exposure, outcome) %>% slice_max(abs(change) + 5 * x, n = 5)
  p15 <- ggplot(sc, aes(x, change)) +
    geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_point(aes(size = pat_pre), alpha = 0.5, colour = "#2166AC") +
    geom_smooth(aes(weight = log(pat_pre)), method = "lm", formula = y ~ x, colour = "black", linewidth = 0.5) +
    ggrepel::geom_text_repel(data = lab, aes(label = name_en), size = 2.3, colour = "grey20", min.segment.length = 0) +
    facet_grid(outcome ~ exposure, scales = "free_x") +
    scale_x_continuous(labels = scales::label_percent(accuracy = 0.1)) +
    scale_size_area(max_size = 5, name = paste("domestic patents", E$pre_l), breaks = c(100, 1000, 10000)) +
    labs(x = paste("Exposure before", E$ep), y = paste("log change", E$post_l, "vs", E$pre_l, "relative to Russia"),
         title = paste0("Did regions more tied to the West lose or gain after ", E$ep, "?"),
         subtitle = "One point per region; line = weighted linear fit (weights log patents before) with 95% band",
         caption = cap_src) +
    theme_paper()
  save_figure(p15, paste0("fig15_region_exposure_vs_change", E$suf), 10, 9)

  # event study: region x year ------------------------------------------------------------------------------------
  pan <- read_csv(here("data", "processed", "region_panel", "region_year_panel.csv"), show_col_types = FALSE) %>%
    filter(between(year, E$es_from, E$es_to)) %>%
    inner_join(ex %>% filter(pat_pre >= 30) %>% select(iso, x_science, x_invent), by = "iso") %>%
    mutate(xs = (x_science - mean(x_science, na.rm = TRUE)) / sd(x_science, na.rm = TRUE),
           xi = (x_invent - mean(x_invent, na.rm = TRUE)) / sd(x_invent, na.rm = TRUE))
  OUTS <- c(pat = "Domestic patents", pat_firm = "Firm patents", pat_university = "University patents",
            pub_all_small = "Articles (<= 50 authors)")
  es <- map_dfr(names(OUTS), function(y) map_dfr(c(xs = "Science exposure", xi = "Invention exposure"), function(lbl) {
    v <- names(which(c(xs = "Science exposure", xi = "Invention exposure") == lbl))
    dd <- pan %>% filter(if (y == "pub_all_small") year >= 2012 else year <= E$es_pat_to)
    f <- fepois(as.formula(paste0(y, " ~ i(year, ", v, ", ref = ", E$base, ") | iso + year")), dd, cluster = ~iso)
    broom::tidy(f, conf.int = TRUE) %>% mutate(outcome = OUTS[y], exposure = lbl)
  })) %>% mutate(year = as.integer(str_extract(term, "\\d{4}")))
  es <- bind_rows(es, distinct(es, outcome, exposure) %>% mutate(year = as.integer(E$base), estimate = 0, conf.low = 0, conf.high = 0))
  write_csv(es, file.path(TAB_DIR, paste0("region_patents_eventstudy", E$suf, ".csv")))
  p16 <- ggplot(es, aes(year, estimate)) +
    geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_vline(xintercept = E$base + 0.5, linetype = "dashed", colour = "grey60") +
    geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2) + geom_line() + geom_point(size = 1) +
    facet_grid(exposure ~ outcome) + scale_x_continuous(breaks = seq(E$es_from, E$es_to, 2)) +
    labs(x = "Filing / publication year", y = paste0("PPML coefficient x year (per SD of exposure), ", E$base, " = 0"),
         title = paste0("Regional patents and articles by pre-", E$ep, " exposure to the West"),
         caption = paste0("Regions with >= 30 domestic patents filed ", E$pre_l, ". Region and year fixed effects; 95% intervals",
                         " clustered by region. Articles from 2012 (OpenAlex series start); patents to ", E$es_pat_to, ".")) +
    theme_paper()
  save_figure(p16, paste0("fig16_region_patents_eventstudy", E$suf), 11, 6)

  print(slopes %>% mutate(across(where(is.double), ~ round(.x, 3))))
  print(es %>% filter(year >= E$base - 3) %>% select(exposure, outcome, year, estimate, conf.low, conf.high) %>%
          mutate(across(where(is.double), ~ round(.x, 3))) %>% arrange(exposure, outcome, year), n = 100)
  print(ex %>% filter(!is.na(dlog_pat)) %>% arrange(desc(dlog_pat)) %>%
          select(name_en, pat_pre, pat_post, dlog_pat, dlog_pat_firm, dlog_pat_university, dlog_pub_all_small,
                 x_science, x_invent) %>% mutate(across(where(is.double), ~ round(.x, 3))), n = 80)
}
for (E in EPISODES) run_episode(E)
