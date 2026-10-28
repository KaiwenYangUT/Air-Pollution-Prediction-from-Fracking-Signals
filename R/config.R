# Project configuration and path helpers.
# Reads config.yml (gitignored; copy it from config.example.yml). Expects the working
# directory to be the repo root. Sourcing this file pins the session time zone.

local({
  if (!file.exists("config.yml")) {
    stop("config.yml not found in ", getwd(),
         ": copy config.example.yml to config.yml and set data_root")
  }
})

cfg <- yaml::read_yaml("config.yml")
for (key in c("data_root", "processed_dir", "legacy_processed_dir")) {
  cfg[[key]] <- path.expand(cfg[[key]])
}

# The original notebooks parse sound timestamps with as.POSIXct() and no tz, so the
# result depends on the session time zone. Pin it to what the original runs used.
Sys.setenv(TZ = cfg$sound_tz)

raw_path <- function(...) file.path(cfg$data_root, "raw", ...)

processed_path <- function(...) {
  dir.create(cfg$processed_dir, recursive = TRUE, showWarnings = FALSE)
  file.path(cfg$processed_dir, ...)
}

legacy_processed_path <- function(...) file.path(cfg$legacy_processed_dir, ...)

output_path <- function(...) {
  p <- file.path(cfg$outputs_dir, ...)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  p
}
