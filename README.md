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

Requires R 4.5 and pandoc (for the self-contained map files).

```bash
cp config.example.yml config.yml
```

Edit `data_root` in `config.yml`, then restore the pinned packages:

```bash
Rscript -e 'renv::restore()'
```

## Running

From the repo root:

```bash
Rscript scripts/run_all.R
```

`--with-models` also runs the slow XGBoost step (hours) and `--from N` resumes at step N.
Each step's console output goes to `outputs/logs/`, not the terminal.

| Step | Script | Outputs |
|---|---|---|
| 1 | `scripts/01_stack_sound.R` | `008_097_logged_{spectra,bb}.rdata` |
| 2 | `scripts/02_merge_sound_pollutant_met.R` | `sound_merge_data.rdata`, `sound_pollutant_data.*`, `sound_pollutant_met_data.*` |
| 3 | `scripts/03_summary_tables.R` | `outputs/tables/{frequency,pollutant,met}_summary_table.html` |
| 4 | `scripts/04_correlation_heatmaps.R` | `outputs/figures/**.png` (Pearson/Spearman, all data and temperature/wind subsets) |
| 5 | `scripts/05_spatial_flare_well.R` | `flare_well_sound_pollutant_met_data.csv`, wells/frequency tables, `outputs/maps/*.html` |
| 6 | `scripts/06_models.R` (optional) | `outputs/models/` |

Derived data goes to `processed_rerun/`, and figures, tables and maps go to `outputs/` (gitignored).

To check a run against the original outputs:

```bash
Rscript scripts/verify_outputs.R --run-notebook
```

## Repository layout

```
R/            functions: config, load, clean, features (merges/subsets), visualize, model
scripts/      numbered pipeline steps, run_all.R, verify_outputs.R, extract_schema.R, hooks/
notebooks/    original R Markdown notebooks (paths updated only), kept for reference
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
4. **Missing model code.** The selected-frequency model, linear regression, feature-importance charts and
   R² values in the slides were produced by code that is not part of this project.
5. **Raw-data quirks.** `raw/sound/LNM049/` also holds LNM050's files, which the loader skips; LNM067 has
   duplicate `(1)` copies; LNM056 is empty; LNM015 has no Logged files.

## Author

Kaiwen Yang, University of Toronto.
