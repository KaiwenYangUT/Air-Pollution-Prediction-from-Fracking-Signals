# STA497: Noise frequencies and air pollution near oil and gas activity

Research project (University of Toronto, STA497 reading course, 2024–25) that studies whether the noise
recorded by a stationary monitoring trailer in the Permian Basin can help trace air pollution, mainly
NOx, back to oil and gas sources such as compressors, pumps and flares. The project also
fed an STA465 (spatial statistics) report on flares and wells around the trailer.

This repository contains the analysis code only. **The data is confidential and is not included.**

## Research question

Which sound frequencies move together with pollutant concentrations (mainly NOx/NO₂), and can
frequency groups be linked to the machinery that produces both the noise and the emissions?

## Findings (qualitative)

- Sound frequencies form clear low and high groups of strongly correlated bands.
- Low frequencies are associated with compressors, generators and drilling, mid frequencies with
  pumps and pipelines, and high frequencies with flaring and venting.
- An XGBoost model of NOx on a selected subset of frequencies fit better than one on all frequencies;
  the A-weighted max/min levels, the C-weighted peak and the 12.5 Hz band were the top predictors.
- Planned next step: filter air-conditioner on/off noise, which may contaminate low-to-mid frequencies.

See `docs/slides/` for the presentation and guest lecture.

## Data (not in this repository)

All data lives outside the repo, in the folder named by `data_root` in `config.yml`:

```
<data_root>/
├── raw/
│   ├── sound/LNM*/        sound-level-meter logs, one folder per monitor deployment
│   ├── pollutants/        Boulder AIR 1-minute CH4, CO, H2S, NOx, O3
│   ├── met/               Boulder AIR 1-minute meteorology
│   └── spatial/           well production (cb_wells_prod.rds), VIIRS flares (pb-vnf_*.rds)
├── processed/             derived data from the original 2024-25 runs (verification baseline)
└── processed_rerun/       derived data written by this pipeline
```

Column names and types are listed in [docs/data_dictionary.md](docs/data_dictionary.md).

## Setup

Requires R 4.5 and pandoc (for the self-contained map files). The Python models (steps 7–10) need Python 3.11.

```bash
cp config.example.yml config.yml
```

Edit `data_root` in `config.yml`, then restore the pinned packages:

```bash
Rscript -e 'renv::restore()'
```

For the Python steps, create the virtual environment:

```bash
python3.11 -m venv .venv
```

```bash
.venv/bin/pip install -r requirements.txt
```

## Running

From the repo root:

```bash
Rscript scripts/run_all.R
```

`--with-models` also runs the slow R XGBoost step (hours), `--with-python` runs the Python steps 7–10, and
`--from N` resumes at step N.
Each step's console output goes to `outputs/logs/`, not the terminal.

| Step | Script | Outputs |
|---|---|---|
| 1 | `scripts/01_stack_sound.R` | `008_097_logged_{spectra,bb}.rdata` |
| 2 | `scripts/02_merge_sound_pollutant_met.R` | `sound_merge_data.rdata`, `sound_pollutant_data.*`, `sound_pollutant_met_data.*` |
| 3 | `scripts/03_summary_tables.R` | `outputs/tables/{frequency,pollutant,met}_summary_table.html` |
| 4 | `scripts/04_correlation_heatmaps.R` | `outputs/figures/**.png` (Pearson/Spearman, all data and temperature/wind subsets) |
| 5 | `scripts/05_spatial_flare_well.R` | `flare_well_sound_pollutant_met_data.csv`, wells/frequency tables, `outputs/maps/*.html` |
| 6 | `scripts/06_models.R` (optional) | `outputs/models/` (R XGBoost exploration) |
| 7 | `scripts/07_python_sta497_models.py` | `outputs/python/sta497/`: XGBoost NOx/NO₂ models, feature importance, prediction plots |
| 8 | `scripts/08_python_sta465_models.py` | `outputs/python/sta465/`: linear and XGBoost models with flares and wells, residual plots |
| 9 | `scripts/09_python_ac_sound_spectrograms.py` | `outputs/python/ac_sound/`: band spectrograms for air-conditioner screening |
| 10 | `scripts/10_python_kfold_cv.py` | `outputs/python/sta497_cv/`: 5-fold CV of the NOx models, XGBoost vs Random Forest, random vs day-blocked folds |

Derived data goes to `processed_rerun/`, and figures, tables and maps go to `outputs/` (gitignored).

To check a run against the original outputs:

```bash
Rscript scripts/verify_outputs.R --run-notebook
```

## Repository layout

```
R/            functions: config, load, clean, features (merges/subsets), visualize, model
python/sta497/ Python package: config, data, variables, models, cv, plots (steps 7-10)
scripts/      numbered pipeline steps, run_all.R, verify_outputs.R, extract_schema.R, hooks/
notebooks/    original R Markdown notebooks (paths updated only) and, in notebooks/python/, the
              original Colab notebooks (outputs stripped), kept for reference, plus the new
              09_STA497_kfold_rf.ipynb (k-fold CV and Random Forest, same code as step 10)
archive/      superseded drafts of the stacking notebook and an empty stub
docs/         data dictionary, verification summary, slides
outputs/      generated figures/tables/maps/logs (gitignored)
```

The pre-commit hook in `scripts/hooks/pre-commit` refuses data-like files. Install it with:

```bash
cp scripts/hooks/pre-commit .git/hooks/pre-commit
```

## Known issues

The pipeline reproduces the original analysis as it was, with one fix (item 1):

1. **High-temperature subset (fixed).** The original notebook built the "> 100F, wind ≤ 7 m/s" subset from the
   ≤ 70F rows, so its 12 heatmaps (in the legacy outputs and the slides' era) actually showed ≤ 70F data.
   `temp_wind_subsets()` in `R/features.R` now uses the > 100F rows, so `outputs/figures/subset_temp_gt100_wsp_le7/`
   differs from the legacy figures. `notebooks/02` still contains the original line, for reference.
2. **Time zones.** The notebooks parse sound timestamps without a time zone, so the result depends on the
   R session. The legacy analysis tables, and every figure, table and model built on them, match
   exactly only when sound times are read as **UTC**, the same zone as the pollutant `time_utc`. That
   is what `sound_tz: UTC` in `config.yml` reproduces. The oldest saved sound table
   (`sound_merge_data.rdata`, Oct 2024) was parsed in America/Toronto instead. The loggers' true clock
   zone is unknown: if they record local site time (Mountain), the sound-to-pollutant join is shifted
   by several hours.
3. **Untracked `Night` column.** The legacy `sound_pollutant_met_data` has a `Night` column that no code
   in this project creates. The pipeline output doesn't have it, and no figure or table uses it.
4. **Python models (steps 7–8).** These come from the original Colab notebooks and keep their choices:
   - The final hyperparameters were hardcoded after tuning. `--tune` re-runs the grid search instead.
   - The STA497 subset models use temp ≤ 75 °F, while the R heatmaps use ≤ 70 °F.
   - In STA465, the all-predictor models predict **SO₂** but the selected-predictor model predicts **NOx**,
     so the two aren't a like-for-like comparison.
   - The STA465 table repeats each minute once per flare detected that day, so a random train/test split
     puts copies of the same minute on both sides, and its test scores are optimistic.
   - Every split in steps 6–8 is random over 1-minute rows, so neighbouring minutes fall in both training and
     test. Step 10 (and `notebooks/python/09_STA497_kfold_rf.ipynb`) re-scores the NOx models with 5-fold CV
     under both random and day-blocked folds. It also re-adds a Random Forest baseline with new settings, since
     the original RF cells were deleted. Step 10 keeps one copy per minute of the STA465 table. Quote the
     day-blocked scores.

   Accidental bugs in the notebooks are fixed: tuning loops that compared against or trained on the wrong
   data (commented in `python/sta497/models.py`), and printouts that showed another model's metrics. The
   unseeded 500/1000-point sample plots, which paired NO₂ predictions with NOx labels, are dropped
   because the full-test-set plots cover them.
5. **Raw-data quirks.** `raw/sound/LNM049/` also holds LNM050's files, which the loader skips; LNM067 has
   duplicate `(1)` copies; LNM056 is empty; LNM015 has no Logged files.

## Author

Kaiwen Yang, University of Toronto.
