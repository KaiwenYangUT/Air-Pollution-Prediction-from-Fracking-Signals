# Listening for Pollution

### Can the sound of an oil field tell us what is in its air?

For a year, from May 2023 to May 2024, a monitoring trailer sat in the Permian Basin, a few kilometres from
working wells and gas flares. Every minute it logged two things: what the air contained (NOx, NO₂,
methane, ozone, sulfur gases) and what the place sounded like, split into 32 frequency bands from a
12.5 Hz rumble to a 16 kHz hiss. The weather station on its roof kept its own log of wind, heat,
humidity and sun.

Machines are loud in characteristic ways. Compressors drone low, pumps hum in the middle, flares roar
and hiss at the top. The hope behind this project is simple: if a machine has an acoustic signature
and also an emissions signature, then listening might be a cheap way to tell which sources are
polluting, and when.

This repository is the full analysis, rebuilt so it can be re-run from raw logs to final figures.
**The data is confidential and is not included.** The code, the methods and the results are.

*A University of Toronto STA497 research project (2024–25), with an STA465 spatial-statistics
extension on the flares and wells around the trailer.*

---

## What we found

**The sound has structure.** The 37 sound measures fall into a few tightly correlated families. Low
bands move together, high bands move together, and there's little crosstalk between them. That's the
first sign that different machines are being heard separately: low frequencies line up with
compressors, generators and drilling, mid frequencies with pumps and pipelines, and high frequencies
with flaring and venting.

**Sound alone predicts some of the pollution, but less than it first appeared.** The original models
were XGBoost regressions scored on a random split of the minutes. On that split, sound explains about
half the variation in NOx. When the models are tested on days they have never seen, that drops to about
a fifth. The reason is explained in [How honest is a score?](#how-honest-is-a-score) below.

**Weather adds real signal.** Adding seven weather variables (temperature, wind speed and direction,
humidity, pressure, water vapour, sunlight) to the sound measures gives the strongest models in the
project: on days they have never seen, they explain about a third of the variation in NOx
and about half of the variation in NO₂, roughly double what sound manages alone. NO₂ is consistently the
easier target.

**The loudest clues are broadband.** The model relies most on the overall A-weighted maximum and minimum
levels, the C-weighted peak and the lowest band, 12.5 Hz, rather than on any single mid-range tone.

**Hand-picking frequencies didn't help.** Keeping one representative from each correlated family (19 of
the 37 measures) seemed to fit better in the original analysis. Under cross-validation it doesn't: the
full set is as good or better.

### The scoreboard

Mean test R² across 5 folds. *Random* folds shuffle minutes; *day* folds hold out whole days.

| Model | Predicts | XGBoost, random | XGBoost, day | Random Forest, random | Random Forest, day |
|---|---|---|---|---|---|
| All 37 sound measures | NOx | 0.49 | 0.18 | 0.41 | 0.22 |
| 19 selected frequencies | NOx | 0.42 | 0.17 | 0.35 | 0.20 |
| Sound + weather (44 predictors) | NOx | 0.66 | **0.34** | 0.57 | **0.34** |
| Sound + weather (44 predictors) | NO₂ | 0.81 | **0.51** | 0.77 | **0.53** |
| STA465: 18 frequencies + wells + weather | NOx | 0.71 | 0.18 | 0.55 | 0.26 |

On a single random 60/20/20 split, the setup the original notebooks used, the sound + weather
XGBoost reaches R² 0.80 for NO₂ and 0.64 for NOx.

### How honest is a score?

Pollution and noise change slowly from minute to minute. If the 10:41 reading is in the training set
and the 10:42 reading is in the test set, the model hasn't learned much by "predicting" the second: it has
effectively seen the answer. Random splits of minute-level data are full of these near-twins, so they
flatter every model.

Holding out whole days removes the twins and asks the question that matters in practice: given a day
the model has never heard, how well can it read the air? Three things stand out:

- Every model loses a large share of its apparent skill: sound-only models lose about two thirds, and
  sound + weather models about 40%. Day-fold scores are the ones to quote.
- Random Forest matches or beats the deep XGBoost models (depth 9–12) on unseen days, even though
  XGBoost wins on random folds. Deep boosted trees tend to memorize within-day patterns.
- Days differ a lot. For the sound-only models, individual day folds range from about 0.09 to 0.41 R²,
  so some days sound much more like their pollution than others. Adding weather narrows that spread.

The STA465 table makes the effect especially stark: it repeats each minute once per flare seen that day,
so in the original split the same minute could sit on both sides. With one copy per minute and days held
out, it lands with the sound-only models, below sound + weather on the full year. It is limited to
flare days (about 9,600 minutes), which leaves too little data for wells and flares to add anything.

---

## Inside the machine

The analysis runs as ten numbered steps: R for the data engineering and figures, Python for the heavier
modelling.

| Step | Script | What it does | Where results land |
|---|---|---|---|
| 1 | `01_stack_sound.R` | Stacks 89 monitor deployments of minute-level sound logs | `processed_rerun/008_097_logged_*.rdata` |
| 2 | `02_merge_sound_pollutant_met.R` | Cleans five pollutant feeds and the weather, joins them to sound by minute | `sound_pollutant_met_data.*` |
| 3 | `03_summary_tables.R` | Summary tables for sound, pollutants and weather | `outputs/tables/` |
| 4 | `04_correlation_heatmaps.R` | Pearson/Spearman heatmaps, all data and temperature/wind subsets | `outputs/figures/` |
| 5 | `05_spatial_flare_well.R` | Flares and wells within 20 km; joins them by date and month; maps | `flare_well_*.csv`, `outputs/maps/` |
| 6 | `06_models.R` *(optional)* | Early R XGBoost experiments (slow) | `outputs/models/` |
| 7 | `07_python_sta497_models.py` | XGBoost NOx/NO₂ models (sound only and sound + weather), feature importance, prediction plots | `outputs/python/sta497/` |
| 8 | `08_python_sta465_models.py` | Linear and XGBoost models with flares and wells | `outputs/python/sta465/` |
| 9 | `09_python_ac_sound_spectrograms.py` | Spectrograms for spotting air-conditioner cycling | `outputs/python/ac_sound/` |
| 10 | `10_python_kfold_cv.py` | The scoreboard: 5-fold CV, XGBoost vs Random Forest, random vs day folds | `outputs/python/sta497_cv/` |

```
R/              config, load, clean, features (merges, subsets), visualize, model
python/sta497/  config, data, variables, models, cv, plots
scripts/        the numbered steps, run_all.R, verify_outputs.R, extract_schema.R, hooks/
notebooks/      the original R Markdown and Colab notebooks (outputs stripped), kept for reference
archive/        superseded drafts
docs/           data dictionary, verification report, slides
outputs/        everything generated (gitignored)
```

## Running it yourself

You'll need R 4.5, pandoc, Python 3.11, and access to the data.

1. Point the code at the data:

   ```bash
   cp config.example.yml config.yml
   ```

   Then set `data_root` in `config.yml`.

2. Restore the pinned R packages:

   ```bash
   Rscript -e 'renv::restore()'
   ```

3. Create the Python environment:

   ```bash
   python3.11 -m venv .venv
   ```

   ```bash
   .venv/bin/pip install -r requirements.txt
   ```

4. Run everything:

   ```bash
   Rscript scripts/run_all.R --with-python
   ```

   `--from N` resumes at step N, and `--with-models` adds the slow R step 6. Console output goes to
   `outputs/logs/`, never the terminal.

5. Check the rebuild against the original outputs:

   ```bash
   Rscript scripts/verify_outputs.R --run-notebook
   ```

The data stays outside the repository:

```
<data_root>/
├── raw/
│   ├── sound/LNM*/      sound-level-meter logs, one folder per deployment
│   ├── pollutants/      1-minute CH4, CO, H2S/SO2, NOx, O3
│   ├── met/             1-minute weather
│   └── spatial/         well production and VIIRS flare detections
├── processed/           derived data from the original 2024–25 runs (verification baseline)
└── processed_rerun/     derived data written by this pipeline
```

Column names and types are listed in [docs/data_dictionary.md](docs/data_dictionary.md). A pre-commit
hook keeps data files and notebook outputs out of git. Install it once per clone:

```bash
cp scripts/hooks/pre-commit .git/hooks/pre-commit
```

## Rebuilding it faithfully

The original analysis lived in R Markdown and Colab notebooks. Rebuilding it meant reproducing their
outputs exactly, then fixing what was wrong in the open. The details are in
[docs/verification.md](docs/verification.md).

- **Reproduced:** the merged analysis tables (byte-identical CSVs), the legacy figures and summary
  tables (apart from those listed below), and the original full-data NOx model (within 0.002 R²).
- **Fixed:** the "> 100 °F" heatmaps were built from the ≤ 70 °F rows. They now use the right rows, and the
  legacy versions are kept for comparison. Several notebook slips (tuning loops scored on the wrong data,
  printouts of the wrong model) are corrected in the Python code.
- **Not reproducible:** two figures and a summary table from November 2024, and the STA465 notebook's
  printed scores, came from earlier, unrecorded versions of the code or data.

## Loose threads

- **Whose clock?** The legacy tables match only when sound timestamps are read as UTC, the zone of the
  pollutant feed, so `sound_tz: UTC` reproduces them. If the loggers actually record local Mountain time,
  sound and air are offset by several hours. Confirming the logger clock is the most valuable open question.
- **Like-for-like.** In STA465, the all-predictor models predict SO₂ while the selected-predictor model
  predicts NOx. The Python subset models use ≤ 75 °F, while the R heatmaps use ≤ 70 °F.
- **A stray column.** The legacy merged table has a `Night` column that no surviving code creates. Nothing
  downstream uses it.
- **Odd files.** `raw/sound/LNM049/` also holds LNM050's logs, which the loader skips. LNM067 has duplicate
  copies, LNM056 is empty and LNM015 has no Logged files.
- **Fixed hyperparameters.** Final XGBoost settings are the ones the notebooks settled on. `--tune` on
  step 7 re-runs the grid search.

## Author

**Kaiwen Yang**, University of Toronto. Slides from the STA497 presentation and an STA304 guest lecture are
in [docs/slides/](docs/slides/).
