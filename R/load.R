# Data loading. Logic copied from the original notebooks; only file paths changed.

library(data.table)

# Stack every LNM folder's LoggedSpectra and LoggedBB file into two tables.
# Only files named <folder>_LoggedSpectra.txt / <folder>_LoggedBB.txt are read, so files of
# another monitor stored in the same folder (e.g. LNM050 inside LNM049) are not picked up.
# Source: notebooks/01_sound_pollutant_met_merge.Rmd, "Stack" chunk (identical in
# archive/stack_sound_data.Rmd).
stack_sound_logs <- function(raw_dir = raw_path("sound")) {
  # Get a list of all LNM folders
  folders <- list.dirs(raw_dir, recursive = FALSE, full.names = TRUE)

  # Initialize empty lists to store data for the different types of files
  logged_spectra_list <- list()
  logged_bb_list <- list()

  # Initialize vectors to keep track of missing or empty files
  missing_logged_spectra <- c()
  missing_logged_bb <- c()
  empty_logged_spectra <- c()
  empty_logged_bb <- c()

  # Iterate through all folders
  for (folder in folders) {
    # Extract folder name
    folder_name <- basename(folder)

    # Construct file paths for Logged files
    logged_spectra_file <- file.path(folder, paste0(folder_name, "_LoggedSpectra.txt"))
    logged_bb_file <- file.path(folder, paste0(folder_name, "_LoggedBB.txt"))

    # Check and read LoggedSpectra files
    if (file.exists(logged_spectra_file) && file.size(logged_spectra_file) > 0) {
      logged_spectra_data <- fread(logged_spectra_file, fill = TRUE)
      logged_spectra_list[[length(logged_spectra_list) + 1]] <- logged_spectra_data
    } else if (file.exists(logged_spectra_file) && file.size(logged_spectra_file) == 0) {
      empty_logged_spectra <- c(empty_logged_spectra, folder_name)
    } else {
      missing_logged_spectra <- c(missing_logged_spectra, folder_name)
    }

    # Check and read LoggedBB files
    if (file.exists(logged_bb_file) && file.size(logged_bb_file) > 0) {
      logged_bb_data <- fread(logged_bb_file, fill = TRUE)
      logged_bb_list[[length(logged_bb_list) + 1]] <- logged_bb_data
    } else if (file.exists(logged_bb_file) && file.size(logged_bb_file) == 0) {
      empty_logged_bb <- c(empty_logged_bb, folder_name)
    } else {
      missing_logged_bb <- c(missing_logged_bb, folder_name)
    }
  }

  # Report missing or empty files (folder names only)
  cat("Folders without LoggedSpectra:", missing_logged_spectra, "\n")
  cat("Folders with empty LoggedSpectra:", empty_logged_spectra, "\n")
  cat("Folders without LoggedBB:", missing_logged_bb, "\n")
  cat("Folders with empty LoggedBB:", empty_logged_bb, "\n")

  # Stack all the data for each group
  list(
    logged_spectra_combined = rbindlist(logged_spectra_list, fill = TRUE),
    logged_bb_combined = rbindlist(logged_bb_list, fill = TRUE)
  )
}

read_pollutant <- function(name) {
  read.csv(raw_path("pollutants", sprintf("Boulder_AIR_LNM_%s_finalized_1min.csv", name)))
}

read_met <- function() {
  read.csv(raw_path("met", "Boulder_AIR_LNM_met_finalized_1min_w_wvmx.csv"))
}

# Flares (VIIRS nightfire) and well production, restricted to the study period.
# Source: archive/private/03_STA465_spatial_flare_well.Rmd, first chunks.
read_flares <- function() {
  pb_vnf <- readRDS(raw_path("spatial", "pb-vnf_230414-240901.rds"))
  pb_vnf[pb_vnf$date >= "2023-05-01" & pb_vnf$date <= "2024-05-31", ] # study period
}

read_wells <- function() {
  cb_wells_prod <- readRDS(raw_path("spatial", "cb_wells_prod.rds")) # pretty cleaned
  cb_wells_prod[cb_wells_prod$prod_date >= "2023-05-01" & cb_wells_prod$prod_date <= "2024-05-31", ]
}
