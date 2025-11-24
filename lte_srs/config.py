"""Configuration classes for LTE SRS generation.

This module wraps the SRS configuration parameters defined in
3GPP TS 36.211 and TS 36.213. The configuration is intentionally
minimalist to cover the most commonly used fields while keeping
validation lightweight so the generator functions can remain
functional and test-friendly.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class SRSConfig:
    """Container for UE-specific LTE SRS settings.

    Parameters
    ----------
    cell_id: int
        Physical cell identity (0..503).
    bandwidth_config: int
        B_srs index from TS 36.213 (0..7). Controls the reference
        bandwidth the UE can occupy.
    subframe_config: int
        T_srs periodicity value in subframes. If set to ``0`` the SRS is
        considered disabled for scheduling purposes.
    b_hop: int
        Frequency hopping parameter (0..3) controlling the available
        hopping set as defined in TS 36.211 section 5.5.3.3.
    group_hopping_enabled: bool
        Whether group hopping is enabled.
    sequence_hopping_enabled: bool
        Whether sequence hopping is enabled.
    transmission_comb: int
        Comb selection k_tc (0 or 1) indicating even/odd subcarrier
        mapping.
    cyclic_shift: float
        Cyclic shift ``alpha`` in radians. 3GPP typically signals it as
        multiples of ``pi/4`` but a raw value is accepted here to make
        experimentation easier.
    srs_bandwidth: int
        N_b value selecting the actual occupied SRS bandwidth.
    n_ul_rb: int
        Number of UL resource blocks in the system bandwidth. Used to
        bound the resulting SRS span.
    n_zc: Optional[int]
        Optional length of the underlying Zadoff-Chu sequence. If not
        provided, 839 (the maximum ZC length defined for LTE uplink) is
        used.
    """

    cell_id: int
    bandwidth_config: int
    subframe_config: int
    b_hop: int
    group_hopping_enabled: bool
    sequence_hopping_enabled: bool
    transmission_comb: int
    cyclic_shift: float
    srs_bandwidth: int
    n_ul_rb: int
    n_zc: Optional[int] = None

    def is_active_subframe(self, subframe: int) -> bool:
        """Return ``True`` if the UE is configured to send SRS in this subframe.

        A ``subframe_config`` of 0 means the feature is disabled.
        Otherwise the SRS is active every ``T_srs`` subframes. The exact
        mapping between T_srs and subframe index is configurable by
        higher-layer signaling; for simplicity we treat it as a pure
        modulo rule.
        """

        if self.subframe_config == 0:
            return False
        return subframe % self.subframe_config == 0

    @property
    def alpha(self) -> float:
        """Return the normalized cyclic shift value ``alpha`` in radians."""

        return float(self.cyclic_shift)

    @property
    def zc_length(self) -> int:
        """Return the length of the underlying Zadoff-Chu sequence."""

        return 839 if self.n_zc is None else int(self.n_zc)

    def bandwidth_in_subcarriers(self) -> int:
        """Compute the number of SRS subcarriers ``M_sc``.

        The mapping between ``B_srs`` and the usable SRS bandwidth is
        summarized in TS 36.213 Table 8.2.1, but many practical
        implementations only need the relative scaling. Here we
        approximate it with ``(N_b + 1) * 12 * 2**B_srs`` while ensuring
        the result does not exceed the configured UL bandwidth.
        """

        scaling = 2 ** max(self.bandwidth_config, 0)
        raw = (self.srs_bandwidth + 1) * 12 * scaling
        max_sc = self.n_ul_rb * 12
        return int(min(raw, max_sc))

    def comb_spacing(self) -> int:
        """Return the subcarrier spacing determined by ``k_tc``."""

        return 2

    def __post_init__(self) -> None:
        if not (0 <= self.cell_id <= 503):
            raise ValueError("cell_id must be between 0 and 503")
        if self.transmission_comb not in (0, 1):
            raise ValueError("transmission_comb (k_tc) must be 0 or 1")
        if self.bandwidth_config < 0:
            raise ValueError("bandwidth_config (B_srs) must be non-negative")
        if self.subframe_config < 0:
            raise ValueError("subframe_config (T_srs) must be non-negative")
        if self.b_hop < 0:
            raise ValueError("b_hop must be non-negative")
        if self.srs_bandwidth < 0:
            raise ValueError("srs_bandwidth (N_b) must be non-negative")
        if self.n_ul_rb <= 0:
            raise ValueError("n_ul_rb must be positive")


@dataclass(frozen=True)
class HoppingState:
    """Container for group/sequence hopping intermediate values."""

    group_number: int
    sequence_number: int
    f_gh: int
    f_ss: int


@dataclass(frozen=True)
class MappingInfo:
    """Metadata describing how an SRS sequence was mapped."""

    subframe_index: int
    slot_index: int
    root_index: int
    alpha: float
    m_sc: int
    comb: int
    n_fft: int
    k0: int
    hopping: HoppingState

    def summary(self) -> str:
        return (
            f"subframe={self.subframe_index} slot={self.slot_index} root={self.root_index} "
            f"alpha={self.alpha:.3f} M_sc={self.m_sc} comb={self.comb} k0={self.k0}"
        )


__all__ = ["SRSConfig", "HoppingState", "MappingInfo"]
