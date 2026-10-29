#!/usr/bin/env python
"""Step 8 (Python): STA465 models on the flare/well/sound/pollutant/met table.

Restructured from notebooks/python/07_STA465_models.ipynb. Sections:
  1. FFT spectrum of the 12.5 Hz band (exploratory)
  2. Linear regression, all 48 predictors           (response SO2, as in the notebook)
  3. XGBoost, all 48 predictors                      (response SO2, as in the notebook)
  4. XGBoost, 29 selected predictors (final model)   (response NOx)
Validation R2 is labelled "Training R-squared" in the notebook; it is reported as valid_r2 here.

Caveats kept from the original (see README, Known issues):
  - Sections 2-3 predict SO2 but section 4 predicts NOx, so they are not a like-for-like comparison.
  - The table repeats each minute once per flare detected that day (many-to-many join), so a
    random split puts copies of the same minute in train and test; test scores are optimistic.

Run from the repo root:  .venv/bin/python scripts/08_python_sta465_models.py
Outputs: outputs/python/sta465/metrics.csv and figures/*.png (metrics are not printed).
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.fftpack import fft, fftfreq

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
from sta497 import models, plots  # noqa: E402
from sta497.config import output_path  # noqa: E402
from sta497.data import load_csv, prepare  # noqa: E402
from sta497.variables import STA465_ALL, STA465_SELECTED  # noqa: E402

PARAMS = models.xgb_params(max_depth=12, eta=0.01, subsample=0.65, colsample_bytree=1.0)


def fig(name):
    return output_path("sta465", "figures", name)


def fft_spectrum(df, band="LZeq_12.5Hz"):
    """Magnitude spectrum of one band over time, treating rows as evenly spaced at the mean
    time step (the series has gaps and repeated minutes, so this is only indicative)."""
    clean = df.dropna(subset=[band, "time_utc"]).copy()
    clean["time_utc"] = pd.to_datetime(clean["time_utc"], errors="coerce")
    clean = clean.dropna(subset=["time_utc"])
    seconds = (clean["time_utc"] - clean["time_utc"].min()).dt.total_seconds().to_numpy()
    signal = clean[band].to_numpy()
    dt = np.mean(np.diff(seconds))
    n = len(signal)
    plots.spectrum(fftfreq(n, d=dt)[: n // 2], np.abs(fft(signal)[: n // 2]),
                   fig("fft_LZeq_12.5Hz.png"), f"Frequency Spectrum of {band}")


def main():
    df = load_csv("flare_well_sound_pollutant_met_data.csv",
                  sorted(set(STA465_ALL + STA465_SELECTED + ["so2", "nox", "time_utc"])))
    fft_spectrum(df)
    print("  fft: done")

    rows = []
    # As in the notebook, the selected-predictor data is taken from the table already
    # restricted to rows complete for all 48 predictors and SO2.
    all_df = prepare(df, STA465_ALL + ["so2"])
    train, valid, test = models.split_60_20_20(all_df)

    lm = models.fit_linear(train, STA465_ALL, "so2")
    valid_pred = lm.predict(valid[STA465_ALL])
    rows.append({"model": "linear_all_predictors", "response": "so2",
                 **models.evaluate(valid["so2"], valid_pred, "valid"),
                 **models.evaluate(test["so2"], lm.predict(test[STA465_ALL]))})
    plots.residuals(valid_pred, valid["so2"], str(fig("linear_all")), "")
    print("  linear_all_predictors: done")

    xgb_all = models.train_xgb(PARAMS, models.dmatrix(train, STA465_ALL, "so2"))
    valid_pred = xgb_all.predict(models.dmatrix(valid, STA465_ALL, "so2"))
    rows.append({"model": "xgb_all_predictors", "response": "so2",
                 **models.evaluate(valid["so2"], valid_pred, "valid"),
                 **models.evaluate(test["so2"], xgb_all.predict(models.dmatrix(test, STA465_ALL, "so2")))})
    plots.residuals(valid_pred, valid["so2"], str(fig("xgb_all")), " - XGBoost Model")
    print("  xgb_all_predictors: done")

    sel_df = prepare(all_df, STA465_SELECTED + ["nox"])
    train, valid, test = models.split_60_20_20(sel_df)
    xgb_sel = models.train_xgb(PARAMS, models.dmatrix(train, STA465_SELECTED, "nox"))
    valid_pred = xgb_sel.predict(models.dmatrix(valid, STA465_SELECTED, "nox"))
    rows.append({"model": "xgb_selected_predictors", "response": "nox",
                 **models.evaluate(valid["nox"], valid_pred, "valid"),
                 **models.evaluate(test["nox"], xgb_sel.predict(models.dmatrix(test, STA465_SELECTED, "nox")))})
    plots.residuals(valid_pred, valid["nox"], str(fig("xgb_selected")), " - XGBoost Model (Selected Predictors)")
    plots.importance(xgb_sel, fig("xgb_selected_importance_top20.png"), "Variable Importance (Top 20)", 20, figsize=(18, 24))
    print("  xgb_selected_predictors: done")

    out = output_path("sta465", "metrics.csv")
    pd.DataFrame(rows).to_csv(out, index=False)
    print(f"Step 8 done: {out}")


if __name__ == "__main__":
    main()
