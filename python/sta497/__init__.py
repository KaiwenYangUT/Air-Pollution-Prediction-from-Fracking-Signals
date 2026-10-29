"""Python modelling code for the STA497 / STA465 noise and air-pollution project.

Restructured from the original Colab notebooks (notebooks/python/). Modules:
    config     paths from the shared config.yml
    data       loading the pipeline's CSV outputs and preparing model matrices
    variables  predictor lists and data subsets
    models     train/validation/test split, XGBoost tuning and training, metrics
    plots      feature importance, prediction, residual, spectrogram and FFT figures
"""
