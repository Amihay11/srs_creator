# MATLAB port of LTE SRS Creator

This folder mirrors the Python toolkit in pure MATLAB so the LTE SRS
examples, tester, and supporting utilities can be run without Python.

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

## Quick start

From MATLAB or Octave, add the `matlab/` folder to your path and run the
tester:

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
metadata mirroring the Python `MappingInfo` structure.

## Word-compatible XML handout

The repository includes `README_docx.xml`, a WordprocessingML version of
this guide that can be opened directly in Microsoft Word or LibreOffice.
It avoids binary `.docx` assets so pull requests stay text-only while still
allowing you to "Save As" a `.docx` if you need a traditional Word file.

## Creating the PDF report

Use MATLAB with the Report Generator toolbox to build the PDF tester
report. It summarizes the UE configurations, validates each SRS sequence,
plots cross-correlation, and adds spectrograms for hopping-enabled UEs.

```matlab
addpath('matlab');
srs_report;                 % writes matlab/srs_report.pdf by default
srs_report('out.pdf');       % custom destination
```
