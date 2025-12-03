# MATLAB port of LTE SRS Creator

This folder mirrors the Python toolkit in pure MATLAB so the LTE SRS
examples, tester, and supporting utilities can be run without Python.
High-level usage is summarized here; an in-depth theory and parameter
walkthrough now lives in `SRS_SIGNAL_GUIDE.md`.

## Structure

- `+lte_srs/` – Package containing configuration helpers and the SRS signal
  generation primitives (Gold sequence, Zadoff–Chu sequence, mapping,
  and correlation utilities).
- `srs_tester.m` – Standalone script equivalent to `srs_tester.py` that
  builds example UE configurations, synthesizes their SRS symbols,
  computes the normalized cross-correlation matrix, and saves a heatmap
  (`correlation_matrix.png`).
- `srs_report.m` – Generates a PDF validation report using MATLAB Report
  Generator with per-UE sequence plots, hopping spectrograms, and a
  cross-correlation heatmap.

## Detailed theory and parameter reference

See `SRS_SIGNAL_GUIDE.md` for:

- Equations for PRS generation, Zadoff–Chu synthesis, and comb mapping.
- Parameter tables (allowed values, 36.211 references, and MATLAB defaults).
- Worked examples that trace `srs_tester` and `srs_report` outputs.
- Signal-flow diagrams and narrative explaining how subframe hopping and
  cyclic shifts interact.

## Quick start

From MATLAB, add the `matlab/` folder to your path and run the tester:

```matlab
addpath('matlab');
srs_tester
```

To generate an SRS symbol directly:

```matlab
addpath('matlab');
cfg = lte_srs.create_config( ...
    'cell_id', 42, ...
    'bandwidth_config', 2, ...
    'subframe_config', 4, ...
    'b_hop', 1, ...
    'group_hopping_enabled', true, ...
    'sequence_hopping_enabled', false, ...
    'transmission_comb', 0, ...
    'cyclic_shift', pi/2, ...
    'srs_bandwidth', 2, ...
    'n_ul_rb', 50 ...
);
[signal, info] = lte_srs.generate_srs(cfg, 8);
```

The output `signal` is a complex baseband OFDM symbol and `info` contains
metadata (tone indices, hopping state, and root selection) mirroring the
Python `MappingInfo` structure.

## Validation and reporting

- **Tester** – `srs_tester.m` builds multiple UE configs, synthesizes their
  SRS, and plots the normalized cross-correlation matrix (saved as
  `correlation_matrix.png`).
- **PDF report** – `srs_report.m` (MATLAB Report Generator) assembles a PDF
  with configuration tables, per-UE constellation/time plots, hopping
  spectrograms, and the correlation heatmap.

```matlab
addpath('matlab');
srs_report;           % writes matlab/srs_report.pdf by default
srs_report('out.pdf');% custom destination
```
