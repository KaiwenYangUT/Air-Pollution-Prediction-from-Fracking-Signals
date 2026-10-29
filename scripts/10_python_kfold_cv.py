#!/usr/bin/env python
"""Step 10 (Python): 5-fold cross-validation of the NOx models, XGBoost vs Random Forest.

Each of 3 experiments (python/sta497/cv.py) is scored by both models under two fold schemes:
  random  shuffled KFold over 1-minute rows (what "k-fold CV" usually means; leaks across
          neighbouring minutes)
  day     GroupKFold by calendar day (no day is split between train and test)
The gap between the two is the optimism from temporal leakage.

Run from the repo root:  .venv/bin/python scripts/10_python_kfold_cv.py [--smoke]
--smoke runs every combination on a 4,000-row sample with 2 folds, 20 boosting rounds and
10 trees, to check the code runs. Outputs: outputs/python/sta497_cv/{metrics_by_fold,metrics}.csv
(metrics are written to file, never printed).
"""
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
from sta497 import cv, models  # noqa: E402
from sta497.config import output_path  # noqa: E402


def main(smoke=False):
    experiments = cv.load_experiments()
    settings = {}
    if smoke:
        experiments = {name: (data.sample(min(len(data), 4000), random_state=models.SEED).reset_index(drop=True), p, r)
                       for name, (data, p, r) in experiments.items()}
        settings = {"n_folds": 2, "num_boost_round": 20, "rf_params": {**models.RF_PARAMS, "n_estimators": 10}}

    rows = []
    for name, (data, predictors, response) in experiments.items():
        for model in cv.MODELS:
            for scheme in cv.SCHEMES:
                rows += cv.run(name, data, predictors, response, model, scheme, **settings)
                print(f"  {name} {model} {scheme}: done", flush=True)

    out_dir = "sta497_cv_smoke" if smoke else "sta497_cv"
    by_fold = pd.DataFrame(rows)
    by_fold.to_csv(output_path(out_dir, "metrics_by_fold.csv"), index=False)
    cv.summarize(by_fold).to_csv(output_path(out_dir, "metrics.csv"), index=False)
    print(f"Step 10 done: {output_path(out_dir, 'metrics.csv')}")


if __name__ == "__main__":
    main(smoke="--smoke" in sys.argv[1:])
