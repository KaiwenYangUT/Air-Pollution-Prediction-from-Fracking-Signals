"""Predictor lists and data subsets used by the models."""
import pandas as pd

# The 37 sound measures: 5 weighted levels and 32 one-third-octave bands.
FREQUENCY = [
    "LAFmax", "LAFmin", "LCpeak", "LAeq", "LCeq", "LZeq_12.5Hz",
    "LZeq_16Hz", "LZeq_20Hz", "LZeq_25Hz", "LZeq_31.5Hz", "LZeq_40Hz",
    "LZeq_50Hz", "LZeq_63Hz", "LZeq_80Hz", "LZeq_100Hz", "LZeq_125Hz",
    "LZeq_160Hz", "LZeq_200Hz", "LZeq_250Hz", "LZeq_315Hz", "LZeq_400Hz",
    "LZeq_500Hz", "LZeq_630Hz", "LZeq_800Hz", "LZeq_1kHz", "LZeq_1.25kHz",
    "LZeq_1.6kHz", "LZeq_2kHz", "LZeq_2.5kHz", "LZeq_3.15kHz", "LZeq_4kHz",
    "LZeq_5kHz", "LZeq_6.3kHz", "LZeq_8kHz", "LZeq_10kHz", "LZeq_12.5kHz",
    "LZeq_16kHz",
]

# The 32 unweighted bands only (spectrograms).
BANDS = [c for c in FREQUENCY if c.startswith("LZeq_")]

# Frequencies kept after grouping bands correlated above 0.9 (one representative per group
# plus the weakly correlated bands); see the "Frequency corr > 0.9" section of the slides.
SELECTED_FREQUENCY = [
    "LAFmax", "LAFmin", "LCpeak", "LAeq", "LCeq", "LZeq_12.5Hz",
    "LZeq_25Hz",
    "LZeq_63Hz", "LZeq_80Hz", "LZeq_100Hz", "LZeq_125Hz",
    "LZeq_160Hz", "LZeq_200Hz", "LZeq_250Hz",
    "LZeq_500Hz", "LZeq_1.25kHz",
    "LZeq_1.6kHz",
    "LZeq_5kHz", "LZeq_12.5kHz",
]

# Meteorological predictors added in the "with met" models.
MET = ["temp_f", "wsp_ms", "wdr_deg", "relh_percent", "pressure_altcorr", "water_vapor_mr_g_kg", "solr_W_m2"]

# Monthly well production within 20 km (joined by month) and flare temperature (by date).
WELLS = ["num_oil_wells", "num_gas_wells", "avg_monthly_oil", "avg_monthly_gas"]
FLARE = ["temp_bb"]

# STA465 predictor sets. The selected set is SELECTED_FREQUENCY without LCeq, as in the
# original STA465 notebook, plus wells and met (no flare temperature).
STA465_ALL = FREQUENCY + WELLS + MET + FLARE
STA465_SELECTED = [c for c in SELECTED_FREQUENCY if c != "LCeq"] + WELLS + MET


def low_temp_low_wind(df: pd.DataFrame, temp_max: float = 75, wind_max: float = 7) -> pd.DataFrame:
    """Rows with temperature <= temp_max (F) and wind speed <= wind_max (m/s).

    The Python models used 75F; the R correlation heatmaps used 70F.
    """
    subset = df[df["temp_f"] <= temp_max]
    return subset[subset["wsp_ms"] <= wind_max]
