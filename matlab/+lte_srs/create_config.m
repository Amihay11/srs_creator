%% create_config.m — build LTE SRS configuration (TS 36.211 5.5.3)
%{
Construct and validate a configuration struct used throughout the SRS
generation pipeline. Parameters map directly onto the notation in 3GPP
TS 36.211 §5.5.3 (Sounding reference signal) so that each helper function
operates on standard-aligned fields.

Inputs
-----
* Name/value pairs defining the following required fields:
  * ``cell_id`` — physical cell identity :math:`N_{ID}^{cell}` in [0, 503].
  * ``bandwidth_config`` — :math:`B_{SRS}` (Table 5.5.3.2-1) ≥ 0.
  * ``subframe_config`` — :math:`T_{SRS}` periodicity index ≥ 0 (Table
    5.5.3.3-1; 0 disables transmission).
  * ``b_hop`` — frequency-hopping parameter :math:`b_{hop}` ≥ 0.
  * ``group_hopping_enabled`` — logical flag enabling group hopping (5.5.3.1.3).
  * ``sequence_hopping_enabled`` — logical flag enabling sequence hopping (5.5.3.1.4).
  * ``transmission_comb`` — :math:`k_{TC}` ∈ {0,1} selecting comb offset.
  * ``cyclic_shift`` — :math:`\alpha` cyclic shift in radians (Table 5.5.3.2-1).
  * ``srs_bandwidth`` — :math:`N_b` bandwidth index ∈ [0,3].
  * ``n_ul_rb`` — uplink bandwidth :math:`N_{UL}^{RB}` > 0 in resource blocks.

* Optional field:
  * ``n_zc`` — custom Zadoff–Chu root length (defaults to 839 if omitted).

Outputs
------
* ``config`` — struct containing all provided fields plus defaults; later
  helper functions assume these fields exist and meet the standard bounds.

Computation details
-------------------
The function reshapes name/value arguments into pairs, populates a struct,
checks for required parameters, applies defaults, and then calls the
internal validator. Validation enforces parameter ranges from TS 36.211
tables to prevent out-of-range SRS generation requests.
%}

function config = create_config(varargin)

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
