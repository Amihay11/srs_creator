%% bandwidth_in_subcarriers.m — compute M_sc (TS 36.211 5.5.3.2)
%{
Derive the number of occupied subcarriers :math:`M_{sc}` for the SRS
resource block according to 3GPP TS 36.211 §5.5.3.2. The value depends on
the configured bandwidth index :math:`B_{SRS}`, additional bandwidth
parameter :math:`N_b`, and the system UL bandwidth :math:`N_{UL}^{RB}`.

Inputs
-----
* ``config`` — struct with fields ``bandwidth_config`` (:math:`B_{SRS}`),
  ``srs_bandwidth`` (:math:`N_b`), and ``n_ul_rb`` (:math:`N_{UL}^{RB}`).

Outputs
------
* ``m_sc`` — integer number of subcarriers actually used by the SRS after
  respecting the UE/system bandwidth limit.

Computation details
-------------------
The scaling term :math:`2^{B_{SRS}}` follows Table 5.5.3.2-1. The raw
allocation multiplies the scaling by :math:`12(N_b+1)` since each resource
block spans 12 subcarriers and the standard defines :math:`N_b \in [0,3]`.
Finally, the result is clipped to the available uplink bandwidth to avoid
over-allocation when the configured width exceeds the cell capability.
%}

function m_sc = bandwidth_in_subcarriers(config)
    scaling = 2 ^ max(config.bandwidth_config, 0);
    raw = (config.srs_bandwidth + 1) * 12 * scaling;
    max_sc = config.n_ul_rb * 12;
    m_sc = min(raw, max_sc);
    m_sc = floor(double(m_sc));
end
