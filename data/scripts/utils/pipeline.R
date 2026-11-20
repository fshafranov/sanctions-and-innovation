# Shared helpers for the replication pipeline (R): logging, assertions, attrition,
# checked merges, variable summaries and results export.
#
# Source from any script run from the project root (run_all.py sets the working
# directory to the root):
#   source(file.path("data", "scripts", "utils", "pipeline.R"))

project_root <- function() {
  d <- normalizePath(getwd())
  repeat {
    if (file.exists(file.path(d, "run_all.py"))) return(d)
    parent <- dirname(d)
    if (parent == d) stop("Could not locate project root (no run_all.py above ", getwd(), ")")
    d <- parent
  }
}

.log_env <- new.env()

# One log per script, overwritten each run (G4, G5).
start_log <- function(script_name, log_dir = file.path("data", "logs")) {
  path <- file.path(project_root(), log_dir, paste0(script_name, ".log"))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(path)) file.remove(path)
  .log_env$path <- path
  log_info("START ", script_name)
  invisible(path)
}

.log_line <- function(level, ...) {
  line <- sprintf("%s | %-7s | %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), level,
                  paste0(..., collapse = ""))
  cat(line, "\n", sep = "")
  if (!is.null(.log_env$path)) cat(line, "\n", sep = "", file = .log_env$path, append = TRUE)
}
log_info <- function(...) .log_line("INFO", ...)
log_warn <- function(...) .log_line("WARNING", ...)
end_log <- function() log_info("END")

check <- function(condition, message) {
  if (!isTRUE(all(condition))) stop("ASSERTION FAILED: ", message, call. = FALSE)
}

log_dim <- function(df, label) log_info(sprintf("%s: %d rows x %d cols", label, nrow(df), ncol(df)))

# ---- attrition (C2) ---------------------------------------------------------
attrition_start <- function(df, label = "start") {
  .log_env$attrition <- data.frame(step = label, before = nrow(df), dropped = 0L,
                                   remaining = nrow(df), stringsAsFactors = FALSE)
  log_info(sprintf("ATTRITION start [%s]: %d obs", label, nrow(df)))
}

filter_logged <- function(df, keep, reason) {
  keep[is.na(keep)] <- FALSE
  before <- nrow(df)
  out <- df[keep, , drop = FALSE]
  row <- data.frame(step = reason, before = before, dropped = before - nrow(out),
                    remaining = nrow(out), stringsAsFactors = FALSE)
  .log_env$attrition <- rbind(.log_env$attrition, row)
  log_info(sprintf("ATTRITION %-40s before=%d dropped=%d remaining=%d",
                   reason, before, before - nrow(out), nrow(out)))
  out
}

attrition_summary <- function() {
  tab <- .log_env$attrition
  tab$cumulative_dropped <- cumsum(tab$dropped)
  check(tab$remaining[1] - sum(tab$dropped) == tail(tab$remaining, 1),
        "attrition does not add up: start - sum(dropped) != final")
  log_info("ATTRITION summary:\n", paste(capture.output(print(tab, row.names = FALSE)), collapse = "\n"))
  invisible(tab)
}

# ---- merges (C2) -------------------------------------------------------------
# validate: "1:1", "1:m", "m:1"; how: "inner", "left", "right", "outer"
merge_checked <- function(x, y, by, how, validate, name = "merge") {
  check(validate %in% c("1:1", "1:m", "m:1"), paste0(name, ": validate must be 1:1, 1:m or m:1"))
  if (validate %in% c("1:1", "1:m")) {
    d <- sum(duplicated(x[, by, drop = FALSE]))
    check(d == 0, sprintf("%s: left keys (%s) not unique (%d duplicates)", name, toString(by), d))
  }
  if (validate %in% c("1:1", "m:1")) {
    d <- sum(duplicated(y[, by, drop = FALSE]))
    check(d == 0, sprintf("%s: right keys (%s) not unique (%d duplicates)", name, toString(by), d))
  }
  log_dim(x, paste(name, "left")); log_dim(y, paste(name, "right"))
  kx <- do.call(paste, c(x[, by, drop = FALSE], sep = "\r"))
  ky <- do.call(paste, c(y[, by, drop = FALSE], sep = "\r"))
  lm <- sum(kx %in% ky); rm <- sum(ky %in% kx)
  log_info(sprintf("%s on (%s) %s how=%s: left matched %d/%d (%.1f%%), left unmatched %d; right matched %d/%d (%.1f%%), right unmatched %d",
                   name, toString(by), validate, how, lm, nrow(x), 100 * lm / max(nrow(x), 1),
                   nrow(x) - lm, rm, nrow(y), 100 * rm / max(nrow(y), 1), nrow(y) - rm))
  out <- merge(x, y, by = by, all.x = how %in% c("left", "outer"),
               all.y = how %in% c("right", "outer"), sort = TRUE)
  log_dim(out, paste(name, "result"))
  out
}

# ---- constructed variables (C3) ---------------------------------------------
summarize_var <- function(df, col, lower = NULL, upper = NULL, inputs = NULL) {
  s <- df[[col]]
  check(is.numeric(s), paste0(col, ": not numeric"))
  n_inf <- sum(is.infinite(s))
  check(n_inf == 0, sprintf("%s: %d infinite values (division by zero / log of 0?)", col, n_inf))
  f <- s[!is.na(s)]
  log_info(sprintf("VAR %s: count=%d mean=%.6g min=%.6g max=%.6g share_missing=%.4f",
                   col, length(f), if (length(f)) mean(f) else NA, if (length(f)) min(f) else NA,
                   if (length(f)) max(f) else NA, mean(is.na(s))))
  if (!is.null(lower)) check(all(f >= lower), sprintf("%s: %d values below %s", col, sum(f < lower), lower))
  if (!is.null(upper)) check(all(f <= upper), sprintf("%s: %d values above %s", col, sum(f > upper), upper))
  if (!is.null(inputs)) {
    implied <- Reduce(`|`, lapply(inputs, function(v) is.na(df[[v]])))
    log_info(sprintf("VAR %s: missing implied by inputs (%s) = %d, additional missing = %d",
                     col, toString(inputs), sum(implied), sum(is.na(s) & !implied)))
    check(!any(!is.na(s) & implied), sprintf("%s: non-missing where an input is missing", col))
  }
}

# ---- results export (D3) -----------------------------------------------------
# Tidy one fixest / lm / glm model into the standard long results format.
tidy_model <- function(model, spec, sample = "main") {
  if (inherits(model, "fixest")) {
    ct <- fixest::coeftable(model)
    r2 <- unname(fixest::r2(model, "r2")); r2w <- unname(fixest::r2(model, "wr2"))
    fe <- if (length(model$fixef_vars)) paste(model$fixef_vars, collapse = "+") else ""
    se_type <- attr(ct, "type"); if (is.null(se_type)) se_type <- ""
    f1 <- NA_real_
    if (!is.null(model$iv) && isTRUE(model$iv) && !is.null(model$iv_first_stage)) {
      # one first-stage F per endogenous regressor; report the weakest
      f1 <- tryCatch(min(vapply(fixest::fitstat(model, "ivf1"), function(e) e$stat, numeric(1))),
                     error = function(e) NA_real_)
    }
  } else {
    ct <- coef(summary(model)); r2 <- summary(model)$r.squared; r2w <- NA_real_
    fe <- ""; se_type <- "iid"; f1 <- NA_real_
  }
  if (is.null(r2)) r2 <- NA_real_
  data.frame(spec = spec, term = rownames(ct), estimate = ct[, 1], std_error = ct[, 2],
             statistic = ct[, 3], p_value = ct[, 4], nobs = nobs(model),
             r2 = r2, r2_within = if (length(r2w)) r2w else NA_real_,
             fstat_first_stage = f1, se_type = se_type, fe = fe, sample = sample,
             row.names = NULL, stringsAsFactors = FALSE)
}

# Deterministic table writer (G4). CSV by default; .dta (via haven) when Stata reads the
# file, in which case every column needs a variable label: labels = c(var = "description").
write_table <- function(df, rel_path, sort_by = NULL, labels = NULL) {
  out <- file.path(project_root(), rel_path)
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  if (length(sort_by)) df <- df[do.call(order, unname(as.list(df[, sort_by, drop = FALSE]))), , drop = FALSE]
  ext <- tolower(tools::file_ext(out))
  if (ext == "csv") {
    write.csv(df, out, row.names = FALSE)
  } else if (ext == "parquet") {
    arrow::write_parquet(df, out)
  } else if (ext == "dta") {
    missing <- setdiff(names(df), names(labels))
    check(length(missing) == 0, paste0(rel_path, ": .dta needs a variable label for every column; missing ", toString(missing)))
    for (v in names(df)) attr(df[[v]], "label") <- labels[[v]]
    haven::write_dta(df, out, version = 15)
  } else stop("unsupported output format: ", ext)
  log_info(sprintf("wrote %s: %d rows x %d cols", rel_path, nrow(df), ncol(df)))
}

write_results <- function(results, rel_path) {
  out <- file.path(project_root(), rel_path)
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  results <- results[order(results$spec, results$term), ]
  write.csv(results, out, row.names = FALSE)
  log_info(sprintf("wrote %s: %d rows", rel_path, nrow(results)))
}

# D4: compare N across specs sharing a sample label; write the differences and any
# captured estimation warnings to empirics/results/warnings/{script}.md (generated).
check_sample_consistency <- function(results, script, warnings_text = character()) {
  out <- character()
  ns <- unique(results[, c("spec", "sample", "nobs")])
  for (s in unique(ns$sample)) {
    sub <- ns[ns$sample == s, ]
    if (length(unique(sub$nobs)) > 1) {
      msg <- sprintf("Sample '%s': N differs across specs: %s", s,
                     paste(sprintf("%s=%d", sub$spec, sub$nobs), collapse = ", "))
      log_warn(msg); out <- c(out, paste0("- ", msg))
    }
  }
  if (length(warnings_text)) out <- c(out, paste0("- estimation warning: ", unique(warnings_text)))
  path <- file.path(project_root(), "empirics", "results", "warnings", paste0(script, ".md"))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(paste0("# Estimation warnings: ", script), "", if (length(out)) out else "- none"), path)
  invisible(out)
}
