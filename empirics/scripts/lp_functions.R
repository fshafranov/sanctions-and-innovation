# lp_functions.R: estimation functions shared by 02_cross_country_lp.R and 03_leave_one_out.R
# (model definitions are in the header of 02_cross_country_lp.R)

shift <- function(x, k) if (k >= 0) dplyr::lead(x, k) else dplyr::lag(x, -k)

prep <- function(panel, outcome, kind, measure, sample) {
  rule <- SAMPLE_RULES[[sample]]
  panel %>%
    group_by(iso3) %>%
    mutate(y = .data[[outcome]], yy = transform_y(y, kind),
           yy_l1 = lag(yy, 1), yy_l2 = lag(yy, 2),
           new = .data[[paste0("new_", measure)]], act = .data[[paste0("n_active_", measure)]],
           ep = coalesce(.data[[paste0("episode5_", measure)]], 0),
           gdp_g_l1 = lag(log(gdppc), 1) - lag(log(gdppc), 2)) %>%
    ungroup() %>%
    mutate(in_sample = year %in% rule$years & (!rule$pop_ge1m | pop_ge1m == 1) & !iso3 %in% rule$drop)
}

tidy_fit <- function(fit, h, shock_name, used) {
  if (is.null(fit) || !(shock_name %in% names(coef(fit)))) return(tibble(horizon = h, estimate = NA, se = NA))
  tibble(horizon = h, estimate = unname(coef(fit)[shock_name]), se = unname(se(fit)[shock_name]),
         n_obs = nobs(fit), n_countries = n_distinct(used$iso3),
         n_events = if (shock_name == "s") sum(used$s > 0, na.rm = TRUE) else sum(used$ep == 1),
         n_event_countries = if (shock_name == "s") n_distinct(used$iso3[used$s > 0]) else
           n_distinct(used$iso3[used$ep == 1]))
}

lp_path <- function(d, kind, shock, timing, controls, estimator = "ppml") {
  if (kind == "count" && estimator == "ols") kind <- "log1p"   # OLS on log(1+y); yy is already log(1+y)
  d <- d %>% group_by(iso3) %>% mutate(s = .data[[shock]], s_l1 = lag(s, 1), s_l2 = lag(s, 2)) %>% ungroup()
  rhs <- c("s", "s_l1", "s_l2", "yy_l1", "yy_l2", if (timing == "second") "yy", if (controls == "gdp") "gdp_g_l1")
  hs <- if (timing == "second") 1:H_MAX else 0:H_MAX
  out <- map_dfr(hs, function(h) {
    dh <- d %>% group_by(iso3) %>%
      mutate(dep = if (kind == "count") lead(y, h) else lead(yy, h)) %>% ungroup() %>%
      filter(in_sample) %>% drop_na(all_of(c("dep", rhs)))
    f <- as.formula(paste("dep ~", paste(rhs, collapse = " + "), "| iso3 + year"))
    fit <- tryCatch(if (kind == "count") fepois(f, dh, cluster = ~iso3) else feols(f, dh, cluster = ~iso3),
                    error = function(e) NULL)
    used <- if (is.null(fit)) dh[0, ] else dh[obs(fit), ]
    tidy_fit(fit, h, "s", used)
  })
  if (timing == "second") out <- bind_rows(tibble(horizon = 0, estimate = 0, se = 0), out)  # b_0 = 0 by construction
  out
}

lpdid_path <- function(d, controls) {
  out <- map_dfr(c(-PRE:-2, 0:H_MAX), function(h) {
    offsets <- (-PRE):max(h, 0)
    dh <- d %>% group_by(iso3) %>%
      mutate(dy = shift(yy, h) - lag(yy, 1),
             clean = reduce(map(offsets, function(k) { v <- shift(act, k); !is.na(v) & v == 0 }), `&`)) %>%
      ungroup() %>%
      filter(in_sample, ep == 1 | clean, !is.na(dy), controls == "none" | !is.na(gdp_g_l1))
    f <- as.formula(paste("dy ~ ep", if (controls == "gdp") "+ gdp_g_l1", "| year"))
    fit <- tryCatch(feols(f, dh, cluster = ~iso3), error = function(e) NULL)
    used <- if (is.null(fit)) dh[0, ] else dh[obs(fit), ]
    tidy_fit(fit, h, "ep", used)
  })
  bind_rows(tibble(horizon = -1, estimate = 0, se = 0), out) %>% arrange(horizon)
}

run_one <- function(panel, spec, outcome, kind) {
  d <- prep(panel, outcome, kind, spec$measure, spec$sample)
  res <- switch(spec$coding,
    onset     = lp_path(d, kind, "new", spec$timing, spec$controls, spec$estimator),
    intensity = lp_path(d, kind, "act", spec$timing, spec$controls, spec$estimator),
    episode5  = lpdid_path(d, spec$controls))
  bind_cols(as_tibble(spec), outcome = outcome, res)
}
