function [freq_grid, k0] = map_to_frequency_grid(seq, config, n_fft)
%MAP_TO_FREQUENCY_GRID Map an SRS sequence to a frequency grid.
%   Returns the IFFT-ready grid and the comb starting index k0 (0-based).
    grid_shifted = zeros(n_fft, 1);
    spacing = lte_srs.comb_spacing(config);
    center = floor(n_fft / 2);
    m_sc = numel(seq);
    k0 = center - floor(m_sc / 2) * spacing + config.transmission_comb;
    for m = 0:m_sc-1
        k = k0 + m * spacing;
        if k >= 0 && k < n_fft
            grid_shifted(k + 1) = seq(m + 1);
        end
    end
    freq_grid = ifftshift(grid_shifted);
end
