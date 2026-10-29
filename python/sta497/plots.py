"""Figures, saved as PNG (the notebooks displayed them inline)."""
import matplotlib

matplotlib.use("Agg")
import matplotlib.dates as mdates  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import seaborn as sns  # noqa: E402
import xgboost as xgb  # noqa: E402


def _save(path):
    plt.tight_layout()
    plt.savefig(path, dpi=100)
    plt.close("all")


def importance(model, path, title, max_features, figsize=(10, 20), xtick_size=10, ytick_size=10):
    """Feature importance by split count ("weight"), the notebooks' setting."""
    fig, ax = plt.subplots(figsize=figsize)
    xgb.plot_importance(model, ax=ax, importance_type="weight", max_num_features=max_features, height=0.5)
    ax.set_title(title, fontsize=14)
    ax.set_xlabel("F score", fontsize=12)
    ax.set_ylabel("Features", fontsize=12)
    ax.tick_params(axis="x", labelsize=xtick_size)
    ax.tick_params(axis="y", labelsize=ytick_size)
    ax.set_xlim(0, ax.get_xlim()[1] * 1.1)  # room for the value labels
    _save(path)


def predicted_vs_actual(actual, predicted, path, title, log=False):
    """Scatter of predictions against actual values with the 45-degree line; log uses log1p."""
    actual, predicted = np.asarray(actual), np.asarray(predicted)
    if log:
        actual, predicted = np.log1p(actual), np.log1p(predicted)
    lo, hi = min(actual.min(), predicted.min()), max(actual.max(), predicted.max())
    plt.figure(figsize=(10, 8))
    plt.scatter(actual, predicted, alpha=0.3, edgecolors="k", s=10)
    plt.plot([lo, hi], [lo, hi], color="red", linestyle="--", linewidth=2, label="45-degree line")
    plt.xlabel("Log(Actual Values + 1)" if log else "Actual Values")
    plt.ylabel("Log(Predicted Values + 1)" if log else "Predicted Values")
    plt.title(title)
    plt.legend()
    plt.grid(True)
    _save(path)


def residuals(predicted, actual, path_prefix, label):
    """Residuals-vs-predicted scatter and residual histogram (two files)."""
    resid = np.asarray(actual) - np.asarray(predicted)
    plt.figure(figsize=(8, 6))
    sns.scatterplot(x=predicted, y=resid)
    plt.axhline(0, color="red", linestyle="--")
    plt.xlabel("Predicted Values")
    plt.ylabel("Residuals")
    plt.title(f"Residuals vs Predicted Values{label}")
    plt.grid(True)
    _save(f"{path_prefix}_residuals_vs_predicted.png")
    plt.figure(figsize=(8, 6))
    sns.histplot(resid, kde=True, bins=30)
    plt.xlabel("Residuals")
    plt.ylabel("Frequency")
    plt.title(f"Histogram of Residuals{label}")
    plt.grid(True)
    _save(f"{path_prefix}_residual_histogram.png")


def spectrogram(df, time_col, bands, path, title="Spectrogram of Sound Frequencies Over Time"):
    """Bands (y) over time (x) coloured by level; missing values are drawn as 0."""
    times = pd.to_datetime(df[time_col]).to_numpy()
    levels = np.nan_to_num(df[bands].to_numpy().T)
    plt.figure(figsize=(12, 8))
    plt.pcolormesh(times, np.arange(len(bands)), levels, shading="auto", cmap="viridis")
    plt.colorbar(label="Amplitude")
    plt.xlabel("Time")
    plt.ylabel("Frequency Levels")
    plt.title(title)
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter("%Y-%m-%d"))
    plt.gca().xaxis.set_major_locator(mdates.WeekdayLocator(interval=1))
    plt.xticks(rotation=45)
    plt.yticks(ticks=np.arange(len(bands)), labels=bands, fontsize=8)
    _save(path)


def line_with_points(x, y, point_idx, path, title, ylabel):
    """Line plot with selected points highlighted (change-point detection)."""
    plt.figure(figsize=(10, 6))
    plt.plot(x, y, label=ylabel)
    plt.scatter(x.iloc[point_idx], y.iloc[point_idx], color="red", label="Detected Peaks")
    plt.xlabel("Time")
    plt.ylabel(ylabel)
    plt.title(title)
    plt.legend()
    _save(path)


def spectrum(freqs, magnitude, path, title):
    plt.figure(figsize=(10, 5))
    plt.plot(freqs, magnitude)
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Magnitude")
    plt.title(title)
    plt.grid()
    _save(path)
