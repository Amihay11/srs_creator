# LTE SRS Creator

This repository provides a lightweight Python toolkit for generating LTE Sounding Reference Signals (SRS) according to 3GPP TS 36.211/36.213. The library focuses on clarity and modularity to make experimentation and education straightforward.

## Features
- UE configuration management (`SRSConfig`)
- Zadoff–Chu base sequence generation
- Group and sequence hopping support
- Cyclic shifts and transmission comb mapping
- Time-domain SRS synthesis and mapping metadata
- Cross-correlation utilities for interference analysis

## SRS Configuration Parameters
The library models the key LTE uplink SRS knobs exposed by higher-layer signaling:

- **Cell ID (`cell_id`)**: Physical cell identity (0–503) seeds the Gold sequence used for hopping.
- **Bandwidth Configuration (`bandwidth_config`, B<sub>srs</sub>)**: Index 0–7 that scales the reference bandwidth available for SRS.
- **Subframe Configuration (`subframe_config`, T<sub>srs</sub>)**: Periodicity in subframes. If set to 0, SRS is disabled for that UE.
- **Frequency Hopping Parameter (`b_hop`)**: Selects one of four hopping bandwidth sets defined in TS 36.211.
- **Group Hopping (`group_hopping_enabled`)**: Enables pseudo-random group index hopping across slots.
- **Sequence Hopping (`sequence_hopping_enabled`)**: Toggles the base sequence within a group between slots.
- **Transmission Comb (`transmission_comb`, k<sub>tc</sub>)**: Chooses even or odd subcarrier mapping (0 or 1), doubling the tone spacing.
- **Cyclic Shift (`cyclic_shift`, α)**: Phase ramp applied to the base sequence; typically multiples of π/4.
- **SRS Bandwidth (`srs_bandwidth`, N<sub>b</sub>)**: Selects how many resource blocks of the configured B<sub>srs</sub> are occupied.
- **UL Bandwidth (`n_ul_rb`)**: Total uplink resource blocks for bounding the occupied SRS tones.
- **Zadoff–Chu Length (`n_zc`, optional)**: Overrides the default 839-length base sequence if experimentation requires.

## Example: Generate an SRS Symbol with Full Control
Below is a minimal example that instantiates an `SRSConfig`, generates the SRS for a chosen subframe, and prints mapping metadata:

```python
import numpy as np
from lte_srs import SRSConfig, generate_srs

config = SRSConfig(
    cell_id=42,
    bandwidth_config=2,      # B_srs
    subframe_config=4,       # T_srs periodicity (send on subframes 0,4,8,...)
    b_hop=1,                 # hopping set
    group_hopping_enabled=True,
    sequence_hopping_enabled=False,
    transmission_comb=0,     # k_tc = 0 (even tones)
    cyclic_shift=np.pi / 2,  # alpha
    srs_bandwidth=2,         # N_b
    n_ul_rb=50,              # system BW in RBs
)

subframe = 8
signal, info = generate_srs(config, subframe_index=subframe, n_fft=2048)
print(f"Generated {len(signal)}-sample SRS for subframe {subframe}")
print("Mapping summary:", info.summary())
```

`signal` contains one OFDM symbol of complex baseband SRS samples. The accompanying `MappingInfo` describes the hopping state, cyclic shift, comb offset, and occupied bandwidth.

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
