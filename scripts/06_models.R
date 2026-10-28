#!/usr/bin/env Rscript
# Step 6 (optional, slow): XGBoost models from notebooks/05_models.Rmd.
# The full grid is 108 xgb.cv runs plus a 40-combination 10-fold caret search (hours).
# --smoke runs both on a 3,000-row sample with a one-point grid, to check the code runs.
# Outputs: outputs/models/{xgb_grid,xgb_caret}.rds and outputs/models/metrics.csv
source("R/config.R")
source("R/features.R")
source("R/model.R")

smoke <- "--smoke" %in% commandArgs(trailingOnly = TRUE)
load(processed_path("sound_pollutant_met_data.rdata"))

if (smoke) {
  set.seed(1)
  sound_pollutant_met_data <- sound_pollutant_met_data[sample(nrow(sound_pollutant_met_data), 3000), ]
  grid <- fit_xgb_grid(sound_pollutant_met_data,
                       param_grid = list(eta = 0.1, max_depth = 6, subsample = 1, colsample_bytree = 1, gamma = 0),
                       nrounds = 20)
  caret_fit <- fit_xgb_caret(sound_pollutant_met_data,
                             tune_grid = expand.grid(max_depth = 3, nrounds = 20, eta = 0.3, gamma = 0, subsample = 1,
                                                     min_child_weight = 1, colsample_bytree = 0.8),
                             folds = 2)
} else {
  grid <- fit_xgb_grid(sound_pollutant_met_data)
  caret_fit <- fit_xgb_caret(sound_pollutant_met_data)
}

out <- if (smoke) "models_smoke" else "models"
saveRDS(grid, output_path(out, "xgb_grid.rds"))
saveRDS(caret_fit, output_path(out, "xgb_caret.rds"))
write.csv(data.frame(model = c("xgb_grid", "xgb_caret"),
                     test_rmse = c(grid$test_rmse, caret_fit$test_rmse)),
          output_path(out, "metrics.csv"), row.names = FALSE)
cat("Step 6 done", if (smoke) "(smoke test)", "\n")
