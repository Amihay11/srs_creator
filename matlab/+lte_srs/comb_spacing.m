%% comb_spacing.m — derive comb spacing K_TC (TS 36.211 5.5.3.2)
%{
Return the SRS comb spacing :math:`K_{TC}` per 3GPP TS 36.211
§5.5.3.2. The comb determines which subcarrier set is populated and the
valid values are 2 (comb 0) and 4 (comb 1), corresponding to the mapping
tables in §5.5.3.2-2/3.

Inputs
-----
* ``config`` — struct with a ``transmission_comb`` (``k_tc``) flag taking
  values 0 or 1 to select the comb offset.

Outputs
------
* ``spacing`` — integer equal to 2 or 4 representing :math:`K_{TC}` for
  use when spacing SRS tones across the occupied bandwidth.

Computation details
-------------------
Although the previous implementation returned a fixed spacing of 2, here
we explicitly implement the table-driven relationship
``spacing = 2 + 2 * k_tc``. Validation of ``k_tc`` to {0,1} occurs when the
configuration is created, so this function focuses on the deterministic
mapping defined by the standard.
%}

function spacing = comb_spacing(config)
    spacing = 2 + 2 * double(config.transmission_comb);
end
