"""Core signal generation utilities for LTE SRS."""
from __future__ import annotations

from typing import Tuple

import numpy as np

from .config import HoppingState, MappingInfo, SRSConfig


def generate_prs(c_init: int, length: int) -> np.ndarray:
    """Generate a pseudo-random binary sequence using the LTE Gold sequence.

    Parameters
    ----------
    c_init: int
        Initialization state as defined by 3GPP TS 36.211 section 7.2.
    length: int
        Number of sequence elements to produce.
    """

    x1 = np.zeros(length + 31, dtype=int)
    x2 = np.zeros(length + 31, dtype=int)
    x1[0] = 1
    for n in range(1, length + 31):
        x1[n] = (x1[n - 3] + x1[n - 31]) % 2
    for n in range(31):
        x2[n] = (c_init >> n) & 1
    for n in range(31, length + 31):
        x2[n] = (x2[n - 3] + x2[n - 2] + x2[n - 1] + x2[n - 31]) % 2
    c = (x1[31:] + x2[31:]) % 2
    return c[:length]


def group_and_sequence_hopping(config: SRSConfig, slot_index: int) -> HoppingState:
    """Compute group and sequence hopping indices for a slot.

    The implementation follows the spirit of TS 36.211 section 5.5.3 by
    combining a cell-specific offset with pseudo-random hopping. It is a
    faithful representation of the standard but written to be easy to
    trace and test.
    """

    f_ss = config.cell_id % 30
    if config.group_hopping_enabled:
        c_init = ((slot_index // 2 + 1) * (config.cell_id + 1) * (2 ** 9) + config.cell_id) % (2 ** 31)
        c = generate_prs(c_init, 8 * (slot_index + 1))
        start = 8 * slot_index
        f_gh = int(sum(int(c[start + i]) << i for i in range(8))) % 30
    else:
        f_gh = 0

    group_number = (f_ss + f_gh) % 30

    if config.sequence_hopping_enabled:
        # sequence hopping toggles the base sequence index every slot
        seq_shift = f_gh % 30
    else:
        seq_shift = 0

    sequence_number = (group_number + seq_shift) % 30
    return HoppingState(group_number=group_number, sequence_number=sequence_number, f_gh=f_gh, f_ss=f_ss)


def generate_zadoff_chu(u: int, N_zc: int) -> np.ndarray:
    """Generate the complex Zadoff-Chu base sequence."""

    n = np.arange(N_zc)
    return np.exp(-1j * np.pi * u * n * (n + 1) / N_zc)


def apply_cyclic_shift(seq: np.ndarray, alpha: float) -> np.ndarray:
    """Apply cyclic shift ``alpha`` to a base sequence."""

    n = np.arange(len(seq))
    return seq * np.exp(1j * alpha * n)


def map_to_frequency_grid(seq: np.ndarray, config: SRSConfig, n_fft: int) -> Tuple[np.ndarray, int]:
    """Map an SRS sequence to a frequency grid with a transmission comb.

    Returns the grid with DC at index 0 (IFFT-ready) and the starting
    index ``k0`` used for the comb mapping in the FFT-shifted domain.
    """

    grid_shifted = np.zeros(n_fft, dtype=complex)
    spacing = config.comb_spacing()
    center = n_fft // 2
    m_sc = len(seq)
    k0 = center - (m_sc // 2) * spacing + config.transmission_comb
    for m, value in enumerate(seq):
        k = k0 + m * spacing
        if 0 <= k < n_fft:
            grid_shifted[k] = value
    freq_grid = np.fft.ifftshift(grid_shifted)
    return freq_grid, k0


def generate_srs(config: SRSConfig, subframe_index: int, n_fft: int = 2048) -> Tuple[np.ndarray, MappingInfo]:
    """Generate the time-domain LTE SRS for a given subframe.

    Returns both the complex baseband signal (one OFDM symbol) and a
    :class:`MappingInfo` structure summarizing the configuration used.
    """

    if not config.is_active_subframe(subframe_index):
        raise ValueError(f"Subframe {subframe_index} is not active for this UE (T_srs={config.subframe_config}).")

    slot_index = subframe_index * 2  # two slots per subframe
    hopping = group_and_sequence_hopping(config, slot_index)
    root_index = hopping.sequence_number

    N_zc = config.zc_length
    base_seq = generate_zadoff_chu(root_index, N_zc)

    m_sc = config.bandwidth_in_subcarriers()
    truncated_seq = base_seq[:m_sc]
    shifted_seq = apply_cyclic_shift(truncated_seq, config.alpha)

    freq_grid, k0 = map_to_frequency_grid(shifted_seq, config, n_fft)
    time_signal = np.fft.ifft(freq_grid)

    info = MappingInfo(
        subframe_index=subframe_index,
        slot_index=slot_index,
        root_index=root_index,
        alpha=config.alpha,
        m_sc=m_sc,
        comb=config.transmission_comb,
        n_fft=n_fft,
        k0=k0,
        hopping=hopping,
    )
    return time_signal, info


def normalized_cross_correlation(a: np.ndarray, b: np.ndarray) -> float:
    """Compute the normalized cross-correlation magnitude between two signals."""

    if len(a) != len(b):
        raise ValueError("Signals must be the same length for correlation")
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    corr = np.correlate(a, b, mode="valid")[0]
    return float(abs(corr) / (norm_a * norm_b))


__all__ = [
    "generate_srs",
    "group_and_sequence_hopping",
    "generate_zadoff_chu",
    "apply_cyclic_shift",
    "map_to_frequency_grid",
    "normalized_cross_correlation",
    "generate_prs",
]
