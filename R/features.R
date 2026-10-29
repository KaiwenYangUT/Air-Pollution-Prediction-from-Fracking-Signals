# Analysis tables: merges, subsets and variable lists.
# Logic copied verbatim from the notebooks; see the Source line on each function.

library(dplyr)
library(data.table)

# ---- Variable lists (notebooks/02 and 05) ---------------------------------------------

frequency_variables <- c(
  "LAFmax", "LAFmin", "LCpeak", "LAeq", "LCeq", "LZeq 12.5Hz",
  "LZeq 16Hz", "LZeq 20Hz", "LZeq 25Hz", "LZeq 31.5Hz", "LZeq 40Hz",
  "LZeq 50Hz", "LZeq 63Hz", "LZeq 80Hz", "LZeq 100Hz", "LZeq 125Hz",
  "LZeq 160Hz", "LZeq 200Hz", "LZeq 250Hz", "LZeq 315Hz", "LZeq 400Hz",
  "LZeq 500Hz", "LZeq 630Hz", "LZeq 800Hz", "LZeq 1kHz", "LZeq 1.25kHz",
  "LZeq 1.6kHz", "LZeq 2kHz", "LZeq 2.5kHz", "LZeq 3.15kHz", "LZeq 4kHz",
  "LZeq 5kHz", "LZeq 6.3kHz", "LZeq 8kHz", "LZeq 10kHz", "LZeq 12.5kHz",
  "LZeq 16kHz"
)

nox_frequency_variables <- c(frequency_variables, "nox", "no2")

pollutant_variables <- c(
  "Methane (CH4, ppb)" = "ch4",
  "Carbon Dioxide (CO2, ppm)" = "co2_ppm",
  "Hydrogen Sulfide (H2S, ppb)" = "h2s",
  "Sulfur Dioxide (SO2, ppb)" = "so2",
  "Carbon Monoxide (CO, ppb)" = "co",
  "Ozone (O3, ppb)" = "o3",
  "Nitrogen Oxide (NOx, ppb)" = "nox",
  "Nitric Oxide (NO, ppb)" = "no",
  "Nitrogen Dioxide (NO2, ppb)" = "no2"
)

met_variables <- c(
  "Wind Direction (degrees)" = "wdr_deg",
  "Wind Speed (m/s)" = "wsp_ms",
  "Temperature (F)" = "temp_f",
  "Relative Humidity (%)" = "relh_percent",
  "Solar Radiation (W/m²)" = "solr_W_m2",
  "Pressure (altitude corrected)" = "pressure_altcorr",
  "Rainfall (mm)" = "rain",
  "Water Vapor Mixing Ratio (g/kg)" = "water_vapor_mr_g_kg"
)

nox_met_variables <- c(met_variables, "NOx" = "nox", "NO2" = "no2")

# ---- Sound + pollutant + met merge (notebooks/01, "Merge of all Pollutant" chunks) ------

# Inner joins on time_utc in the original order. H2S is joined without NA removal.
merge_sound_pollutants <- function(sound_merged_data, nox_data_reduced, o3_data,
                                   co_data_reduced, h2s_data_reduced, ch4_data_reduced) {
  # Remove rows with NA values in each dataset
  nox_data_NA_reduced <- na.omit(nox_data_reduced)
  o3_data_NA_reduced <- na.omit(o3_data)
  co_data_NA_reduced <- na.omit(co_data_reduced)
  ch4_data_NA_reduced <- na.omit(ch4_data_reduced)

  # Rename the Start_Time column in sound_merged_data to time_utc to match nox_data_reduced
  colnames(sound_merged_data)[colnames(sound_merged_data) == "Start_Time"] <- "time_utc"

  sound_nox_merged_data <- merge(nox_data_NA_reduced, sound_merged_data, by = "time_utc", all.x = FALSE, all.y = FALSE)

  # First merge o3_data with sound_nox_merged_data, then sequentially merge the others
  merged_data <- merge(o3_data_NA_reduced, sound_nox_merged_data, by = "time_utc", all.x = FALSE, all.y = FALSE)
  merged_data <- merge(co_data_NA_reduced, merged_data, by = "time_utc", all.x = FALSE, all.y = FALSE)
  merged_data <- merge(ch4_data_NA_reduced, merged_data, by = "time_utc", all.x = FALSE, all.y = FALSE)
  merged_data <- merge(h2s_data_reduced, merged_data, by = "time_utc", all.x = FALSE, all.y = FALSE)
  merged_data
}

# The original joins the trimmed (not NA-removed) met table.
merge_met <- function(met_data_reduced, sound_pollutant_data) {
  merge(met_data_reduced, sound_pollutant_data, by = "time_utc", all.x = FALSE, all.y = FALSE)
}

# ---- Temperature / wind subsets (notebooks/02, "Correlation Heat Map (temp ...)") ------

# The original notebook built the "> 100F" subset from the <= 70F rows
# (sound_low_temp[sound_low_temp$wsp_ms <= 7, ]); fixed here to use the > 100F rows.
temp_wind_subsets <- function(sound_pollutant_met_data) {
  sound_low_temp <- sound_pollutant_met_data[sound_pollutant_met_data$temp_f <= 70, ]
  sound_low_temp_ws <- sound_low_temp[sound_low_temp$wsp_ms <= 7, ]
  sound_high_temp <- sound_pollutant_met_data[sound_pollutant_met_data$temp_f > 100, ]
  sound_high_temp_ws <- sound_high_temp[sound_high_temp$wsp_ms <= 7, ]
  list(low_temp_ws = sound_low_temp_ws, high_temp_ws = sound_high_temp_ws)
}

# ---- Flares and wells within 20 km of the trailer (archive/private/03, STA465) ---------

library(sf)

# Site of the monitoring trailer; UTM zone 13N for metric buffers.
central_point <- st_sfc(st_point(c(-104.1089, 32.2961)), crs = 4326)

spatial_buffer <- function(pb_vnf, cb_wells_prod) {
  pb_vnf_high_temp <- pb_vnf %>%
    filter(temp_bb >= 1600)

  central_point_utm <- st_transform(central_point, crs = 32613)
  flare_points_sf <- st_as_sf(pb_vnf_high_temp, coords = c("lon", "lat"), crs = 4326) %>%
    st_transform(crs = 32613)

  # Create a 20 km buffer around the central point
  buffer_20km <- st_buffer(central_point_utm, dist = 20000) # 20 km in meters

  flare_points_in_buffer20 <- flare_points_sf %>%
    st_filter(buffer_20km) %>%
    st_transform(crs = 4326)
  flare_points_outside_buffer <- flare_points_sf %>%
    filter(!st_within(., buffer_20km, sparse = FALSE)) %>%
    st_transform(crs = 4326)

  cb_wells_prod <- cb_wells_prod %>%
    rename(lon = uog_lon, lat = uog_lat)
  well_points_sf <- st_as_sf(cb_wells_prod, coords = c("lon", "lat"), crs = 4326) %>%
    st_transform(crs = 32613)
  wells_in_buffer20 <- well_points_sf %>%
    st_filter(buffer_20km) %>%
    st_transform(crs = 4326)
  wells_outside_buffer <- well_points_sf %>%
    filter(!st_within(., buffer_20km, sparse = FALSE)) %>%
    st_transform(crs = 4326)

  list(
    buffer_20km_wgs84 = st_transform(buffer_20km, crs = 4326),
    central_point_wgs84 = st_transform(central_point, crs = 4326),
    flare_points_in_buffer20 = flare_points_in_buffer20,
    flare_points_outside_buffer = flare_points_outside_buffer,
    wells_in_buffer20 = wells_in_buffer20,
    wells_outside_buffer = wells_outside_buffer
  )
}

# Monthly well production summary for wells inside the buffer.
summarise_wells <- function(wells_in_buffer20) {
  wells_in_buffer20 <- wells_in_buffer20 %>%
    mutate(month = format(prod_date, "%Y-%m")) # Extract month and year from prod_date

  wells_in_buffer20 %>%
    group_by(month) %>%
    summarize(
      num_oil_wells = sum(prod_type_p == "OIL", na.rm = TRUE),
      num_gas_wells = sum(prod_type_p == "GAS", na.rm = TRUE),
      avg_monthly_oil = mean(monthly_oil, na.rm = TRUE),
      median_monthly_oil = median(monthly_oil, na.rm = TRUE),
      iqr_monthly_oil = IQR(monthly_oil, na.rm = TRUE),
      avg_monthly_gas = mean(monthly_gas, na.rm = TRUE),
      median_monthly_gas = median(monthly_gas, na.rm = TRUE),
      iqr_monthly_gas = IQR(monthly_gas, na.rm = TRUE)
    )
}

# Wells are joined by month and flares by calendar date (many-to-many, hence cartesian).
merge_flare_well_sound <- function(flare_points_in_buffer20, wells_summary_data, sound_pollutant_met_data) {
  wells_summary_data_no_geom <- st_drop_geometry(wells_summary_data)

  # Extract the year-month from time_utc in sound_pollutant_met_data
  sound_pollutant_met_data <- sound_pollutant_met_data %>%
    mutate(month = format(time_utc, "%Y-%m"))

  well_sound_pollutant_met_data <- merge(wells_summary_data_no_geom, sound_pollutant_met_data, by = "month", all.x = FALSE, all.y = FALSE)
  well_sound_pollutant_met_data <- well_sound_pollutant_met_data %>%
    mutate(date = as.Date(time_utc))

  setDT(flare_points_in_buffer20)
  setDT(well_sound_pollutant_met_data)
  flare_points_in_buffer20[, date := as.Date(date)]
  well_sound_pollutant_met_data[, date := as.Date(time_utc)]

  merge(
    flare_points_in_buffer20,
    well_sound_pollutant_met_data,
    by = "date",
    all.x = FALSE,
    all.y = FALSE,
    allow.cartesian = TRUE
  )
}
