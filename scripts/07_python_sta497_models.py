#!/usr/bin/env python
"""Step 7 (Python): STA497 XGBoost models of NOx/NO2 from sound frequencies.

Restructured from notebooks/python/06_STA497_models.ipynb. Experiments:
  1. full_nox        NOx ~ 37 sound measures, all data
  2. full_no2        NO2 ~ 37 sound measures (same hyperparameters as 1)
  3. subset_nox      NOx ~ 37 sound measures, temp <= 75F and wind <= 7 m/s
  4. subset_met_nox  as 3, plus 7 meteorological predictors
  5. selected_nox    NOx ~ 19 frequencies selected from the corr > 0.9 grouping (all data)
  6. sound_met_nox   NOx ~ 37 sound measures + 7 meteorological predictors (all data)
  7. sound_met_no2   NO2 ~ the same 44 predictors (all data)

Final models use the hyperparameters the notebook settled on (FINAL_PARAMS). --tune re-runs
the validation grid search for each experiment instead (slow) and records its choice.

Run from the repo root:  .venv/bin/python scripts/07_python_sta497_models.py [--tune]
Outputs: outputs/python/sta497/metrics.csv and figures/*.png. Metrics are written to file,
never printed.
"""
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
from sta497 import models, plots  # noqa: E402
from sta497.config import output_path  # noqa: E402
from sta497.data import load_csv, prepare  # noqa: E402
from sta497.variables import FREQUENCY, MET, SELECTED_FREQUENCY, low_temp_low_wind  # noqa: E402

FINAL_PARAMS = {
    "full_nox": models.xgb_params(max_depth=9, eta=0.1, subsample=1.0, colsample_bytree=0.8),
    "subset_nox": models.xgb_params(max_depth=9, eta=0.1, subsample=0.8, colsample_bytree=1.0),
    # Chosen by hand after the grid search (outside the grid: depth 12).
    "selected_nox": models.xgb_params(max_depth=12, eta=0.01, subsample=0.65, colsample_bytree=1.0),
}
FINAL_PARAMS["full_no2"] = FINAL_PARAMS["full_nox"]        # reused, not re-tuned
FINAL_PARAMS["subset_met_nox"] = FINAL_PARAMS["full_nox"]  # as recorded in the notebook
# Added after the notebooks: the met predictors on all data rather than only the subset.
FINAL_PARAMS["sound_met_nox"] = FINAL_PARAMS["full_nox"]
FINAL_PARAMS["sound_met_no2"] = FINAL_PARAMS["full_nox"]


def fig(name):
    return output_path("sta497", "figures", name)


def run(name, data, predictors, response, tune, label):
    """Split, (optionally) tune, train, evaluate and plot one experiment."""
    train, valid, test = models.split_60_20_20(data)
    dtrain = models.dmatrix(train, predictors, response)
    dvalid = models.dmatrix(valid, predictors, response)
    dtest = models.dmatrix(test, predictors, response)

    params, valid_rmse = FINAL_PARAMS[name], None
    if tune:
        params, valid_rmse = models.tune_xgb(dtrain, dvalid)
    model = models.train_xgb(params, dtrain)
    preds = model.predict(dtest)

    n = len(predictors)
    plots.importance(model, fig(f"{name}_importance_top20.png"), f"{label} Feature Importance (Top 20)", 20)
    plots.importance(model, fig(f"{name}_importance_all.png"), f"{label} Feature Importance (All {n})", n,
                     figsize=(20, 40) if n > 40 else (10, 20), xtick_size=6 if n <= 40 else 8, ytick_size=10 if n <= 40 else 8)
    title = f"{label} {response.upper()} Scatter Plot"
    plots.predicted_vs_actual(test[response], preds, fig(f"{name}_predicted_vs_actual.png"),
                              f"{title}: Predicted vs Actual Values (Full Test Data)")
    plots.predicted_vs_actual(test[response], preds, fig(f"{name}_predicted_vs_actual_log.png"),
                              f"{title}: Log-Transformed Predicted vs Actual Values (Full Test Data)", log=True)

    row = {"experiment": name, "response": response, "n_predictors": n,
           "n_train": len(train), "n_valid": len(valid), "n_test": len(test),
           "params": str({k: v for k, v in params.items() if k not in ("objective", "eval_metric")}),
           "tuned": tune, "valid_rmse_best": valid_rmse,
           **models.evaluate(test[response], preds),
           "test_accuracy_within_5": models.accuracy_within(test[response], preds, 5)}
    print(f"  {name}: done")
    return row, model


def main(tune=False):
    df = load_csv("sound_pollutant_met_data.csv", FREQUENCY + MET + ["nox", "no2"])

    # As in the notebook, `df` is narrowed in place: the NO2 rows (and every later experiment)
    # are rows complete for the 37 measures, NOx and NO2.
    df_nox = prepare(df, FREQUENCY + ["nox"])
    df_no2 = prepare(df_nox, FREQUENCY + ["no2"])
    subset = low_temp_low_wind(df_no2)

    rows = []
    row, full_model = run("full_nox", df_nox, FREQUENCY, "nox", tune, "Full Data")
    plots.importance(full_model, fig("full_nox_importance_top10.png"), "Variable Importance (Top 10)", 10)
    rows.append(row)
    rows.append(run("full_no2", df_no2, FREQUENCY, "no2", tune, "Full Data")[0])
    rows.append(run("subset_nox", prepare(subset, FREQUENCY + ["nox"]), FREQUENCY, "nox", tune, "Subset")[0])
    rows.append(run("subset_met_nox", prepare(subset, FREQUENCY + MET + ["nox"]), FREQUENCY + MET, "nox", tune, "Met Subset")[0])
    row, selected_model = run("selected_nox", prepare(df_no2, SELECTED_FREQUENCY + ["nox"]), SELECTED_FREQUENCY, "nox", tune, "Selected Frequencies")
    plots.importance(selected_model, fig("selected_nox_importance_top10.png"), "Variable Importance (Top 10)", 10)
    rows.append(row)
    rows.append(run("sound_met_nox", prepare(df_no2, FREQUENCY + MET + ["nox"]), FREQUENCY + MET, "nox", tune, "Sound + Met")[0])
    rows.append(run("sound_met_no2", prepare(df_no2, FREQUENCY + MET + ["no2"]), FREQUENCY + MET, "no2", tune, "Sound + Met")[0])

    out = output_path("sta497", "metrics_tuned.csv" if tune else "metrics.csv")
    pd.DataFrame(rows).to_csv(out, index=False)
    print(f"Step 7 done: {out}")


if __name__ == "__main__":
    main(tune="--tune" in sys.argv[1:])
