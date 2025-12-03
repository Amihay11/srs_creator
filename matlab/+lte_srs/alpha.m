%% alpha.m — cyclic shift helper (TS 36.211 5.5.3.1)
%{
Return the normalized cyclic shift value, :math:`\alpha`, used when
rotating the Zadoff–Chu base sequence for LTE sounding reference signals
(SRS) as defined in 3GPP TS 36.211 §5.5.3.1 and §5.5.3.2. The cyclic
shift controls which orthogonal sequence is transmitted within an SRS
comb and is later reapplied when demodulating or correlating received
symbols.

Inputs
-----
* ``config`` — struct with a ``cyclic_shift`` field in radians. This
  value typically takes one of the discrete shifts in the set
  {0, π/4, …, 7π/4} for normal cyclic shifts per TS 36.211 Table 5.5.3.2-1.

Outputs
------
* ``value`` — scalar double representing :math:`\alpha` in radians for
  direct reuse in exponential phase rotation terms ``exp(1j * alpha * n)``.

Computation details
-------------------
The function simply casts the provided configuration field to ``double``
so that downstream exponential operations work with MATLAB's floating
point arithmetic. No wrapping or normalization is performed because the
input is assumed to be compliant with the discrete set defined by the
standard; validation occurs when constructing the configuration object.
%}

function value = alpha(config)
    value = double(config.cyclic_shift);
end
