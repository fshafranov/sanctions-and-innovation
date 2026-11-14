# specifications.R: every dimension along which the cross-country analysis varies; BASE = first option.
# Base definitions stay fixed, variants are added here with date and who asked.

DIMENSIONS <- list(
  measure  = c(west_econ    = "Western economic",                     # user 11 Nov: US/EU/UN + broader Western, trade or financial
               west_placebo = "Western arms/travel only (placebo)",   # no trade/financial measure
               any_econ     = "Any sender, economic"),
  coding   = c(onset     = "Onset (new case in t), panel LP",
               episode5  = "New episode after 5 clean years, LP-DiD", # user 11 Nov
               intensity = "Intensity (cases in force), panel LP"),   # user 11 Nov
  sample   = c(base = "Pop >= 1m, 1995-2023",                         # user 11 Nov (base)
               all  = "All economies, 1995-2023",
               from2000 = "Pop >= 1m, 2000-2023",
               no_chn   = "Pop >= 1m, 1995-2023, without China",            # added 11 Nov (Claude): PPML weight check
               no_big3  = "Pop >= 1m, 1995-2023, without China, Russia, Iran"),
  timing   = c(second = "Shock second", first = "Shock first"),       # LP only
  controls = c(none = "No controls", gdp = "Lagged GDP per capita growth"),
  estimator = c(ppml = "PPML for counts", ols = "OLS on log(1+y) for counts")   # added 11 Nov (Claude)
)
BASE_SPEC <- c(measure = "west_econ", coding = "onset", sample = "base", timing = "second", controls = "none",
               estimator = "ppml")

SAMPLE_RULES <- list(
  base     = list(years = 1995:2023, pop_ge1m = TRUE),
  all      = list(years = 1995:2023, pop_ge1m = FALSE),
  from2000 = list(years = 2000:2023, pop_ge1m = TRUE),
  no_chn   = list(years = 1995:2023, pop_ge1m = TRUE, drop = "CHN"),
  no_big3  = list(years = 1995:2023, pop_ge1m = TRUE, drop = c("CHN", "RUS", "IRN"))
)

# Which runs: every measure x coding x outcome in the base sample; variants of one dimension at a time
# for the main measure.
spec_grid <- function() {
  base <- expand_grid(measure = names(DIMENSIONS$measure), coding = names(DIMENSIONS$coding),
                      sample = "base", timing = "second", controls = "none", estimator = "ppml")
  one_dim <- bind_rows(
    expand_grid(measure = "west_econ", coding = names(DIMENSIONS$coding), sample = c("all", "from2000"),
                timing = "second", controls = "none"),
    expand_grid(measure = "west_econ", coding = c("onset", "intensity"), sample = "base",
                timing = "first", controls = "none"),
    expand_grid(measure = "west_econ", coding = names(DIMENSIONS$coding), sample = "base",
                timing = "second", controls = "gdp"),
    expand_grid(measure = c("west_econ", "west_placebo"), coding = names(DIMENSIONS$coding),
                sample = c("no_chn", "no_big3"), timing = "second", controls = "none"),
    expand_grid(measure = c("west_econ", "west_placebo"), coding = c("onset", "intensity"), sample = "base",
                timing = "second", controls = "none", estimator = "ols"))
  bind_rows(base, one_dim) %>%
    mutate(estimator = coalesce(estimator, "ppml"),
           timing = ifelse(coding == "episode5", "second", timing)) %>%   # timing not defined for LP-DiD
    distinct()
}
