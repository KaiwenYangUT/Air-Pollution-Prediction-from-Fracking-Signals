#!/usr/bin/env Rscript
# Step 3: summary tables of the main analysis table.
# Outputs: outputs/tables/{frequency,pollutant,met}_summary_table.html
source("R/config.R")
source("R/features.R")
source("R/visualize.R")

load(processed_path("sound_pollutant_met_data.rdata"))

# frequency table: its save_kable() line was commented out in the last notebook version,
# but the file exists from an earlier run, so it is regenerated for completeness.
save_html_table(summary_table(sound_pollutant_met_data, frequency_variables),
                output_path("tables", "frequency_summary_table.html"))
save_html_table(summary_table(sound_pollutant_met_data, pollutant_variables),
                output_path("tables", "pollutant_summary_table.html"))
save_html_table(summary_table(sound_pollutant_met_data, met_variables),
                output_path("tables", "met_summary_table.html"))
cat("Step 3 done\n")
