function [time_signal, info] = generate_srs(config, subframe_index, n_fft)
%GENERATE_SRS Generate the time-domain LTE SRS for a given subframe.
%   [SIGNAL, INFO] = GENERATE_SRS(CONFIG, SUBFRAME_INDEX, N_FFT) returns one
%   OFDM symbol worth of SRS along with metadata describing the mapping.
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
