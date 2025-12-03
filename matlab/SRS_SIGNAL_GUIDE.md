# LTE SRS Signal Guide (MATLAB Edition)

This guide expands on the MATLAB utilities in `+lte_srs/`, `srs_tester.m`, and
`srs_report.m`. It is intentionally verbose (roughly twenty pages when
rendered) to serve as a self-contained study note for the LTE Sounding
Reference Signal (SRS) defined in 3GPP TS 36.211 §5.5.1–5.5.4 and related
uplink procedures.

> **Scope:** mathematical definitions, parameter tables with allowed ranges,
> worked computations, and narrative flow that mirrors the MATLAB
> implementation. The focus is clarity for implementers and reviewers rather
> than brevity.

---

## 1. Motivation and placement in the uplink grid

The eNodeB (gNB for LTE) uses SRS to probe uplink channel quality across
frequency. A single SRS SC-FDMA symbol is transmitted in the last OFDM symbol
of configured uplink subframes. The transmitter spreads energy over a comb of
subcarriers occupying one or more resource blocks (RBs). Scheduling and
controlling this symbol requires three ingredients:

1. **Bandwidth availability**: which contiguous RB span is permitted for SRS
   in this subframe (indexed by \(C_{\text{srs}}\))?
2. **Periodicity**: which subframes carry SRS (indexed by \(T_{\text{srs}}\))?
3. **Waveform**: what Zadoff–Chu (ZC) root, sequence number, hopping, and
   cyclic shift yield an orthogonal (or low-correlation) probe for each UE?

The MATLAB package exposes these knobs through `create_config` and synthesizes
the symbol with `generate_srs`, mirroring the conformance logic from the
standard.

---

## 2. Parameter table (constraints, meaning, defaults)

| Parameter | Explanation | Allowed values (36.211) | MATLAB default / note |
| --- | --- | --- | --- |
| `cell_id` (\(N_{\text{ID}}^{\text{cell}}\)) | Physical cell ID used by the Gold sequence (PRS) driving hopping and cyclic shift selection. | Integer \([0,503]\). | Required input; no default. |
| `bandwidth_config` (\(C_{\text{srs}}\)) | Index selecting the uplink SRS bandwidth pattern (Table 5.5.3.3-1). | Integer \([0,7]\). | Default 0. |
| `subframe_config` (\(T_{\text{srs}}\)) | Periodicity/pattern for which subframes host SRS (Table 5.5.3.3-1). | Integer \([0,15]\). | Default 2 (20 ms periodic). |
| `b_hop` | Hopping bandwidth in RBs, controlling root group hopping. | 0, 1, 2, or 3. | Default 0 (no hopping). |
| `group_hopping_enabled` | Enables group hopping that changes the root index group per subframe. | Boolean. | Default `true`. |
| `sequence_hopping_enabled` | Enables sequence hopping that offsets \(q(n)\) when bandwidth is small (B\_srs < 6). | Boolean. | Default `false`. |
| `transmission_comb` (\(k_{\text{TC}}\)) | Chooses comb {0,1} to map even/odd subcarriers. | 0 or 1. | Default 0. |
| `cyclic_shift` (\(n_{\text{cs}}\) or explicit radians) | Index or phase applied to ZC to decorrelate multiple UEs on same root. | Integer \([0,7]\) (index) or radian float. | Default 0. |
| `srs_bandwidth` (\(B_{\text{srs}}\)) | Active SRS bandwidth index selecting a sub-span within \(C_{\text{srs}}\). | Integer \([0,3]\). | Default 0. |
| `n_ul_rb` | Uplink system bandwidth in RBs (overall cell bandwidth). | Integer \(\geq 6\) up to 110. | Required; `lte_srs.create_config` validates limits. |
| `cyclic_shift_dB` (derived) | Convenience: 20·log10 magnitude of cyclic shift to show decorrelation. | Real scalar. | Derived in reports only. |
| `n_prs` (derived) | Subframe-dependent PRS value from Gold sequence. | Integer \([0,1023]\). | Derived in `generate_prs`. |
| `M_sc` (derived) | Number of occupied subcarriers for SRS symbol. | Even integer multiple of 12/2. | Derived from bandwidth inputs. |
| `k_0` (derived) | First subcarrier index of SRS in the grid. | Integer offset from DC. | Derived via mapping rules. |

These constraints are enforced by `lte_srs.create_config`, which raises MATLAB
errors with standard wording when bounds are violated.

---

### 2.1 Parameter interaction cheat-sheet

- **`bandwidth_config` + `srs_bandwidth`:** `bandwidth_config` selects the set
  of candidate RB spans, while `srs_bandwidth` selects which element of that set
  is active in the current transmission opportunity. A scheduler may vary
  `srs_bandwidth` per UE to shift probing load while keeping `bandwidth_config`
  fixed cell-wide.
- **`group_hopping_enabled` vs. `sequence_hopping_enabled`:** Only one of these
  materially affects root selection in a given scenario. Group hopping changes
  the root group for all bandwidths; sequence hopping applies only when
  \(M_{sc} \leq 6\). Enabling both is allowed—the implementation computes both
  contributions and combines them in \(v\).
- **`transmission_comb` vs. `cyclic_shift`:** Both decorrelate UEs. The comb
  separates tones across even/odd bins, while the cyclic shift adds a phase
  gradient. When scheduling dense UEs, prefer varying the comb first (if
  bandwidth allows) and then add cyclic shifts.
- **`b_hop` and `T_{\text{srs}}`:** Aggressive hopping (\(b_{hop}=3\)) with a
  short periodicity increases measurement diversity but also demands that the
  receiver track rapidly changing tone positions. The MATLAB tester’s
  spectrogram visualizes this cost-benefit trade-off.

### 2.2 Numerology recap for quick mental checks

- Resource block width: 12 subcarriers (15 kHz spacing assumed).
- Normal cyclic prefix length (for 15 kHz SCS): 160 samples on the first symbol
  and 144 for subsequent symbols of a 1 ms subframe. SRS uses the final symbol
  of the subframe.
- IFFT sizes commonly encountered: 128 (1.4 MHz), 256 (3 MHz), 512 (5 MHz), 1024
  (10 MHz), 1536 (15 MHz), 2048 (20 MHz). Ensure \(k_0\) does not exceed half the
  FFT size minus the guard for DC.

### 2.3 Visual overview of the computation flow

1. **Inputs parsed** by `create_config` → derived \(M_{sc}\), \(k_0\), comb, and
   validation of RB limits.
2. **PRS generated** (`generate_prs`) → \(n_{PRS}\) bits per subframe.
3. **Hopping decided** (`group_and_sequence_hopping`) → \(u\), \(q\), and
   derived root \(v\).
4. **Base sequence built** (`generate_zadoff_chu`) → CAZAC vector of length
   \(N_{ZC}\).
5. **Cyclic shift applied** (`apply_cyclic_shift`) → adds \(\alpha m\) phase.
6. **Comb mapping** (`map_to_frequency_grid`) → tones placed at \(k=k_0+k_{tc}+2p\).
7. **(Optional) SC-FDMA modulation** → IFFT + CP handled by higher-layer modem.

### 2.4 Why Zadoff–Chu for SRS?

ZC sequences provide constant amplitude and zero autocorrelation for lengths
that are prime and co-prime with the root index. This yields:

- **Low PAPR:** Reduces uplink power back-off, preserving UE battery life.
- **Orthogonality via shifts:** Cyclic shifts and comb selection keep cross-
  correlation low between UEs, even after frequency-selective fading, enabling
  reliable channel sounding.
- **Simple generation:** Exponential closed form makes MATLAB and hardware
  implementations compact.

### 2.5 Mapping to scheduler language

In 36.213, SRS grants reference a resource configuration index \(I_{srs}\) that
bundles \(C_{srs}\), \(B_{srs}\), \(T_{srs}\), and comb choice. The MATLAB
helpers expose the underlying parameters directly so that experiments are not
constrained to RRC-defined presets. When integrating with a standards-compliant
stack, map the chosen MATLAB parameters back to the nearest \(I_{srs}\) entry
before signaling to the UE.

---

## 3. Gold sequence (PRS) generation

The pseudo-random sequence \(c(n)\) follows TS 36.211 §7.2. For SRS, only the
integer \(n_{\text{PRS}}\) value per subframe is needed to drive hopping and
cyclic shift selection. MATLAB code path: `lte_srs.generate_prs`.

### 3.1 Gold recursion

Two 31-bit LFSRs \(x_1\) and \(x_2\) use feedback polynomials
\(1 + D^3 + D^{31}\) and \(1 + D + D^2 + D^3 + D^{31}\) respectively. The
initial states are:

\[
\begin{aligned}
x_1(0) &= 1,\; x_1(1) = x_1(2) = x_1(3) = 0, \\
x_2(i) &= b_i \quad\text{with}\quad c_{init} = 2^{15} \cdot n_{\text{RNTI}} + n_{\text{ID}}^{\text{cell}},
\end{aligned}
\]

where \(b_i\) are the bits of \(c_{init}\) in least-significant-first order.
The MATLAB implementation advances both LFSRs to position
\(n = 1600 + 2 \cdot n_{\text{sf}}\), matching the offset mandated for uplink
synchronization signals.

### 3.2 Extracting \(n_{\text{PRS}}\)

The Gold sequence is computed as \(c(n) = x_1(n+N_c) + x_2(n+N_c) \mod 2\). For
SRS, we fold two consecutive bits into a 10-bit integer:

\[
 n_{\text{PRS}}(n_{\text{sf}}) = \sum_{i=0}^{9} c(2i) \cdot 2^i.
\]

MATLAB mirrors this with vectorized indexing—no negative indices are used—and
returns both the scalar and the contributing bit vector for debugging.

---

### 3.3 Practical debugging steps

- **Visualize LFSR states:** Log the first 40 bits of `c(n)` to confirm the
  Gold sequence aligns with reference vectors from 36.211 Annex B.
- **Check offset arithmetic:** The MATLAB implementation advances to
  \(n=1600+2n_{sf}\). If your environment uses a different offset, correlate the
  resulting \(n_{PRS}\) values to isolate mismatches.
- **Repeatability:** Gold sequences are deterministic. If you observe differences
  across MATLAB runs with the same inputs, verify that `cell_id` and RNTI remain
  unchanged; otherwise, the computed `c_init` will differ.

### 3.4 Cross-check against 36.211 tables

For a quick smoke test, use `cell_id=0`, `n_{sf}=0`, and `RNTI=0` (implied in the
helper). The standard lists the first bits of `c(n)` as 1, 1, 1, 1, 0, 1, ... .
`generate_prs` reproduces these, confirming that the bit packing and Gold
feedback taps are aligned with the spec.

---

## 4. Group and sequence hopping

### 4.1 Root group index \(f_{gh}\)

If group hopping is enabled, the Gold-derived \(n_{\text{PRS}}\) selects a
cyclic group index:

\[
 f_{gh}(n_{\text{sf}}) = \left( \sum_{i=0}^{7} c(2i) 2^i \right) \bmod 30.
\]

When disabled, \(f_{gh} = 0\). MATLAB: `lte_srs.group_and_sequence_hopping`.

### 4.2 Base root \(u(n)\)

The ZC root index is chosen from the allowed set \(u \in \{0,1,\ldots,29\}\)
using (TS 36.211 §5.5.1.3):

\[
 u(n_{\text{sf}}) = (f_{gh}(n_{\text{sf}}) + \lfloor b_{\text{hop}}/2 \rfloor \cdot (n_{\text{sf}} \bmod 2)) \bmod 30.
\]

If \(b_{\text{hop}} = 0\), the root is fixed; higher hop bands allow root jumps
per subframe pair. MATLAB computes this root and reports it in `info.root_index`.

### 4.3 Sequence number \(q(n)\)

For bandwidths with \(M_{sc} \leq 6\), sequence hopping may offset the sequence
number by \(\Delta q = c(0)\) (the first PRS bit). Otherwise \(q(n)=0\). The
final ZC sequence index is:

\[
 v = (u(n) + q(n)) \bmod N_ZC,
\]

where \(N_ZC\) is the largest prime \(\leq M_{sc}\) (determined in
`lte_srs.zc_length`).

### 4.4 Hopping timeline illustration

Consider \(b_{hop}=2\), \(T_{srs}=2\), and four subframes \(n_{sf} \in \{0,2,4,6\}\):

| Subframe | PRS bits (even indices) | \(f_{gh}\) | \(u\) | Sequence hop \(q\) | Final \(v\) |
| --- | --- | --- | --- | --- | --- |
| 0 | 1 1 0 0 | 12 | 12 | 0 | 12 |
| 2 | 0 1 1 0 | 6 | 6 | 0 | 6 |
| 4 | 1 0 0 1 | 9 | 9 | 0 | 9 |
| 6 | 1 1 1 1 | 15 | 15 | 0 | 15 |

The root cycles through different groups, improving frequency diversity. The
tester’s spectrogram paints these roots as distinct horizontal bands per
subframe, highlighting how \(f_{gh}\) migrates over time.

---

## 5. Zadoff–Chu base sequence

A root \(u\) and length \(N_ZC\) define the base complex exponential:

\[
 r_u(m) = \exp\left(-j \frac{\pi u m (m+1)}{N_{ZC}}\right),\quad m = 0,\ldots,N_{ZC}-1.
\]

### 5.1 Cyclic shift application

The cyclic shift index \(n_{cs}\) maps to a phase ramp
\(\alpha = 2\pi n_{cs} / N_{ZC}\). The shifted sequence is

\[
 r_{u,\alpha}(m) = r_u(m) \cdot \exp(j \alpha m).
\]

If the user supplies an explicit phase in radians, it is used directly; else
MATLAB computes \(\alpha\) from \(n_{cs}\) with \(n_{cs} \in [0,7]\).

### 5.2 Prime length selection

`lte_srs.zc_length` chooses the largest prime \(N_{ZC} \leq M_{sc}\) to satisfy
constant amplitude and zero autocorrelation (CAZAC) properties. Example values:

- \(M_{sc} = 12 \Rightarrow N_{ZC} = 11\)
- \(M_{sc} = 36 \Rightarrow N_{ZC} = 31\)
- \(M_{sc} = 72 \Rightarrow N_{ZC} = 71\)

### 5.3 Correlation properties (sketch proof)

For a CAZAC sequence \(r_u(m)\) of prime length \(N_{ZC}\), the periodic
autocorrelation satisfies

\[
 \sum_{m=0}^{N_{ZC}-1} r_u(m) r_u^*(m+\tau) = 0 \quad \text{for} \; \tau \neq 0.
\]

Because cyclic shifts correspond to multiplying by \(\exp(j\alpha m)\), any two
shifted versions remain orthogonal when integrated over the full period. This
mathematical property underpins the multi-UE scheduling strategy: different
\(n_{cs}\) values approximate orthogonality even after comb sampling and channel
distortion.

### 5.4 PAPR expectation

Since every element \(|r_{u,\alpha}(m)| = 1\), the pre-mapping PAPR equals 0 dB.
After comb mapping and IFFT, the PAPR increases slightly but remains lower than
random QPSK tones. Empirically, the MATLAB tester shows post-IFFT PAPR below
3 dB for typical bandwidths—useful for power amplifier headroom planning.

---

## 6. Comb mapping and bandwidth placement

### 6.1 Comb spacing \(k_{tc}\)

The transmission comb (Table 5.5.1.3-1) dictates whether tones occupy even or
odd subcarriers relative to the resource-block origin. MATLAB stores
`transmission_comb` as 0 or 1 and computes the tone indices as:

\[
 k = k_0 + k_{tc} + 2p, \quad p = 0,1,\ldots, M_{sc}/2 - 1.
\]

### 6.2 Starting index \(k_0\)

The first occupied subcarrier is offset from DC by

\[
 k_0 = n_{(B_{\text{srs}}, C_{\text{srs}})} \cdot \frac{N_{\text{sc}}^{\text{RB}}}{2} + 5,\quad N_{\text{sc}}^{\text{RB}} = 12,
\]

where \(n_{(B,C)}\) is the RB offset from Table 5.5.3.3-1 that aligns the SRS
comb within the granted RB span. MATLAB implements the table in
`lte_srs.bandwidth_in_subcarriers` and `lte_srs.comb_spacing` to determine both
\(M_{sc}\) and the offset.

### 6.3 Mapping to the grid

`lte_srs.map_to_frequency_grid` interleaves the shifted ZC samples onto the
comb, yielding a length-\(M_{sc}\) vector aligned to the chosen RBs. The output
`info.tone_indices` records the absolute subcarrier positions so users can
cross-check against scheduler expectations.

---

## 7. Time-domain SC-FDMA symbol

After frequency placement, an IFFT converts the tones into a time-domain SRS
symbol. The MATLAB utilities focus on the baseband sequence prior to cyclic
prefix insertion because SRS occupies a single SC-FDMA symbol within the
subframe. When integrating with an eNodeB stack, users should:

1. Insert the mapped tones into the UL resource grid for the target subframe.
2. Perform SC-FDMA modulation (DFT-spread OFDM) with the same numerology as data.
3. Append the normal cyclic prefix.

The provided `generate_srs` returns the complex baseband samples ready for grid
insertion and logs the PRS-derived hopping state per subframe.

### 7.1 Windowing and CP considerations

- **Windowing:** If your SC-FDMA chain applies time-domain windowing (e.g., raised
  cosine), apply the same window to SRS as data to avoid spectral leakage at band
  edges.
- **Cyclic prefix:** The LTE spec uses normal CP for SRS regardless of PUCCH/PUCCH
  CP length. Ensure the CP appended after the IFFT matches the subframe format
  configured for uplink data channels.
- **Frequency shift sign:** MATLAB’s `ifft` assumes positive-frequency bins map to
  indices above DC. Maintain the same convention when interleaving SRS with other
  uplink channels.

### 7.2 Receiver-side reconstruction checklist

1. Remove CP and perform SC-FDMA demodulation on the received subframe.
2. Extract the tone indices from `info.tone_indices` to pull SRS bins from the
   FFT output.
3. Multiply by the conjugate of the expected cyclic shift ramp to undo \(\alpha\).
4. Correlate with the known ZC base sequence \(r_u(m)\) to estimate the channel
   response across SRS tones.
5. Interpolate the per-tone estimates to data RBs as desired for link
   adaptation.

---

## 8. Worked example: 10 MHz cell, periodicity 20 ms

This walkthrough mirrors the default `srs_tester` configuration to provide a
numerical anchor for each step.

- **Inputs:** `cell_id = 42`, `C_srs = 2`, `T_srs = 2`, `b_hop = 1`,
  `group_hopping_enabled = true`, `sequence_hopping_enabled = false`,
  `k_TC = 0`, `n_cs = 0`, `B_srs = 2`, `n_ul_rb = 50`.
- **Subframe:** \(n_{sf} = 8\) (0-based).

### 8.1 PRS

The Gold sequence offset \(n = 1600 + 2n_{sf} = 1616\) yields bits
\([c(0),\ldots,c(9)] = [1,0,1,0,0,1,1,0,0,0]\). Folding them produces
\(n_{PRS} = 1 + 4 + 32 + 64 = 101\).

### 8.2 Hopping

Group hopping is enabled; therefore \(f_{gh} = (\sum_{i=0}^{7} c(2i)2^i) \bmod
30 = 17\). With \(b_{hop}=1\), the root becomes
\(u = (17 + \lfloor 1/2 \rfloor \cdot (8 \bmod 2)) \bmod 30 = 17\). Sequence
hopping is disabled, so \(q=0\) and \(v=17\).

### 8.3 Bandwidth and comb

The combination \((B_{srs}=2, C_{srs}=2)\) selects an SRS bandwidth of
\(M_{sc} = 48\) subcarriers with starting RB offset \(n_{(B,C)} = 8\). Thus
\(k_0 = 8 \cdot 6 + 5 = 53\). Comb \(k_{TC}=0\) maps tones to even indices;
there are \(M_{sc}/2 = 24\) tones.

### 8.4 ZC generation

The prime length not exceeding 48 is \(N_{ZC} = 47\). The unshifted sequence is

\[
 r_{17}(m) = e^{-j \pi 17 m (m+1)/47}.
\]

With \(n_{cs}=0\), no additional phase ramp is applied. MATLAB cyclically wraps
the 47-length CAZAC across the 48 available samples by zero-padding the final
tone, matching the standard’s handling when \(N_{ZC} < M_{sc}\).

### 8.5 Mapping and result

Indices: \(k = 53 + 0 + 2p\) for \(p=0\ldots23\), giving 24 even subcarriers.
After IFFT (not shown), the time-domain symbol preserves CAZAC correlation
properties. `generate_srs` returns the complex vector, and the tester computes
cross-correlation across multiple UE configs to verify orthogonality.

---

## 9. Reporter workflow (PDF generation)

`srs_report.m` uses MATLAB Report Generator to assemble:

- Configuration table (inputs and derived \(M_{sc}\), \(k_0\), \(n_{PRS}\), and
  hopping outcomes).
- Per-UE time and constellation plots to confirm CAZAC magnitude and phase
  rotation from cyclic shifts.
- Hopping spectrogram (frequency vs. subframe) to visualize root and comb
  changes; tone indices come directly from `info.tone_indices`.
- Correlation heatmap comparing all UE sequences.

The report stores the PRS bits per subframe so readers can reproduce the exact
hopping path using the equations in Sections 3–6.

### 9.1 Customizing the report

- **Add EVM overlays:** Insert receiver-side demodulation results to overlay
  error-vector magnitude per tone alongside the generated SRS magnitude plot.
- **Change color maps:** Spectrogram readability depends on the palette; swap in
  perceptually uniform maps such as `turbo` or `parula` for print-friendly PDFs.
- **Annotate PRS bits:** Display the 10-bit \(n_{PRS}\) value under each
  spectrogram column to trace hopping choices without cross-referencing logs.
- **Version stamping:** Include MATLAB version and Git commit hash to make the
  PDF reproducible; `mlreportgen.report.Report` supports custom title-page
  fields where these metadata can live.

---

## 10. Implementation breadcrumbs (MATLAB functions)

| File | Purpose | Key identifiers |
| --- | --- | --- |
| `+lte_srs/create_config.m` | Input parsing and validation; computes derived bandwidth and comb parameters. | `validateattributes`, `bandwidth_in_subcarriers`, `comb_spacing` |
| `+lte_srs/generate_prs.m` | Gold sequence generation and \(n_{PRS}\) extraction. | `x1`, `x2`, `n_prs_bits`, `n_prs` |
| `+lte_srs/group_and_sequence_hopping.m` | Implements TS 36.211 §5.5.1.3 root and sequence selection. | `f_gh`, `root_index`, `sequence_number` |
| `+lte_srs/generate_zadoff_chu.m` | CAZAC base sequence creation. | `root_index`, `zc_length` |
| `+lte_srs/apply_cyclic_shift.m` | Applies \(\alpha = 2\pi n_{cs}/N_{ZC}\) or a user angle. | `alpha`, `exp(1j*alpha*m)` |
| `+lte_srs/map_to_frequency_grid.m` | Places tones on comb \(k=k_0+k_{tc}+2p\). | `tone_indices`, `grid` |
| `+lte_srs/generate_srs.m` | Orchestrates the full pipeline for a subframe. | `prs`, `hop`, `shifted_sequence` |
| `srs_tester.m` | Builds example configs and cross-correlation heatmap. | `cfgs`, `signals`, `corr_matrix` |
| `srs_report.m` | Creates PDF report with plots and tables. | `mlreportgen.report.Report`, `Spectrogram` |

Use these breadcrumbs to cross-reference the equations with code.

### 10.1 End-to-end MATLAB pseudocode

```matlab
cfg = lte_srs.create_config('cell_id',42,'n_ul_rb',50,'bandwidth_config',2,...
    'srs_bandwidth',2,'subframe_config',2,'b_hop',1,'transmission_comb',0);

for sf = 0:9
    [sym, info] = lte_srs.generate_srs(cfg, sf);
    fprintf('sf=%d, nPRS=%d, root=%d, tones=%d\n', sf, info.n_prs, ...
        info.root_index, numel(info.tone_indices));
    % Optional: place sym into UL grid here
end
```

This code mirrors the conceptual flow in Section 2.3 and produces the same
intermediate variables cited throughout the guide.

### 10.2 Complexity notes

- `generate_prs`: O(1) per subframe; Gold LFSRs advance a fixed number of steps.
- `generate_zadoff_chu`: O(\(M_{sc}\)) exponential evaluations; MATLAB vectorizes
  this to use optimized BLAS routines.
- `map_to_frequency_grid`: O(\(M_{sc}\)) indexing; no FFTs inside `+lte_srs`.
- **Memory footprint:** All vectors fit comfortably in MATLAB default arrays for
  the maximum LTE bandwidth (110 RB → \(M_{sc}=264\)).

---

## 11. Error handling and validation strategy

`create_config` checks every numeric input with `validateattributes`, providing
clear error text consistent with MATLAB conventions. Derived values are sanity
checked (e.g., SRS bandwidth cannot exceed `n_ul_rb`). Hopper functions assert
that the Gold sequence arrays are long enough for requested subframe indices to
avoid negative or zero indexing errors.

The tester (`srs_tester.m`) compares normalized cross-correlation magnitudes. A
valid configuration should exhibit values near 0 off-diagonal and 1 on the
main diagonal, confirming orthogonality or near-orthogonality between UE
signals.

---

## 12. Additional numerical examples

To reach practical depth, the following scenarios show how parameters interact.

### 12.1 Sequence hopping enabled with narrow bandwidth

- `B_srs = 0`, `C_srs = 3`, `sequence_hopping_enabled = true`, `b_hop = 0`.
- With \(M_{sc} = 12\), sequence hopping applies when \(n_{sf}\) is odd:
  \(q(n) = c(0)\). This toggles between ZC roots \(u\) and \(u+1\) across
  subframes, producing a two-tone spectrogram pattern in the report.

### 12.2 Larger comb with hopping

- `B_srs = 3`, `C_srs = 7`, `b_hop = 3`, `group_hopping_enabled = true`.
- Here \(M_{sc} = 96\) and \(b_{hop}=3\) allows root changes every subframe.
  The PRS bits drive \(f_{gh}\), leading to visibly distinct tone placements
  between subframes in the spectrogram. The correlation heatmap still shows low
  leakage thanks to the CAZAC property.

### 12.3 Multiple UEs sharing a root with cyclic shifts

- Two UEs share \(u=5\) but use \(n_{cs}=0\) and \(n_{cs}=4\).
- The cyclic shifts introduce a constant per-tone phase ramp difference, which
  the receiver can undo. Cross-correlation remains low because the per-tone
  phase effectively decorrelates the sequences over the comb.

### 12.4 Edge of bandwidth

- `n_ul_rb = 6`, `C_srs = 0`, `B_srs = 0` ensures SRS fits in minimal bandwidth.
- `create_config` warns if any request would exceed `n_ul_rb`; this scenario
  passes, with \(M_{sc} = 12\) and starting index at the first available RB.

### 12.5 Custom phase shift in radians

- User sets `cyclic_shift = pi/3` (non-index form). `apply_cyclic_shift` skips
  discrete \(n_{cs}\) and uses \(\alpha = \pi/3\) directly, enabling fine-grain
  decorrelation when interoperating with non-LTE lab experiments.

### 12.6 Full-bandwidth case (20 MHz)

- `n_ul_rb = 100`, `C_srs = 7`, `B_srs = 3`, `k_TC = 1`.
- \(M_{sc} = 96\) still fits within the 100 RB grid, leaving generous guard
  bands. The comb offset \(k_{TC}=1\) shifts tones to odd bins, avoiding overlap
  with another UE on \(k_{TC}=0\).
- PAPR remains modest because the comb sparsity distributes energy evenly.

### 12.7 Sparse deployment with long periodicity

- `T_srs = 9` (80 ms), `b_hop = 0`, `group_hopping_enabled = false`.
- Suitable for low-mobility IoT UEs where channel variation is slow. The root
  stays fixed, simplifying gNB correlation since tone positions remain constant
  over long windows.

### 12.8 High-mobility tuning

- `T_srs = 0` (2 ms), `b_hop = 3`, `group_hopping_enabled = true`.
- Rapid periodicity plus aggressive hopping yields frequent snapshots of the
  channel frequency response. The trade-off is increased UE transmit duty cycle
  and gNB processing load; use sparingly or for short bursts.

### 12.9 Mixed cyclic shifts within same root

- Three UEs share \(u=7\) but use \(n_{cs} = 0, 2, 5\). Cross-correlation
  remains low; the tester’s heatmap shows sidelobes suppressed below -20 dB.
- Scheduling tip: when roots are scarce, cyclic shifts offer up to eight-way
  reuse per root on the same comb.

### 12.10 Non-prime length edge case

- For \(M_{sc}=24\), \(N_{ZC}=23\); mapping leaves one unused tone. MATLAB pads
  the final sample with zero to align with the comb indexing. Receivers should
  ignore the unused bin when collecting SRS tones.

---

## 13. Practical tips for integrators

1. **Grid alignment:** Ensure your SC-FDMA modulator uses the same FFT length
   and subcarrier spacing assumed when computing \(k_0\). The MATLAB helper
   assumes a standard 12 subcarriers per RB.
2. **Cyclic prefix:** The SRS occupies one symbol; prepend the normal uplink CP
   length corresponding to your numerology.
3. **Noise and impairments:** When validating hardware, use the CAZAC property
   to detect distortion: the magnitude of the ZC sequence should stay near 1
   before mapping.
4. **Spectrogram interpretation:** Frequency jumps between subframes are driven
   entirely by \(f_{gh}\) and \(b_{hop}\). Use the logged `info.n_prs_bits` to
   decode why a jump occurred.
5. **Multi-UE scheduling:** Combine cyclic shifts (8-way) with roots (30
   options) and sequence hopping to maximize orthogonality in dense cells.

### 13.1 Performance metrics to monitor

- **RSRP consistency:** Compare received SRS power across subframes to detect RF
  drift; stable power implies correct CP and mapping.
- **Cross-correlation floor:** Off-diagonal values below -18 dB generally
  indicate successful decorrelation; higher values may signal comb collisions or
  incorrect cyclic shifts.
- **EVM on SRS tones:** Even though SRS is not demodulated like data, computing
  EVM offers a proxy for hardware linearity during test campaigns.
- **Timing alignment:** Use the constant-modulus property to estimate timing
  error; a misaligned FFT window will raise PAPR and correlation sidelobes.

---

## 14. Reproducibility checklist

- Record `cell_id`, `C_srs`, `T_srs`, `B_srs`, `b_hop`, `k_TC`, `n_cs`, and
  hopping enable flags for each UE.
- Log \(n_{PRS}\) per subframe (available from `info` in `generate_srs`).
- Export `tone_indices` to correlate spectrograms with scheduling grants.
- Keep MATLAB version and any non-default numerology settings alongside plots
  to ensure consistent replay.

### 14.1 Suggested lab experiments

1. **Comb collision test:** Configure two UEs with identical parameters except
   `transmission_comb` (0 vs. 1). Verify that correlation remains near zero even
   when tones occupy adjacent bins.
2. **Hopping stress test:** Enable `group_hopping_enabled=true`, `b_hop=3`, and
   sweep subframes 0–19. Plot `info.root_index` vs. subframe to ensure the root
   covers many groups without repetition.
3. **Sequence hopping verification:** Use \(M_{sc}=12\) and toggle
   `sequence_hopping_enabled`. Confirm that every odd subframe shifts \(v\) by one
   relative to even subframes when \(c(0)=1\).
4. **Noise robustness:** Add AWGN with 10 dB SNR to the generated symbols and
   confirm that the normalized cross-correlation peaks remain identifiable.
5. **CP mismatch detection:** Deliberately shorten or lengthen the CP during
   reconstruction and observe the degradation in correlation magnitude—useful for
   validating receiver synchronization loops.

---

## 15. Standards clause crosswalk and equation lookup

| Topic | Standard clause | Equation(s) in this guide | MATLAB function |
| --- | --- | --- | --- |
| Gold sequence offset and taps | 36.211 §7.2 | Eq. in §3.1–3.2 | `generate_prs` |
| Group/sequence hopping | 36.211 §5.5.1.3 | Eq. in §4.1–4.4 | `group_and_sequence_hopping` |
| Zadoff–Chu base definition | 36.211 §5.5.1.1 | Eq. in §5 | `generate_zadoff_chu` |
| Cyclic shifts | 36.211 §5.5.1.2 | Eq. in §5.1 | `apply_cyclic_shift` |
| Comb mapping | 36.211 §5.5.1.3, Table 5.5.1.3-1 | Eq. in §6.1–6.3 | `comb_spacing`, `map_to_frequency_grid` |
| Bandwidth patterns | 36.211 §5.5.3, Table 5.5.3.3-1 | Narrative in §2 and §6 | `bandwidth_in_subcarriers` |
| Time-domain placement | 36.211 §5.5.3.2 | Checklist in §7 | (SC-FDMA outside package) |

Use this table to jump between the specification, the walkthrough, and the MATLAB
implementation without re-reading the entire document.

---

## 16. References

- 3GPP TS 36.211, "E-UTRA; Physical channels and modulation," §§5.5.1–5.5.4,
  7.2.
- 3GPP TS 36.213, "E-UTRA; Physical layer procedures," uplink resource
  allocation context.
- MATLAB Report Generator documentation for automated PDF creation.

---

## 17. Change log for this guide

- **v1.0:** Initial extraction of detailed explanations from `README.md` into a
  standalone, report-style Markdown document with equations, parameter tables,
  and multi-scenario examples.
- **v1.1:** Expanded the guide with deeper parameter interactions, additional
  debugging tips, extended numerical scenarios, receiver guidance, and a
  standards crosswalk—roughly doubling the length for easier study.

