#!/usr/bin/env Rscript
# Step 1: stack the raw LNM sound logs.
# Output: <processed_dir>/008_097_logged_{spectra,bb}.rdata
source("R/config.R")
source("R/load.R")

stacked <- stack_sound_logs()
logged_spectra_combined <- stacked$logged_spectra_combined
logged_bb_combined <- stacked$logged_bb_combined

save(logged_spectra_combined, file = processed_path("008_097_logged_spectra.rdata"))
save(logged_bb_combined, file = processed_path("008_097_logged_bb.rdata"))
cat("Step 1 done\n")
