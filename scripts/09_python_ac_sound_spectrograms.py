#!/usr/bin/env python
"""Step 9 (Python): spectrograms of the 32 sound bands over selected periods, and a simple
change-point view, to look for air-conditioner on/off patterns (planned future work).

Restructured from notebooks/python/08_AC_sound_spectrograms.ipynb. Dropped from the notebook:
an unfinished STFT cell that referenced undefined variables, and a cell that printed rows.

Run from the repo root:  .venv/bin/python scripts/09_python_ac_sound_spectrograms.py
Outputs: outputs/python/ac_sound/*.png
"""
import sys
from pathlib import Path

import pandas as pd
from scipy.signal import find_peaks

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))
from sta497 import plots  # noqa: E402
from sta497.config import output_path  # noqa: E402
from sta497.data import load_csv  # noqa: E402
from sta497.variables import BANDS  # noqa: E402

# (file label, start inclusive, end exclusive). The notebook headed the August week "May".
WINDOWS = [
    ("2023-06-23_to_2023-11-23", "2023-06-23", "2023-11-23"),
    ("2023-08-01_week", "2023-08-01", "2023-08-07"),
    ("2023-05_first_half", "2023-05-01", "2023-05-16"),
    ("2023-05-13_to_14", "2023-05-13", "2023-05-15"),
    ("2024-01_to_06", "2024-01-01", "2024-07-01"),  # 2024 data start in early March
    ("2024-04", "2024-04-01", "2024-05-01"),
    ("2024-04_first_half", "2024-04-01", "2024-04-16"),
    ("2024-04-06", "2024-04-06", "2024-04-07"),
]


def main():
    df = load_csv("sound_pollutant_met_data.csv", BANDS + ["time_utc"])
    df["time_utc"] = pd.to_datetime(df["time_utc"], errors="coerce")

    for label, start, end in WINDOWS:
        window = df[(df["time_utc"] >= start) & (df["time_utc"] < end)]
        plots.spectrogram(window, "time_utc", BANDS, output_path("ac_sound", f"spectrogram_{label}.png"))
        print(f"  spectrogram {label}: done")

    # Peaks in the mean level across bands. height=0.5 (dB) is far below typical levels, so
    # nearly every local maximum qualifies; tune it before reading anything into the result.
    mean_amplitude = df[BANDS].mean(axis=1)
    peaks, _ = find_peaks(mean_amplitude, height=0.5)
    plots.line_with_points(df["time_utc"], mean_amplitude, peaks,
                           output_path("ac_sound", "change_points_mean_amplitude.png"),
                           "Change Point Detection in Sound Data", "Mean Amplitude")
    print("Step 9 done")


if __name__ == "__main__":
    main()
