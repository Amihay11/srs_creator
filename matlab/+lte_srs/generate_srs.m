%% generate_srs.m — synthesize time-domain LTE SRS (TS 36.211 5.5.3)
%{
Produce one OFDM symbol containing the sounding reference signal for a
specified subframe following 3GPP TS 36.211 §5.5.3. The function ties
together hopping selection, Zadoff–Chu generation, cyclic shift, comb
placement, and IFFT synthesis, returning both the complex symbol and
metadata describing the intermediate parameters.

Inputs
-----
* ``config`` — SRS configuration struct created by ``create_config``.
* ``subframe_index`` — zero-based subframe number within a radio frame.
* ``n_fft`` (optional) — FFT size used for OFDM synthesis; defaults to 2048
  for a 20 MHz LTE system.

Outputs
------
* ``time_signal`` — column vector of length ``n_fft`` containing the SRS
  OFDM symbol in the time domain.
* ``info`` — struct with fields ``subframe_index``, ``slot_index``,
  ``root_index``, ``alpha``, ``m_sc``, ``comb``, ``n_fft``, ``k0``, and
  ``hopping`` capturing the configuration and mapping decisions.

Computation details
-------------------
1. Subframe gating uses ``is_active_subframe`` to enforce the periodicity
   :math:`T_{SRS}` from Table 5.5.3.3-1; inactive subframes raise an error.
2. Slot indexing doubles the subframe number, then ``group_and_sequence_hopping``
   derives the root sequence index :math:`u` (and group/sequence hop values)
   per §5.5.3.1.3/1.4.
3. ``zc_length`` selects :math:`N_{ZC}` (839 or 140 depending on bandwidth),
   and ``generate_zadoff_chu`` produces the base sequence :math:`r_u(n)`.
4. The bandwidth :math:`M_{sc}` from ``bandwidth_in_subcarriers`` trims the
   base sequence; ``apply_cyclic_shift`` rotates by :math:`\alpha` to create
   orthogonal variants (Table 5.5.3.2-1).
5. ``map_to_frequency_grid`` interleaves the tones with comb spacing
   :math:`K_{TC}` and offset :math:`k_0` into an ``n_fft`` grid. Finally,
   ``ifft`` converts the sparse frequency grid into the time-domain symbol.
%}

function [time_signal, info] = generate_srs(config, subframe_index, n_fft)
    if nargin < 3
        n_fft = 2048;
    end

    if ~lte_srs.is_active_subframe(config, subframe_index)
        error('Subframe %d is not active for this UE (T_srs=%d).', subframe_index, config.subframe_config);
    end

    slot_index = subframe_index * 2;
    hopping = lte_srs.group_and_sequence_hopping(config, slot_index);
    root_index = hopping.sequence_number;

    N_zc = lte_srs.zc_length(config);
    base_seq = lte_srs.generate_zadoff_chu(root_index, N_zc);

    m_sc = lte_srs.bandwidth_in_subcarriers(config);
    truncated_seq = base_seq(1:m_sc);
    shifted_seq = lte_srs.apply_cyclic_shift(truncated_seq, lte_srs.alpha(config));

    [freq_grid, k0] = lte_srs.map_to_frequency_grid(shifted_seq, config, n_fft);
    time_signal = ifft(freq_grid);

    info = struct('subframe_index', subframe_index, ...
        'slot_index', slot_index, ...
        'root_index', root_index, ...
        'alpha', lte_srs.alpha(config), ...
        'm_sc', m_sc, ...
        'comb', config.transmission_comb, ...
        'n_fft', n_fft, ...
        'k0', k0, ...
        'hopping', hopping);
end
