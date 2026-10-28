# Cleaning steps. Logic copied verbatim from notebooks/01_sound_pollutant_met_merge.Rmd,
# including its quirks (documented inline) so the original outputs are reproduced exactly.

library(dplyr)

# Sound: tidy names, parse time, drop rows without project/time, then join Spectra with BB.
# Start_Time is parsed without a tz, i.e. in the session zone pinned by R/config.R.
clean_sound <- function(logged_spectra_combined, logged_bb_combined) {
  # Step 1: Rename columns to remove spaces
  logged_spectra_combined <- logged_spectra_combined %>%
    rename(Project_Name = `Project Name`, Start_Time = `Start Time`)
  logged_bb_combined <- logged_bb_combined %>%
    rename(Project_Name = `Project Name`, Start_Time = `Start Time`)

  # Step 2: Manipulate "Start Time" so it can be used as time
  logged_spectra_combined$Start_Time <- as.POSIXct(logged_spectra_combined$Start_Time, format = "%m/%d/%Y %I:%M:%S %p")
  logged_bb_combined$Start_Time <- as.POSIXct(logged_bb_combined$Start_Time, format = "%m/%d/%Y %I:%M:%S %p")

  # Drop rows where Project_Name or Start_Time are NA
  logged_bb_combined <- logged_bb_combined[!is.na(logged_bb_combined$Project_Name) & !is.na(logged_bb_combined$Start_Time), ]
  logged_spectra_combined <- logged_spectra_combined[!is.na(logged_spectra_combined$Project_Name) & !is.na(logged_spectra_combined$Start_Time), ]

  # Remove leading/trailing spaces
  logged_spectra_combined$Project_Name <- trimws(logged_spectra_combined$Project_Name)
  logged_bb_combined$Project_Name <- trimws(logged_bb_combined$Project_Name)

  # Step 3: Join on "Project Name" and "Start Time"
  merge(logged_spectra_combined, logged_bb_combined, by = c("Project_Name", "Start_Time"))
}

# Keep rows from the first non-missing value of `column` onwards.
from_first_non_missing <- function(data, column) {
  first_non_missing_index <- which(!is.na(data[[column]]))[1]
  data[first_non_missing_index:nrow(data), ]
}

to_utc <- function(x) as.POSIXct(x, format = "%Y-%m-%d %H:%M", tz = "UTC")

clean_nox <- function(nox_data) {
  nox_data <- nox_data[-1, ] # first row is empty so remove
  nox_data$nox <- as.numeric(nox_data$nox)
  nox_data$no <- as.numeric(nox_data$no)
  nox_data$no2 <- as.numeric(nox_data$no2)
  nox_data_reduced <- from_first_non_missing(nox_data, "nox")
  nox_data_reduced$time_utc <- to_utc(nox_data_reduced$time_utc)
  nox_data_reduced
}

# O3 has no leading-NA trim in the original.
clean_o3 <- function(o3_data) {
  o3_data <- o3_data[-1, ] # first row is empty so remove
  o3_data$o3 <- as.numeric(o3_data$o3)
  o3_data$time_utc <- to_utc(o3_data$time_utc)
  o3_data
}

# CO drops two leading rows (the second is followed by continuous NAs).
clean_co <- function(co_data) {
  co_data <- co_data[-1, ] # first row is empty so remove
  co_data <- co_data[-1, ]
  co_data$co <- as.numeric(co_data$co)
  co_data_reduced <- from_first_non_missing(co_data, "co")
  co_data_reduced$time_utc <- to_utc(co_data_reduced$time_utc)
  co_data_reduced
}

# H2S/SO2 are trimmed from the first non-missing so2 (h2s starts later) and are
# not NA-removed later (the original's "EXCEPTION, do not remove").
clean_h2s <- function(h2s_data) {
  h2s_data <- h2s_data[-1, ] # first row is empty so remove
  h2s_data$h2s <- as.numeric(h2s_data$h2s)
  h2s_data$so2 <- as.numeric(h2s_data$so2)
  h2s_data_reduced <- from_first_non_missing(h2s_data, "so2")
  h2s_data_reduced$time_utc <- to_utc(h2s_data_reduced$time_utc)
  h2s_data_reduced
}

# The original computes a trim on ch4 and then overwrites it with the trim on co2_ppm.
clean_ch4 <- function(ch4_data) {
  ch4_data <- ch4_data[-1, ] # first row is empty so remove
  ch4_data$ch4 <- as.numeric(ch4_data$ch4)
  ch4_data$co2_ppm <- as.numeric(ch4_data$co2_ppm)
  ch4_data_reduced <- from_first_non_missing(ch4_data, "co2_ppm")
  ch4_data_reduced$time_utc <- to_utc(ch4_data_reduced$time_utc)
  ch4_data_reduced
}

# The original computes a trim on wdr_deg and then overwrites it with the trim on wsp_ms.
# Its NA-removed copy (met_data_NA_reduced) is never used, so it is not built here.
clean_met <- function(met_data) {
  met_data <- met_data[-1, ] # first row is empty so remove
  colnames(met_data)[colnames(met_data) == "solr"] <- "solr_W_m2"
  colnames(met_data)[colnames(met_data) == "water_vapor_mr"] <- "water_vapor_mr_g_kg"
  met_data$wdr_deg <- as.numeric(met_data$wdr_deg)
  met_data$wsp_ms <- as.numeric(met_data$wsp_ms)
  met_data$temp_f <- as.numeric(met_data$temp_f)
  met_data$relh_percent <- as.numeric(met_data$relh_percent)
  met_data$solr_W_m2 <- as.numeric(met_data$solr_W_m2)
  met_data$pressure_altcorr <- as.numeric(met_data$pressure_altcorr)
  met_data$rain <- as.numeric(met_data$rain)
  met_data$water_vapor_mr_g_kg <- as.numeric(met_data$water_vapor_mr_g_kg)
  met_data_reduced <- from_first_non_missing(met_data, "wsp_ms")
  met_data_reduced$time_utc <- to_utc(met_data_reduced$time_utc)
  met_data_reduced
}
