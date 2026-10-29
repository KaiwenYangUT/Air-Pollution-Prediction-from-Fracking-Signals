"""Train/validation/test split, XGBoost tuning and training, and evaluation metrics."""
from itertools import product

import numpy as np
import xgboost as xgb
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import train_test_split

SEED = 42
NUM_BOOST_ROUND = 1000

# Grid searched in the notebooks (1000 rounds, early stopping after 10 on the validation set).
PARAM_GRID = {
    "max_depth": [3, 6, 9],
    "eta": [0.01, 0.1, 0.3],
    "subsample": [0.8, 1.0],
    "colsample_bytree": [0.8, 1.0],
}


def xgb_params(max_depth, eta, subsample, colsample_bytree) -> dict:
    return {"objective": "reg:squarederror", "max_depth": max_depth, "eta": eta,
            "subsample": subsample, "colsample_bytree": colsample_bytree, "eval_metric": "rmse"}


def split_60_20_20(df, seed: int = SEED):
    """60% train, 20% validation, 20% test (two train_test_split calls, as in the notebooks)."""
    train, rest = train_test_split(df, test_size=0.4, random_state=seed)
    valid, test = train_test_split(rest, test_size=0.5, random_state=seed)
    return train, valid, test


def dmatrix(df, predictors, response) -> xgb.DMatrix:
    return xgb.DMatrix(df[predictors], label=df[response])


def tune_xgb(dtrain, dvalid, grid: dict = PARAM_GRID):
    """Grid search scored by best validation RMSE. Returns (best_params, best_rmse).

    The notebooks' subset searches compared against the full-data search's best score and the
    met-subset search trained on the full data; each search here is self-contained.
    """
    best_params, best_rmse = None, float("inf")
    for max_depth, eta, subsample, colsample in product(*grid.values()):
        params = xgb_params(max_depth, eta, subsample, colsample)
        model = xgb.train(params, dtrain, num_boost_round=NUM_BOOST_ROUND,
                          evals=[(dvalid, "Validation")], early_stopping_rounds=10, verbose_eval=False)
        if model.best_score < best_rmse:
            best_params, best_rmse = params, model.best_score
    return best_params, best_rmse


def train_xgb(params: dict, dtrain) -> xgb.Booster:
    """Final model: a fixed 1000 rounds without early stopping, as in the notebooks."""
    return xgb.train(params, dtrain, num_boost_round=NUM_BOOST_ROUND)


def fit_linear(train, predictors, response) -> LinearRegression:
    return LinearRegression().fit(train[predictors], train[response])


def evaluate(actual, predicted, prefix: str = "test") -> dict:
    actual = np.asarray(actual)
    return {f"{prefix}_rmse": float(np.sqrt(mean_squared_error(actual, predicted))),
            f"{prefix}_mae": float(mean_absolute_error(actual, predicted)),
            f"{prefix}_r2": float(r2_score(actual, predicted))}


def accuracy_within(actual, predicted, tolerance: float = 5) -> float:
    """Share of predictions within +/- tolerance of the actual value."""
    return float(np.mean(np.abs(np.asarray(predicted) - np.asarray(actual)) <= tolerance))
