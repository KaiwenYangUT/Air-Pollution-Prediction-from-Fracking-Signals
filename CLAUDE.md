# CLAUDE.md

R pipeline for the STA497 noise/air-pollution project. See README.md for the pipeline and layout.

## Privacy rules (non-negotiable)

The data is confidential research data.

- Never open, read, cat, head, tail, grep, sample or print the contents of any data file: `.csv`,
  `.tsv`, `.txt`, `.xlsx`, `.rds`, `.rdata`, `.parquet`, JSON dumps, and the HTML tables or knitted
  reports under `<data_root>/legacy_outputs/` or `outputs/` (they embed values).
- Identify data by file name, extension and size only (`ls`, `du`, `find`). For column names and
  types, use `docs/data_dictionary.md` (regenerate with `Rscript scripts/extract_schema.R`).
- Never paste data values into chat, commits, docs or code. That includes summary statistics,
  correlation coefficients and model metrics from the data.
- Nothing data-related goes into git. `.gitignore` and `scripts/hooks/pre-commit` enforce this;
  check `git ls-files` after committing.
- Do not push to any remote without asking first.
- Nothing is deleted. Archive or back up instead.

## Running code safely

- Data is outside the repo, at `data_root` in `config.yml` (gitignored; template in
  `config.example.yml`). All code finds it through `R/config.R` (`raw_path()`, `processed_path()`,
  `legacy_processed_path()`, `output_path()`).
- Run scripts from the repo root. Redirect their output to `outputs/logs/` (`run_all.R` does this).
  Read only exit codes and counts, never raw logs: R warnings and errors can echo data.
- Don't add `head()`, `print()` or `View()` of data to pipeline code (`df.head()`/`print(df)` in Python).
- Commit notebooks only with outputs stripped (the pre-commit hook enforces this). The originals with
  outputs are in `archive/private/` and are not to be opened.
- The pipeline writes to `processed_rerun/`, never to the legacy `processed/` folder.

## Pipeline

`Rscript scripts/run_all.R` runs steps 01 to 05: stack the sound logs, merge them with pollutants and
met data, write summary tables, correlation heatmaps, then the flare/well spatial join and maps.
`--with-models` adds step 06, XGBoost, which takes hours (`06_models.R --smoke` gives a quick check).
`--with-python` adds the Python steps 07–09 (`python/sta497/` package; `.venv` from `requirements.txt`). Python
scripts write metrics to `outputs/python/*/metrics.csv` and never print them.

`Rscript scripts/verify_outputs.R [--run-notebook]` compares outputs with the legacy files and with
a re-run of the original notebook. It reports PASS/FAIL, checksums and difference counts only.

The R/ modules copy the original notebook logic verbatim, quirks included. Fix a known issue
(README "Known issues") only when asked, in its own commit.
