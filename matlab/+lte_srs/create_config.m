function config = create_config(varargin)
%CREATE_CONFIG Build and validate an LTE SRS configuration structure.
%   CONFIG = CREATE_CONFIG('Name', Value, ...) returns a struct with the
%   parameters required by the LTE SRS generation routines. The fields map
%   closely to the Python SRSConfig dataclass for easy cross-language use.
%
%   Required name-value pairs:
%     'cell_id'                   Physical cell identity (0..503)
%     'bandwidth_config'          B_srs index (>=0)
%     'subframe_config'           T_srs periodicity (>=0; 0 disables SRS)
%     'b_hop'                     Frequency hopping parameter (>=0)
%     'group_hopping_enabled'     Logical flag
%     'sequence_hopping_enabled'  Logical flag
%     'transmission_comb'         k_tc (0 or 1)
%     'cyclic_shift'              Alpha in radians
%     'srs_bandwidth'             N_b (>=0)
%     'n_ul_rb'                   Number of UL RBs (>0)
%
%   Optional:
%     'n_zc'                      Custom Zadoff-Chu length; defaults to 839
%
%   The function performs lightweight validation and mirrors the helper
%   methods available in the Python implementation via additional helper
%   functions in the +lte_srs package.

if mod(numel(varargin), 2) ~= 0
    error('Arguments must be provided as name/value pairs.');
end

pairs = reshape(varargin, 2, []);
config = struct();
for idx = 1:size(pairs, 2)
    name = pairs{1, idx};
    value = pairs{2, idx};
    config.(name) = value;
end

required = {'cell_id', 'bandwidth_config', 'subframe_config', 'b_hop', ...
    'group_hopping_enabled', 'sequence_hopping_enabled', ...
    'transmission_comb', 'cyclic_shift', 'srs_bandwidth', 'n_ul_rb'};

for k = 1:numel(required)
    if ~isfield(config, required{k})
        error('Missing required parameter: %s', required{k});
    end
end

if ~isfield(config, 'n_zc')
    config.n_zc = [];
end

validate_config(config);
end

function validate_config(cfg)
%VALIDATE_CONFIG Internal helper to check bounds and value types.
    if cfg.cell_id < 0 || cfg.cell_id > 503
        error('cell_id must be between 0 and 503.');
    end
    if cfg.transmission_comb ~= 0 && cfg.transmission_comb ~= 1
        error('transmission_comb (k_tc) must be 0 or 1.');
    end
    if cfg.bandwidth_config < 0
        error('bandwidth_config (B_srs) must be non-negative.');
    end
    if cfg.subframe_config < 0
        error('subframe_config (T_srs) must be non-negative.');
    end
    if cfg.b_hop < 0
        error('b_hop must be non-negative.');
    end
    if cfg.srs_bandwidth < 0
        error('srs_bandwidth (N_b) must be non-negative.');
    end
    if cfg.n_ul_rb <= 0
        error('n_ul_rb must be positive.');
    end
end
