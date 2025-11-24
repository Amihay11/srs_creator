"""Test and visualization harness for LTE SRS generation."""
from __future__ import annotations

import itertools
from dataclasses import dataclass
from typing import Iterable, List, Tuple

import importlib.util
import numpy as np

from lte_srs import (
    MappingInfo,
    SRSConfig,
    generate_srs,
    normalized_cross_correlation,
)


@dataclass
class SRSResult:
    signal: np.ndarray
    info: MappingInfo


def build_configurations() -> List[SRSConfig]:
    """Create a small suite of diverse SRS configurations for testing."""

    common = dict(bandwidth_config=2, subframe_config=2, b_hop=1, n_ul_rb=50)
    return [
        SRSConfig(
            cell_id=cell,
            group_hopping_enabled=gh,
            sequence_hopping_enabled=sh,
            transmission_comb=comb,
            cyclic_shift=alpha,
            srs_bandwidth=n_b,
            **common,
        )
        for cell, gh, sh, comb, alpha, n_b in [
            (0, True, False, 0, 0.0, 0),
            (1, True, True, 1, np.pi / 4, 1),
            (12, False, True, 0, np.pi / 2, 2),
            (37, False, False, 1, 3 * np.pi / 4, 3),
        ]
    ]


def generate_signals(configs: Iterable[SRSConfig], subframe: int) -> List[SRSResult]:
    results: List[SRSResult] = []
    for cfg in configs:
        sig, info = generate_srs(cfg, subframe)
        results.append(SRSResult(signal=sig, info=info))
    return results


def correlation_matrix(results: List[SRSResult]) -> np.ndarray:
    """Compute the normalized correlation matrix for a set of signals."""

    n = len(results)
    corr = np.zeros((n, n))
    for i, j in itertools.product(range(n), repeat=2):
        corr[i, j] = normalized_cross_correlation(results[i].signal, results[j].signal)
    return corr


def highlight_pairs(corr: np.ndarray, threshold: float = 0.3) -> List[Tuple[int, int, float]]:
    """Return pairs with correlation magnitude above a threshold."""

    pairs: List[Tuple[int, int, float]] = []
    n = corr.shape[0]
    for i in range(n):
        for j in range(i + 1, n):
            if corr[i, j] > threshold:
                pairs.append((i, j, corr[i, j]))
    return pairs


def plot_correlation(corr: np.ndarray, labels: List[str], path: str = "correlation_matrix.png") -> str:
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(6, 5))
    im = ax.imshow(corr, vmin=0, vmax=1, cmap="viridis")
    ax.set_xticks(range(len(labels)))
    ax.set_yticks(range(len(labels)))
    ax.set_xticklabels(labels)
    ax.set_yticklabels(labels)
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right")
    ax.set_title("Normalized SRS Cross-Correlation")
    fig.colorbar(im, ax=ax, label="|corr|")
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return path


def has_matplotlib() -> bool:
    return importlib.util.find_spec("matplotlib") is not None


def main() -> None:
    configs = build_configurations()
    subframe = 4
    print(f"Generating SRS for subframe {subframe}\n")
    for cfg in configs:
        print(cfg)

    results = generate_signals(configs, subframe)
    labels = [f"UE{i}" for i in range(len(results))]
    corr = correlation_matrix(results)
    pairs = highlight_pairs(corr)

    print("\nCorrelation matrix (magnitude):")
    with np.printoptions(precision=3, suppress=True):
        print(corr)

    if pairs:
        print("\nHighly correlated pairs (>0.3):")
        for i, j, v in pairs:
            print(f"  {labels[i]} vs {labels[j]}: {v:.3f}")
    else:
        print("\nNo highly correlated pairs detected.")

    if has_matplotlib():
        plot_path = plot_correlation(corr, labels)
        print(f"Correlation heatmap saved to {plot_path}")
    else:
        print("Matplotlib is not available; skipping heatmap rendering.")


if __name__ == "__main__":
    main()
