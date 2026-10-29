"""Paths from config.yml, shared with the R pipeline (see R/config.R).

Data lives outside the repository; nothing here reads or prints data values.
"""
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]


def load_config() -> dict:
    path = REPO_ROOT / "config.yml"
    if not path.exists():
        raise FileNotFoundError(f"{path} not found: copy config.example.yml to config.yml and set data_root")
    cfg = yaml.safe_load(path.read_text())
    for key in ("data_root", "processed_dir", "legacy_processed_dir"):
        cfg[key] = Path(cfg[key]).expanduser()
    return cfg


CFG = load_config()


def processed_path(name: str) -> Path:
    """A derived data file written by the R pipeline (scripts/02 and 05)."""
    return CFG["processed_dir"] / name


def output_path(*parts: str) -> Path:
    """A file under outputs/python/ (gitignored); parent folders are created."""
    path = REPO_ROOT / CFG["outputs_dir"] / "python" / Path(*parts)
    path.parent.mkdir(parents=True, exist_ok=True)
    return path
