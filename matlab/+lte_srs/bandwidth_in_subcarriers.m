function m_sc = bandwidth_in_subcarriers(config)
%BANDWIDTH_IN_SUBCARRIERS Compute the number of SRS subcarriers.
    scaling = 2 ^ max(config.bandwidth_config, 0);
    raw = (config.srs_bandwidth + 1) * 12 * scaling;
    max_sc = config.n_ul_rb * 12;
    m_sc = min(raw, max_sc);
    m_sc = floor(double(m_sc));
end
