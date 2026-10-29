# XGBoost models of no2 on the sound variables, from notebooks/05_models.Rmd.
# Attempts 1 and 2 are ported; attempt 3 passes a grid list to xgb.cv and does not run,
# so it stays in the notebook only. The selected-frequency model, linear regression and
# feature-importance charts shown in the slides have no code in this project.
# Requires xgboost 1.7.x (pinned in renv.lock): caret's xgbTree does not support xgboost >= 3,
# and this code uses the 1.x API (watchlist, cv$best_iteration) as the original did.

library(xgboost)
library(data.table)

model_predictors <- gsub(" ", "_", frequency_variables)

# Attempt 1: 60/20/20 random split (seed 42), manual grid search with 3-fold xgb.cv,
# final model trained with early stopping on the validation set.
fit_xgb_grid <- function(sound_pollutant_met_data, response = "no2",
                         param_grid = list(eta = c(0.01, 0.1, 0.2), max_depth = c(6, 8, 10),
                                           subsample = c(0.8, 1.0), colsample_bytree = c(0.8, 1.0),
                                           gamma = c(0, 0.1, 1)),
                         nrounds = 200) {
  names(sound_pollutant_met_data) <- gsub(" ", "_", names(sound_pollutant_met_data))
  predictors <- model_predictors

  # Split the dataset
  set.seed(42)
  n <- nrow(sound_pollutant_met_data)
  train_index <- sample(1:n, size = 0.6 * n)
  temp_index <- setdiff(1:n, train_index)
  valid_index <- sample(temp_index, size = 0.5 * length(temp_index))
  test_index <- setdiff(temp_index, valid_index)

  train_data <- sound_pollutant_met_data[train_index, ]
  valid_data <- sound_pollutant_met_data[valid_index, ]
  test_data <- sound_pollutant_met_data[test_index, ]

  dtrain <- xgb.DMatrix(data = as.matrix(train_data[, predictors]), label = train_data[, response])
  dvalid <- xgb.DMatrix(data = as.matrix(valid_data[, predictors]), label = valid_data[, response])
  dtest <- xgb.DMatrix(data = as.matrix(test_data[, predictors]), label = test_data[, response])

  # Cross-validation for parameter tuning
  best_param <- list()
  best_rmse <- Inf
  for (eta in param_grid$eta) {
    for (max_depth in param_grid$max_depth) {
      for (subsample in param_grid$subsample) {
        for (colsample_bytree in param_grid$colsample_bytree) {
          for (gamma in param_grid$gamma) {
            params <- list(
              objective = "reg:squarederror",
              eta = eta,
              max_depth = max_depth,
              subsample = subsample,
              colsample_bytree = colsample_bytree,
              gamma = gamma
            )
            cv <- xgb.cv(params = params, data = dtrain, nrounds = nrounds, nfold = 3,
                         metrics = "rmse", early_stopping_rounds = 10, verbose = 0)
            min_rmse <- min(cv$evaluation_log$test_rmse_mean)
            if (min_rmse < best_rmse) {
              best_rmse <- min_rmse
              best_param <- params
              best_nrounds <- cv$best_iteration
            }
          }
        }
      }
    }
  }

  # Fit the final model
  final_model <- xgb.train(params = best_param, data = dtrain, nrounds = best_nrounds,
                           watchlist = list(train = dtrain, valid = dvalid),
                           early_stopping_rounds = 10, verbose = 1)

  # Evaluate on test set
  preds <- predict(final_model, dtest)
  test_rmse <- sqrt(mean((preds - test_data[, response])^2))

  list(model = final_model, best_param = best_param, best_nrounds = best_nrounds,
       cv_rmse = best_rmse, test_rmse = test_rmse)
}

# Attempt 2: caret 60/20/20 stratified split (seed 301), 10-fold CV over max_depth x nrounds.
fit_xgb_caret <- function(sound_pollutant_met_data, response = "no2",
                          tune_grid = expand.grid(max_depth = c(3, 5, 7, 9), nrounds = (1:10) * 50,
                                                  eta = 0.3, gamma = 0, subsample = 1,
                                                  min_child_weight = 1, colsample_bytree = 0.8),
                          folds = 10) {
  library(caret)
  set.seed(301)
  predictors <- model_predictors

  # Create a copy of the dataset for model processing
  model_data <- sound_pollutant_met_data
  names(model_data) <- gsub(" ", "_", names(model_data))

  # Split data into training (60%), validation (20%), and test (20%) sets
  trainIndex <- createDataPartition(model_data[[response]], p = 0.6, list = FALSE)
  train_data <- model_data[trainIndex, ]
  temp_data <- model_data[-trainIndex, ]
  validationIndex <- createDataPartition(temp_data[[response]], p = 0.5, list = FALSE)
  validation_data <- temp_data[validationIndex, ]
  test_data <- temp_data[-validationIndex, ]

  train_control <- trainControl(method = "cv", number = folds, search = "grid")
  optimal_xgb_model <- train(
    form = as.formula(paste(response, "~", paste(predictors, collapse = "+"))),
    data = train_data,
    method = "xgbTree",
    trControl = train_control,
    tuneGrid = tune_grid,
    na.action = na.omit
  )

  validation_pred <- predict(optimal_xgb_model, newdata = validation_data)
  test_pred <- predict(optimal_xgb_model, newdata = test_data)
  list(model = optimal_xgb_model,
       validation_rmse = sqrt(mean((validation_pred - validation_data[[response]])^2)),
       test_rmse = sqrt(mean((test_pred - test_data[[response]])^2)))
}
