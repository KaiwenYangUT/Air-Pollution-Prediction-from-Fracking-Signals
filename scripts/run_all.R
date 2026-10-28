#!/usr/bin/env Rscript
# Reproduce all outputs in order. Run from the repo root:
#   Rscript scripts/run_all.R                 # steps 1-5
#   Rscript scripts/run_all.R --with-models   # also step 6 (hours)
#   Rscript scripts/run_all.R --from 3        # resume from step 3
# Each step runs in its own R process (frees memory between steps); its console output
# goes to outputs/logs/<step>.log, never to the terminal, because logs can echo data.
args <- commandArgs(trailingOnly = TRUE)
from <- if ("--from" %in% args) as.integer(args[which(args == "--from") + 1]) else 1L

steps <- c("01_stack_sound.R", "02_merge_sound_pollutant_met.R", "03_summary_tables.R",
           "04_correlation_heatmaps.R", "05_spatial_flare_well.R")
if ("--with-models" %in% args) steps <- c(steps, "06_models.R")

dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
for (step in steps[seq_along(steps) >= from]) {
  log <- file.path("outputs/logs", sub("\\.R$", ".log", step))
  started <- Sys.time()
  status <- system2(file.path(R.home("bin"), "Rscript"), file.path("scripts", step), stdout = log, stderr = log)
  mins <- round(as.numeric(difftime(Sys.time(), started, units = "mins")), 1)
  cat(sprintf("%-34s %s  (%.1f min, log: %s)\n", step, if (status == 0) "OK" else "FAILED", mins, log))
  if (status != 0) quit(status = 1)
}
cat("All steps completed.\n")
