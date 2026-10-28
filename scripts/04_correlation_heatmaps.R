#!/usr/bin/env Rscript
# Step 4: correlation heatmaps. Each plot_cor_heatmap() call reproduces one block of
# notebooks/02_summary_correlation_plots.Rmd with the same arguments and title.
# Outputs: outputs/figures/*.png and outputs/figures/subset_*/{Pearson,Spearman}/...
source("R/config.R")
source("R/features.R")
source("R/visualize.R")
library(Hmisc)

load(processed_path("sound_pollutant_met_data.rdata"))
fig <- function(...) output_path("figures", ...)
pos <- c("white", "purple")
neg <- c("red", "white")

# ---- Sound frequencies, all data ----
frequency_cor_matrix <- rcorr(as.matrix(sound_pollutant_met_data[, frequency_variables, drop = FALSE]))$r

# This figure and the >= 0.9 one below had their png() lines commented out in the last
# notebook version; the files exist from an earlier run, so both are regenerated.
plot_cor_heatmap(frequency_cor_matrix, fig("frequency_correlation_heatmap.png"),
                 style_full(tl.cex = 0.5, bounded = TRUE), "Frequency Correlation Heat Map")

# The original sets the few (small) negative frequency correlations to 0 from here on.
frequency_cor_matrix[frequency_cor_matrix < 0] <- 0

plot_cor_heatmap(frequency_cor_matrix, fig("frequency_correlation_greater_0.9_heatmap.png"),
                 style_highlight(pos, 0.6), "Frequency Heat Map Highlighting Correlations ≥ 0.9",
                 mask = keep_at_least(0.9))
for (t in c("0.85", "0.80", "0.75", "0.70", "0.60")) {
  plot_cor_heatmap(frequency_cor_matrix, fig(sprintf("frequency_correlation_greater_%s_heatmap.png", t)),
                   style_highlight(pos, 0.6), sprintf("Frequency Heat Map Highlighting Correlations ≥ %s", t),
                   mask = keep_at_least(as.numeric(t)))
}

# ---- NOx and sound frequencies, all data ----
nox_frequency_cor_matrix <- rcorr(as.matrix(sound_pollutant_met_data[, nox_frequency_variables, drop = FALSE]))$r

plot_cor_heatmap(nox_frequency_cor_matrix, fig("nox_frequency_correlation_heatmap.png"),
                 style_full(tl.cex = 0.5, bounded = FALSE), "Nox and Frequency Corr Heat Map")
plot_cor_heatmap(nox_frequency_cor_matrix, fig("nox_frequency_correlation_greater_0.90_heatmap.png"),
                 style_highlight(pos, 0.6), "Nox and Frequency Heat Map Highlighting Correlations ≥ 0.9",
                 mask = keep_abs_at_least(0.9))
plot_cor_heatmap(nox_frequency_cor_matrix, fig("nox_frequency_correlation_smaller_0_heatmap.png"),
                 style_highlight(neg, 0.6), "Nox and Frequency Heat Map Highlighting Correlations < 0",
                 mask = keep_at_most(0))
plot_cor_heatmap(nox_frequency_cor_matrix, fig("nox_frequency_correlation_smaller_-0.3_heatmap.png"),
                 style_highlight(neg, 0.6), "Nox and Frequency Heat Map Highlighting Correlations <= -0.3",
                 mask = keep_at_most(-0.3))

# ---- NOx and meteorology, all data ----
nox_met_filtered_data <- sound_pollutant_met_data[, unname(nox_met_variables), drop = FALSE]
colnames(nox_met_filtered_data) <- names(nox_met_variables)
met_nox_cor_matrix <- rcorr(as.matrix(nox_met_filtered_data))$r

plot_cor_heatmap(met_nox_cor_matrix, fig("met_nox_correlation_heatmap.png"),
                 style_full(tl.cex = 0.8, bounded = FALSE), "Met and NOx Correlation Heat Map for Met and NOx Variables")
plot_cor_heatmap(met_nox_cor_matrix, fig("met_nox_correlation_smaller_-0.3_heatmap.png"),
                 style_highlight(neg, 0.6), "Met and NOx Heat Map Highlighting Correlations <= -0.3",
                 mask = keep_at_most(-0.3), title_line = 2.5)
plot_cor_heatmap(met_nox_cor_matrix, fig("met_nox_correlation_smaller_-0.4_heatmap.png"),
                 style_highlight(neg, 0.6), "Met and NOx Heat Map Highlighting Correlations <= -0.4",
                 mask = keep_at_most(-0.4))
plot_cor_heatmap(met_nox_cor_matrix, fig("met_nox_correlation_smaller_-0.5_heatmap.png"),
                 style_highlight(neg, 0.6), "Met and NOx  Heat Map Highlighting Correlations <= -0.5",
                 mask = keep_at_most(-0.5))

# ---- Temperature / wind-speed subsets, Pearson and Spearman ----
# Titles keep the original wording, including "Low Temperature(> 100F)" and the Spearman
# NOx coefficient map titled "Spearman Frequency ...".
subset_heatmaps <- function(subset_data, temp_label, out_dir) {
  cond <- sprintf(" for %s and\n Low Wind Speed (<= 7m/s) Conditions", temp_label)
  for (method in c("Pearson", "Spearman")) {
    m <- tolower(method)
    sub_fig <- function(group, name) output_path("figures", out_dir, method, group, sprintf("%s_subset_%s", m, name))
    freq <- rcorr(as.matrix(subset_data[, frequency_variables, drop = FALSE]), type = m)$r
    nox <- rcorr(as.matrix(subset_data[, nox_frequency_variables, drop = FALSE]), type = m)$r
    full_freq_title <- if (method == "Pearson") "Pearson Frequency Heatmap" else "Spearman Frequency Correlation Heatmap"
    hl_freq_title <- sprintf("%s Frequency Heat Map Highlighting Correlations ≥ 0.9", method)
    coef_freq_title <- if (method == "Pearson") "Pearson Frequency Heatmap with Coefficient ≥ 0.9" else "Spearman Frequency Heat Map with Coefficient ≥ 0.9"
    hl_nox_title <- if (method == "Pearson") "Pearson Nox and Frequency Corr Map Highlighting Correlations ≥ 0.9" else "Spearman Nox and Frequency Heat Map Highlighting Correlations ≥ 0.9"
    coef_nox_title <- if (method == "Pearson") "Pearson Nox and Frequency Corr Map With Coefficient ≥ 0.9" else "Spearman Frequency Heat Map with Coefficient ≥ 0.9"

    plot_cor_heatmap(freq, sub_fig("sound", "frequency_correlation_heatmap.png"),
                     style_full(tl.cex = 1, bounded = TRUE), paste0(full_freq_title, cond),
                     title_line = 2, title_cex = 1)
    plot_cor_heatmap(freq, sub_fig("sound", "frequency_correlation_greater_0.90_heatmap.png"),
                     style_highlight(pos, 1), paste0(hl_freq_title, cond),
                     mask = keep_abs_at_least(0.9), title_line = 2, title_cex = 1)
    plot_cor_heatmap(freq, sub_fig("sound", "coefficient_frequency_correlation_greater_0.90_heatmap.png"),
                     style_coefficients, paste0(coef_freq_title, cond),
                     mask = keep_abs_at_least(0.9, fill = NA), title_line = 2,
                     title_cex = if (method == "Pearson") 1.2 else 1, size = 1000)

    plot_cor_heatmap(nox, sub_fig("nox_and_sound", "nox_frequency_correlation_heatmap.png"),
                     style_full(tl.cex = 1, bounded = FALSE), sprintf("%s Nox and Frequency Corr Heat Map%s", method, cond),
                     title_line = 2, title_cex = 1)
    plot_cor_heatmap(nox, sub_fig("nox_and_sound", "nox_frequency_correlation_greater_0.90_heatmap.png"),
                     style_highlight(pos, 1), paste0(hl_nox_title, cond),
                     mask = keep_abs_at_least(0.9), title_line = 2, title_cex = 1)
    plot_cor_heatmap(nox, sub_fig("nox_and_sound", "coefficient_nox_frequency_correlation_greater_0.90_heatmap.png"),
                     style_coefficients, paste0(coef_nox_title, cond),
                     mask = keep_abs_at_least(0.9, fill = NA), title_line = 2, title_cex = 1, size = 1000)
  }
}

subsets <- temp_wind_subsets(sound_pollutant_met_data)
subset_heatmaps(subsets$low_temp_ws, "Low Temperature(<= 70F)", "subset_temp_le70_wsp_le7")
subset_heatmaps(subsets$high_temp_ws, "Low Temperature(> 100F)", "subset_temp_gt100_wsp_le7")
cat("Step 4 done\n")
