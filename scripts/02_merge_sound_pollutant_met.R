#!/usr/bin/env Rscript
# Step 2: clean sound, pollutant and met data and join them on time.
# Outputs (processed_dir): sound_merge_data.rdata, sound_pollutant_data.{rdata,csv},
#                          sound_pollutant_met_data.{rdata,csv}
source("R/config.R")
source("R/load.R")
source("R/clean.R")
source("R/features.R")

load(processed_path("008_097_logged_spectra.rdata"))
load(processed_path("008_097_logged_bb.rdata"))

sound_merged_data <- clean_sound(logged_spectra_combined, logged_bb_combined)
save(sound_merged_data, file = processed_path("sound_merge_data.rdata"))
rm(logged_spectra_combined, logged_bb_combined)

# The original reloads the saved sound table before merging; do the same so the
# object passed on is exactly what was saved.
load(processed_path("sound_merge_data.rdata"))

sound_pollutant_data <- merge_sound_pollutants(
  sound_merged_data,
  nox_data_reduced = clean_nox(read_pollutant("nox")),
  o3_data = clean_o3(read_pollutant("o3")),
  co_data_reduced = clean_co(read_pollutant("co")),
  h2s_data_reduced = clean_h2s(read_pollutant("h2s")),
  ch4_data_reduced = clean_ch4(read_pollutant("ch4"))
)
rm(sound_merged_data)

sound_pollutant_met_data <- merge_met(clean_met(read_met()), sound_pollutant_data)

save(sound_pollutant_data, file = processed_path("sound_pollutant_data.rdata"))
write.csv(sound_pollutant_data, processed_path("sound_pollutant_data.csv"))
save(sound_pollutant_met_data, file = processed_path("sound_pollutant_met_data.rdata"))
write.csv(sound_pollutant_met_data, processed_path("sound_pollutant_met_data.csv"))
cat("Step 2 done\n")
