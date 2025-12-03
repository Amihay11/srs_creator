# MATLAB port of LTE SRS Creator

This folder mirrors the Python toolkit in pure MATLAB so the LTE SRS
examples, tester, and supporting utilities can be run without Python.
It now serves as the single source of documentation for the MATLAB flow;
the previous WordprocessingML handout has been removed and its contents
are folded into this README for easier maintenance.

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

## SRS overview

The LTE Sounding Reference Signal (SRS) lets the eNodeB probe uplink
channel quality. A single SRS symbol is transmitted in the last SC-FDMA
symbol of certain uplink subframes, occupying a comb of subcarriers across
one or more resource blocks (RBs). Key references: 3GPP TS 36.211
Sections 5.5.1–5.5.4.

### Core parameters

- **cell_id (N<sub>ID</sub><sup>cell</sup>)** – Physical cell ID used in the
  Gold sequence (pseudo-random sequence, PRS) that seeds hopping and cyclic
  shift selection.
- **bandwidth_config (C<sub>srs</sub>)** – Bandwidth index that selects which
  contiguous RB span is available to SRS for a given subframe.
- **subframe_config (T<sub>srs</sub>)** – Periodicity pattern determining
  which uplink subframes carry SRS.
- **b_hop** – Hopping bandwidth configuration controlling how the PRS drives
  root hopping among Zadoff–Chu bases.
- **group_hopping_enabled / sequence_hopping_enabled** – Enable group hopping
  (changes the root index group) or sequence hopping (offsets the sequence
  number q(n) when the SRS bandwidth is small).
- **transmission_comb (k<sub>tc</sub>)** – Chooses even or odd subcarriers in
  the comb mapping.
- **cyclic_shift (n<sub>cs</sub>)** – Applies a cyclic phase shift to decorrelate
  SRS from multiple UEs using the same root.
- **srs_bandwidth (B<sub>srs</sub>)** – Active SRS bandwidth index that, with
  `bandwidth_config`, defines the occupied RB range.
- **n_ul_rb** – Uplink system bandwidth in RBs; used to bound the allocation.

### End-to-end signal flow

1) **Configuration and validation** – `lte_srs.create_config` builds a struct
   from user parameters, checks ranges, computes derived values (active RB
   span, comb spacing, cyclic shift indices), and supplies defaults.
2) **Subframe gating** – `lte_srs.is_active_subframe(cfg, n_sf)` determines if
   subframe `n_sf` should carry SRS for the chosen T<sub>srs</sub>.
3) **PRS generation** – `lte_srs.generate_prs` advances the Gold sequence to
   obtain the `n_prs` value for the subframe. This seeds group hopping and the
   cyclic shift.
4) **Group/sequence hopping** – `lte_srs.group_and_sequence_hopping` computes
   the Zadoff–Chu root index u(n) and sequence number q(n) per subframe from
   n<sub>prs</sub>, b<sub>hop</sub>, and hopping flags.
5) **Base sequence** – `lte_srs.generate_zadoff_chu` produces the length-M ZC
   sequence r<sub>u,v</sub>(m) with prime root. `lte_srs.apply_cyclic_shift`
   rotates the sequence by the configured n<sub>cs</sub> to decorrelate UEs.
6) **Comb mapping and bandwidth placement** –
   `lte_srs.map_to_frequency_grid` interleaves tones according to
   k<sub>tc</sub> (even/odd) and centers them in the selected RB span derived
   from B<sub>srs</sub> and C<sub>srs</sub>.
7) **Time-domain symbol** – `lte_srs.generate_srs` assembles the full SRS
   sequence for the subframe, applies any required cyclic shift, and returns
   the complex baseband vector plus mapping metadata (tone indices, root info,
   hopping state) for debugging.

Text diagrams:

```
[Config] -> [PRS n_prs] -> [Group/Sequence Hopping] -> [ZC Root] ->
[Cyclic Shift] -> [Comb Mapping] -> [OFDM Symbol]

Subframe n:   u(n), q(n), n_cs(n)
Subframe n+1: u(n+1), q(n+1), n_cs(n+1)  --> Spectrogram highlights tone jumps
```

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
