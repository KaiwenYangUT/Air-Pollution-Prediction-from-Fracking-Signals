#!/usr/bin/env Rscript
# Compare pipeline outputs with (a) the legacy files from the original 2024-25 runs and
# (b) the original notebook code re-run in the current environment.
# Reports ONLY pass/fail, file names, checksums, mismatch counts and numeric differences.
# Never prints or writes data values.
#   Rscript scripts/verify_outputs.R                  # compare
#   Rscript scripts/verify_outputs.R --run-notebook   # first re-run notebooks/02 into outputs/notebooks/
# Writes outputs/verification/report.md and prints a one-line summary per check.
suppressPackageStartupMessages({
  library(data.table)
  library(png)
})
source("R/config.R")

args <- commandArgs(trailingOnly = TRUE)
results <- list()
add <- function(check, file, status, detail = "") {
  results[[length(results) + 1]] <<- data.table(check = check, file = file, status = status, detail = detail)
}
md5 <- function(f) unname(tools::md5sum(f))
`%|%` <- function(x, y) if (identical(x, "")) y else x
fmt <- function(x) format(signif(x, 3), scientific = TRUE)

# ---- (b) optional: re-run the original notebook code ---------------------------------
if ("--run-notebook" %in% args) {
  script <- tempfile(fileext = ".R")
  knitr::purl("notebooks/02_summary_correlation_plots.Rmd", output = script, quiet = TRUE, documentation = 0)
  code <- readLines(script)
  # The notebook's setup chunk changes directory for knitting; run from the repo root instead.
  code <- code[!grepl("opts_knit\\$set\\(root.dir|^owd <- setwd", code)]
  writeLines(c('source("R/config.R")', code), script)
  log <- "outputs/logs/notebook02_baseline.log"
  status <- system2(file.path(R.home("bin"), "Rscript"), script, stdout = log, stderr = log)
  cat("notebook 02 re-run:", if (status == 0) "OK" else "FAILED", "(log:", log, ")\n")
}

# ---- data frames -----------------------------------------------------------------------
# Cell-level comparison; returns counts and max absolute difference only.
# Numbers within a relative tolerance count as equal (newer data.table parses some decimals
# with ~1e-14 differences); `exact_cells` counts any bit-level difference.
compare_columns <- function(a, b, tol = 1e-9) {
  cols <- intersect(names(a), names(b))
  n_bad_cols <- 0L; n_bad_cells <- 0; n_exact <- 0; max_diff <- 0
  for (cn in cols) {
    x <- a[[cn]]; y <- b[[cn]]
    if (inherits(x, "POSIXt") || inherits(x, "Date")) { x <- as.numeric(x); y <- as.numeric(y) }
    if (is.factor(x)) x <- as.character(x)
    if (is.factor(y)) y <- as.character(y)
    if (is.list(x) || is.list(y)) { x <- vapply(x, paste, "", collapse = ","); y <- vapply(y, paste, "", collapse = ",") }
    both_na <- is.na(x) & is.na(y)
    exact <- both_na | (!is.na(x) & !is.na(y) & x == y)
    exact[is.na(exact)] <- FALSE
    same <- exact
    if (is.numeric(x) && is.numeric(y)) {
      close <- !is.na(x) & !is.na(y) & abs(x - y) <= tol * pmax(1, abs(x))
      same <- exact | close
      if (any(!exact)) max_diff <- max(max_diff, max(abs(x - y)[!exact], na.rm = TRUE), na.rm = TRUE)
    }
    n_exact <- n_exact + sum(!exact)
    bad <- sum(!same)
    if (bad > 0) {
      n_bad_cols <- n_bad_cols + 1L
      n_bad_cells <- n_bad_cells + bad
    }
  }
  list(cols = n_bad_cols, cells = n_bad_cells, exact_cells = n_exact, max_diff = max_diff)
}

compare_frames <- function(check, name, a, b) {
  if (identical(a, b)) return(add(check, name, "PASS", "identical()"))
  notes <- c()
  if (!identical(dim(a), dim(b))) notes <- c(notes, sprintf("dims %s vs %s", paste(dim(a), collapse = "x"), paste(dim(b), collapse = "x")))
  if (!identical(names(a), names(b))) notes <- c(notes, sprintf("%d column names differ", length(union(setdiff(names(a), names(b)), setdiff(names(b), names(a))))))
  ca <- vapply(a, function(v) class(v)[1], ""); cb <- vapply(b, function(v) class(v)[1], "")
  common <- intersect(names(ca), names(cb))
  if (any(ca[common] != cb[common])) notes <- c(notes, sprintf("%d column classes differ", sum(ca[common] != cb[common])))
  tz <- function(d) { p <- Filter(function(v) inherits(v, "POSIXct"), d); vapply(p, function(v) attr(v, "tzone") %||% "", "") }
  if (!identical(tz(a), tz(b))) notes <- c(notes, "POSIXct tzone attributes differ")
  if (nrow(a) == nrow(b)) {
    cc <- compare_columns(a, b)
    if (cc$cells == 0 && cc$exact_cells > 0) {
      return(add(check, name, "PASS~", paste(c(sprintf("equal within 1e-9 relative; %s cells differ in the last bits (max abs diff %s)",
                                                         format(cc$exact_cells, big.mark = ","), fmt(cc$max_diff)), notes), collapse = "; ")))
    }
    if (cc$cells == 0) {
      return(add(check, name, if (length(notes)) "PASS*" else "PASS",
                 paste(c("all values equal", notes, "(object attributes differ)"), collapse = "; ")))
    }
    notes <- c(notes, sprintf("%s mismatched cells in %d columns, max abs diff %s", format(cc$cells, big.mark = ","), cc$cols, fmt(cc$max_diff)))
  }
  add(check, name, "FAIL", paste(notes, collapse = "; "))
}

for (f in c("008_097_logged_bb.rdata", "008_097_logged_spectra.rdata", "sound_merge_data.rdata",
            "sound_pollutant_data.rdata", "sound_pollutant_met_data.rdata")) {
  old <- legacy_processed_path(f); new <- processed_path(f)
  if (!file.exists(new)) { add("data", f, "MISSING", "not produced"); next }
  ea <- new.env(); eb <- new.env()
  na <- load(old, envir = ea); nb <- load(new, envir = eb)
  for (o in union(na, nb)) {
    if (!(o %in% na && o %in% nb)) { add("data", paste0(f, ":", o), "FAIL", "object missing in one file"); next }
    compare_frames("data", paste0(f, ":", o), get(o, ea), get(o, eb))
  }
  rm(ea, eb); invisible(gc())
}

# CSVs: checksum first, then a chunked text comparison (files can be ~1 GB).
compare_csv <- function(f, chunk = 200000L) {
  old <- legacy_processed_path(f); new <- processed_path(f)
  if (!file.exists(new)) return(add("data", f, "MISSING", "not produced"))
  if (md5(old) == md5(new)) return(add("data", f, "PASS", paste("md5", md5(new))))
  ha <- names(suppressWarnings(fread(old, nrows = 0L))); hb <- names(suppressWarnings(fread(new, nrows = 0L)))
  common <- intersect(ha, hb)
  header_note <- if (identical(ha, hb)) character() else
    sprintf("columns only in legacy: %s; only in re-run: %s; compared %d shared columns",
            paste(setdiff(ha, hb), collapse = ",") %|% "none", paste(setdiff(hb, ha), collapse = ",") %|% "none", length(common))
  offset <- 0L; bad <- 0; rows_a <- 0L; rows_b <- 0L
  repeat {
    read <- function(p, h) tryCatch(suppressWarnings(fread(p, skip = offset + 1L, nrows = chunk, header = FALSE,
                                                           colClasses = "character", col.names = h, showProgress = FALSE)),
                                    error = function(e) data.table())
    a <- read(old, ha); b <- read(new, hb)
    rows_a <- rows_a + nrow(a); rows_b <- rows_b + nrow(b)
    if (nrow(a) == 0 && nrow(b) == 0) break
    n <- min(nrow(a), nrow(b))
    for (cn in common) bad <- bad + sum(a[[cn]][seq_len(n)] != b[[cn]][seq_len(n)], na.rm = TRUE)
    if (nrow(a) < chunk || nrow(b) < chunk) break
    offset <- offset + chunk
  }
  detail <- paste(c(sprintf("md5 differs; rows %d vs %d; %s cells with different text", rows_a, rows_b, format(bad, big.mark = ",")),
                    header_note), collapse = "; ")
  add("data", f, if (bad == 0 && rows_a == rows_b) "PASS*" else "FAIL", detail)
}
for (f in c("sound_pollutant_data.csv", "sound_pollutant_met_data.csv", "flare_well_sound_pollutant_met_data.csv")) compare_csv(f)

# ---- figures and tables ----------------------------------------------------------------
compare_png <- function(check, name, old, new) {
  if (!file.exists(old)) return(add(check, name, "NO BASELINE"))
  if (!file.exists(new)) return(add(check, name, "MISSING", "not produced"))
  if (md5(old) == md5(new)) return(add(check, name, "PASS", "md5 identical"))
  a <- readPNG(old); b <- readPNG(new)
  if (!identical(dim(a)[1:2], dim(b)[1:2])) return(add(check, name, "FAIL", sprintf("size %s vs %s", paste(dim(a)[1:2], collapse = "x"), paste(dim(b)[1:2], collapse = "x"))))
  k <- min(dim(a)[3], dim(b)[3], 3)
  d <- abs(a[, , 1:k, drop = FALSE] - b[, , 1:k, drop = FALSE])
  frac <- mean(apply(d, c(1, 2), max) > 0)
  add(check, name, if (frac == 0) "PASS*" else "DIFF", sprintf("md5 differs; %.3f%% pixels differ, max channel diff %.3f", 100 * frac, max(d)))
}

compare_html_table <- function(check, name, old, new) {
  if (!file.exists(old)) return(add(check, name, "NO BASELINE"))
  if (!file.exists(new)) return(add(check, name, "MISSING", "not produced"))
  cells <- function(p) { h <- paste(readLines(p, warn = FALSE), collapse = "\n")
    m <- regmatches(h, gregexpr("<td[^>]*>[^<]*</td>", h))[[1]]; trimws(gsub("<[^>]+>", "", m)) }
  a <- cells(old); b <- cells(new)
  if (length(a) != length(b)) return(add(check, name, "FAIL", sprintf("%d vs %d table cells", length(a), length(b))))
  bad <- sum(a != b)
  na <- suppressWarnings(as.numeric(a)); nb <- suppressWarnings(as.numeric(b))
  diff <- if (any(!is.na(na) & !is.na(nb))) max(abs(na - nb), na.rm = TRUE) else 0
  add(check, name, if (bad == 0) "PASS" else "FAIL",
      sprintf("%d table cells, %d differ, max abs numeric diff %s", length(a), bad, fmt(diff)))
}

legacy_fig <- "outputs/legacy/figures"
unfiltered <- list.files(legacy_fig, "^(frequency|nox|met)_.*\\.png$")
for (f in unfiltered) {
  compare_png("figure vs legacy", f, file.path(legacy_fig, f), output_path("figures", f))
  compare_png("figure vs notebook re-run", f, output_path("notebooks", f), output_path("figures", f))
}
subset_figs <- list.files(legacy_fig, "\\.png$", recursive = TRUE)
subset_figs <- subset_figs[startsWith(subset_figs, "subset_")]
for (f in subset_figs) {
  compare_png("figure vs legacy", f, file.path(legacy_fig, f), output_path("figures", f))
}
# The notebook writes both subsets to the same file names, so its re-run only holds the
# second (> 100F) set; compare that one.
for (f in subset_figs[startsWith(subset_figs, "subset_temp_gt100")]) {
  compare_png("figure vs notebook re-run", f, output_path("notebooks", basename(f)), output_path("figures", f))
}

legacy_html <- file.path(cfg$data_root, "legacy_outputs", "html")
for (f in c("frequency_summary_table.html", "pollutant_summary_table.html", "met_summary_table.html",
            "wells_summary_data_table.html", "frequency_summary_data.html")) {
  compare_html_table("table vs legacy", f, file.path(legacy_html, f), output_path("tables", f))
}
for (f in c("pollutant_summary_table.html", "met_summary_table.html")) {
  compare_html_table("table vs notebook re-run", f, output_path("notebooks", f), output_path("tables", f))
}

# ---- report ----------------------------------------------------------------------------
res <- rbindlist(results)
report <- output_path("verification", "report.md")
writeLines(c("# Verification report", "",
             sprintf("Generated %s. PASS = identical; PASS* = equal values/pixels but different bytes or attributes;",
                     format(Sys.time(), "%Y-%m-%d %H:%M")),
             "PASS~ = numbers equal within 1e-9 relative (last-bit parsing differences);",
             "DIFF = rendered image differs; FAIL = values differ. No data values are included.", "",
             "| check | file | status | detail |", "|---|---|---|---|",
             sprintf("| %s | `%s` | %s | %s |", res$check, res$file, res$status, res$detail)), report)
summ <- res[, .N, by = .(check, status)][order(check, status)]
for (i in seq_len(nrow(summ))) cat(sprintf("%-28s %-12s %3d\n", summ$check[i], summ$status[i], summ$N[i]))
cat("Report:", report, "\n")
