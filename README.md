# LTE SRS Creator

This repository provides a lightweight Python toolkit for generating LTE Sounding Reference Signals (SRS) according to 3GPP TS 36.211/36.213. The library focuses on clarity and modularity to make experimentation and education straightforward.

## Features
- UE configuration management (`SRSConfig`)
- Zadoff–Chu base sequence generation
- Group and sequence hopping support
- Cyclic shifts and transmission comb mapping
- Time-domain SRS synthesis and mapping metadata
- Cross-correlation utilities for interference analysis

## Getting Started
The project depends on NumPy and Matplotlib. From the repository root:

```bash
python -m pip install --upgrade pip
python -m pip install numpy matplotlib
```

## Example Usage
Run the included tester to generate several SRS instances, compute their cross-correlation matrix, and save a heatmap:

```bash
python srs_tester.py
```

The script prints the configurations used, the correlation matrix, and the location of the saved plot (`correlation_matrix.png`).
