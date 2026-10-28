#!/usr/bin/env Rscript
# Step 5: flares and wells within 20 km of the trailer, joined to the sound/pollutant/met table.
# Source: archive/private/03_STA465_spatial_flare_well.Rmd and notebooks/04_STA465_appendix.Rmd.
# Outputs: <processed_dir>/flare_well_sound_pollutant_met_data.csv,
#          outputs/tables/{wells_summary_data_table,frequency_summary_data}.html, outputs/maps/*.html
source("R/config.R")
source("R/load.R")
source("R/features.R")
source("R/visualize.R")

pb_vnf <- read_flares()
cb_wells_prod <- read_wells()
b <- spatial_buffer(pb_vnf, cb_wells_prod)

# Maps
save_map(map_flares_wells_buffer(b), output_path("maps", "flares_wells_20km_buffer.html"))
cb_wells_prod_density <- cb_wells_prod %>%
  select(api, uog_lon, uog_lat) %>%
  distinct() %>%
  rename(lon = uog_lon, lat = uog_lat)
save_map(map_density(cb_wells_prod_density), output_path("maps", "wells_density.html"))
save_map(map_density(pb_vnf), output_path("maps", "flares_density.html"))

# Monthly production of wells in the buffer
wells_summary_data <- summarise_wells(b$wells_in_buffer20)
wells_summary_data_table <- wells_summary_data %>%
  st_drop_geometry() %>%
  rename(
    "Year & Month" = month,
    "Number of Oil Wells" = num_oil_wells,
    "Number of Gas Wells" = num_gas_wells,
    "Average Monthly Production of Oil" = avg_monthly_oil,
    "Median Monthly Production of Oil" = median_monthly_oil,
    "IQR of Monthly Oil Production" = iqr_monthly_oil,
    "Average Monthly Production of Gas" = avg_monthly_gas,
    "Median Monthly Production of Gas" = median_monthly_gas,
    "IQR of Monthly Gas Production" = iqr_monthly_gas
  )
save_html_table(wells_summary_data_table, output_path("tables", "wells_summary_data_table.html"))

# Join flares (by date) and wells (by month) to the analysis table
load(processed_path("sound_pollutant_met_data.rdata"))
flare_well_sound_pollutant_met_data <- merge_flare_well_sound(b$flare_points_in_buffer20, wells_summary_data,
                                                              sound_pollutant_met_data)
rm(sound_pollutant_met_data); invisible(gc())

save_html_table(summary_table(flare_well_sound_pollutant_met_data, frequency_variables),
                output_path("tables", "frequency_summary_data.html"))
write.csv(flare_well_sound_pollutant_met_data,
          processed_path("flare_well_sound_pollutant_met_data.csv"))
cat("Step 5 done\n")
