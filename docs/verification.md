# Verification summary

`scripts/verify_outputs.R --run-notebook` compared a clean `run_all.R` run (R 4.5.3, renv-pinned
packages, `sound_tz: UTC`) with:

- **legacy**: the derived data and figures produced by the original notebooks in 2024–25.
- **notebook re-run**: the original `notebooks/02` code re-run in the same environment, to isolate
  refactoring errors from package drift.

The full per-file report is written to `outputs/verification/report.md` (gitignored). The table below
summarizes it. It contains no data values.

## Data

| Output | Result | Notes |
|---|---|---|
| `008_097_logged_bb.rdata`, `008_097_logged_spectra.rdata` | PASS~ | Equal within 1e-9 relative. The newer data.table parses some decimals with last-bit differences (max abs diff about 1e-14). |
| `sound_pollutant_data.rdata` | PASS~ | Same dims and columns; equal within 1e-9. |
| `sound_pollutant_met_data.rdata` | PASS~ | Same rows; equal within 1e-9. The legacy file also has a `Night` column that no project code creates. |
| `sound_pollutant_data.csv`, `sound_pollutant_met_data.csv` | PASS | Byte-identical (same MD5). |
| `flare_well_sound_pollutant_met_data.csv` | PASS* | Same rows; all 263 shared columns identical text. The legacy file also has `Night`. |
| `sound_merge_data.rdata` | expected FAIL | Only `Start_Time` differs, by the UTC/Toronto offset. This Oct-2024 file was parsed in America/Toronto, but every downstream legacy table was built from UTC-parsed sound times (README, Known issues 2). |

## Figures and tables

| Check | Result |
|---|---|
| Figures vs notebook re-run | 13/13 identical outside the fixed subset |
| Figures vs legacy | 24 identical; 1 differs in 0.001% of pixels (anti-aliasing); 2 differ (below) |
| > 100F subset figures (12) | Differ from legacy and notebook, as intended: the subset bug is fixed (README, Known issues 1). Before the fix, all 12 were identical to the notebook re-run and the legacy files. |
| Tables vs notebook re-run | 2/2 identical |
| Tables vs legacy | 4/5 identical; 1 differs (below) |

Three legacy files from **22 Nov 2024** aren't reproduced: `frequency_correlation_heatmap.png`,
`frequency_correlation_greater_0.9_heatmap.png` and `frequency_summary_table.html`. Their
`png()`/`save_kable()` lines are commented out in the final notebook, and rebuilding the main table
with either UTC or Toronto sound times doesn't reproduce them. They came from an earlier,
unrecorded version of the code or data.

## Python models (steps 7–8) vs the original Colab notebooks

The re-run metrics (Python 3.11, versions in `requirements.txt`, same input CSVs) were compared
programmatically with the numbers printed in the original notebooks. Only differences are shown.

| Model | Test R² difference | Reading |
|---|---|---|
| STA497 full-data NOx (all 37 measures) | 0.002 | Reproduced: RMSE and MAE are within 0.03. |
| STA497 low-temperature/low-wind subset | 0.014 | Close: row subsampling (0.8) gives some drift across xgboost builds and CPUs. |
| STA497 selected-frequency NOx | 0.09 | Not reproduced exactly. The model is deep and subsampled (depth 12, subsample 0.65), but a gap this size suggests the notebook's printed run differed in other ways too. |
| STA465 linear, XGBoost (all and selected) | 0.17–0.27 | Not reproduced. The linear model is deterministic, and no tested variant (SO₂ vs NOx response, row filters, predictor sets) brings the gap close to zero. The notebook most likely ran on an earlier version of `flare_well_sound_pollutant_met_data.csv`. |

## Not verified

- Leaflet maps (`outputs/maps/`): no legacy copies exist apart from the knitted reports.
- Models (`scripts/06_models.R`): the original saved no outputs to compare with. `--smoke` checks
  that the code runs.
