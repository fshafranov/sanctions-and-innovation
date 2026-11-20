# 00_setup.R: packages, paths, outcome table, figure theme. Sourced by every analysis script.
suppressPackageStartupMessages({
  library(tidyverse)
  library(fixest)
  library(here)
})
setFixest_notes(FALSE)
setFixest_nthreads(1)   # 12 Nov 2026: multithreaded fixest segfaulted inside long purrr loops (03_leave_one_out.R)

FIG_DIR <- here("empirics", "results", "figures"); TAB_DIR <- here("empirics", "results", "tables")
dir.create(FIG_DIR, showWarnings = FALSE, recursive = TRUE); dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)

H_MAX <- 8   # years after the event
LAGS  <- 2   # lags of shock and outcome
PRE   <- 5   # pre-event horizons in LP-DiD, and length of the clean window

# kind: count -> PPML on the level (lags in log(1+y)); LP-DiD on log(1+y) differences
#       log   -> OLS on log(y);  level -> OLS on the level
OUTCOMES <- tribble(
  ~outcome,         ~label,                                         ~kind,   ~block,
  "pat_res",        "Patent applications, residents",               "count", "Patents",
  "pat_nres",       "Patent applications, non-residents",           "count", "Patents",
  "articles_wb",    "Journal articles (NSF/WB, fractional)",        "count", "Science",
  "works_oa",       "Articles and reviews (OpenAlex, full count)",  "count", "Science",
  "intl_share",     "Share internationally co-authored, pp",        "level", "Science",
  "rd_gdp",         "R&D spending, % of GDP",                       "level", "R&D",
  "researchers_pm", "Researchers per million, log",                 "log",   "R&D",
  "hitech_share",   "High-tech exports, % of manuf. exports",       "level", "Trade",
  "ip_pay",         "Payments for foreign IP, log",                 "log",   "Trade",
  "tfp",            "TFP (PWT 11.0, constant national prices), log", "log",  "Productivity"
)

read_panel <- function() {
  read_csv(here("data", "processed", "country_panel", "panel.csv"), show_col_types = FALSE) %>%
    mutate(intl_share = 100 * intl_share) %>%
    arrange(iso3, year)
}

# outcome in the scale used for lags and differences
transform_y <- function(y, kind) switch(kind,
  count = log1p(y),
  log   = ifelse(y > 0, log(y), NA_real_),
  level = y)

theme_paper <- function() {
  theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
          legend.position = "top", plot.caption = element_text(hjust = 0, size = 7.5, colour = "grey30"),
          plot.title.position = "plot", plot.caption.position = "plot")
}
save_figure <- function(plot, name, width = 8, height = 6) {
  ggsave(file.path(FIG_DIR, paste0(name, ".pdf")), plot, width = width, height = height)
  ggsave(file.path(FIG_DIR, paste0(name, ".png")), plot, width = width, height = height, dpi = 200)
}
MEASURE_COLOURS <- c("Western economic" = "#0072B2", "Western arms/travel only (placebo)" = "#E69F00",
                     "Any sender, economic" = "#009E73")
