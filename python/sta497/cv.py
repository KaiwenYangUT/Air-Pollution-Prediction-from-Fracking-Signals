"""K-fold cross-validation of the NOx models: XGBoost vs Random Forest, random vs day-blocked folds.

Used by scripts/10_python_kfold_cv.py and notebooks/python/09_STA497_kfold_rf.ipynb. The row sets
and XGBoost hyperparameters match scripts/07 and 08, so the CV scores are comparable with their
single 60/20/20 holdout.
"""
import pandas as pd

from . import models
from .data import load_csv, prepare
from .variables import FREQUENCY, SELECTED_FREQUENCY, STA465_ALL, STA465_SELECTED

# Same settings as FINAL_PARAMS in scripts/07 and PARAMS in scripts/08.
XGB_PARAMS = {
    "full_nox": models.xgb_params(max_depth=9, eta=0.1, subsample=1.0, colsample_bytree=0.8),
    "selected_nox": models.xgb_params(max_depth=12, eta=0.01, subsample=0.65, colsample_bytree=1.0),
    "sta465_selected_nox": models.xgb_params(max_depth=12, eta=0.01, subsample=0.65, colsample_bytree=1.0),
}

SCHEMES = ("random", "day")
MODELS = ("xgb", "rf")
METRICS = ["test_rmse", "test_mae", "test_r2"]


def with_day(df: pd.DataFrame) -> pd.DataFrame:
    """Add the calendar day of `time_utc` (the fold group) and drop rows whose time won't parse."""
    df = df.copy()
    df["day"] = pd.to_datetime(df["time_utc"], errors="coerce", utc=True).dt.floor("D")
    return df.dropna(subset=["day"]).reset_index(drop=True)


def load_experiments() -> dict:
    """name -> (data, predictors, response).

    full_nox             NOx ~ 37 sound measures                       (rows as scripts/07)
    selected_nox         NOx ~ 19 selected frequencies                 (rows as scripts/07)
    sta465_selected_nox  NOx ~ 29 predictors: 18 frequencies, 4 well,  (rows as scripts/08,
                         7 met                                          one copy per minute)
    """
    df = load_csv("sound_pollutant_met_data.csv", FREQUENCY + ["nox", "no2", "time_utc"])
    df_nox = prepare(df, FREQUENCY + ["nox"])
    df_no2 = prepare(df_nox, FREQUENCY + ["no2"])

    flare = load_csv("flare_well_sound_pollutant_met_data.csv",
                     sorted(set(STA465_ALL + STA465_SELECTED + ["so2", "nox", "time_utc"])))
    flare = prepare(prepare(flare, STA465_ALL + ["so2"]), STA465_SELECTED + ["nox"])
    # The table repeats each minute once per flare that day. Without the flare columns the copies
    # are identical, so keep one; otherwise random folds put the same minute in train and test.
    flare = flare.drop_duplicates(subset=["time_utc"] + STA465_SELECTED + ["nox"])

    return {
        "full_nox": (with_day(df_nox), FREQUENCY, "nox"),
        "selected_nox": (with_day(prepare(df_no2, SELECTED_FREQUENCY + ["nox"])), SELECTED_FREQUENCY, "nox"),
        "sta465_selected_nox": (with_day(flare), STA465_SELECTED, "nox"),
    }


def run(name, data, predictors, response, model, scheme, n_folds=models.N_FOLDS,
        num_boost_round=models.NUM_BOOST_ROUND, rf_params=models.RF_PARAMS) -> list:
    """Per-fold metric rows for one experiment x model x fold scheme."""
    splits = models.kfold_splits(data, scheme, n_folds)
    rows = models.cross_validate(data, predictors, response, model, splits, XGB_PARAMS[name],
                                 num_boost_round, rf_params)
    return [{"experiment": name, "model": model, "scheme": scheme, "n_predictors": len(predictors), **row}
            for row in rows]


def summarize(by_fold: pd.DataFrame) -> pd.DataFrame:
    """Mean and SD of each test metric across folds, one row per experiment x model x scheme."""
    summary = by_fold.groupby(["experiment", "model", "scheme"], sort=False)[METRICS].agg(["mean", "std"])
    summary.columns = [f"{metric}_{stat}" for metric, stat in summary.columns]
    return summary.reset_index()
