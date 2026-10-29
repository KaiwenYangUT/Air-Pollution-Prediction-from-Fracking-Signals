"""Loading the R pipeline's CSV outputs and preparing model data."""
import numpy as np
import pandas as pd

from .config import processed_path


def load_csv(name: str, columns=None) -> pd.DataFrame:
    """Read a pipeline CSV with spaces in column names replaced by underscores
    (e.g. "LZeq 12.5Hz" -> "LZeq_12.5Hz"), as every notebook did first.

    `columns` (underscore names) limits what is read; the full flare/well table is ~1 GB.
    """
    path = processed_path(name)
    header = pd.read_csv(path, nrows=0).columns
    usecols = None
    if columns is not None:
        wanted = set(columns)
        usecols = [c for c in header if c.replace(" ", "_") in wanted]
    df = pd.read_csv(path, usecols=usecols)
    df.columns = [c.replace(" ", "_") for c in df.columns]
    return df


def prepare(df: pd.DataFrame, columns) -> pd.DataFrame:
    """Coerce `columns` to numeric and drop rows missing any of them (notebook "Step 1")."""
    df = df.copy()
    for col in columns:
        if not np.issubdtype(df[col].dtype, np.floating):
            df[col] = pd.to_numeric(df[col], errors="coerce")
    return df.dropna(subset=list(columns))
