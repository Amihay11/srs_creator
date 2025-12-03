%% generate_zadoff_chu.m — root Zadoff–Chu sequence (TS 36.211 5.5.1.1)
%{
Generate the length-:math:`N_{ZC}` root Zadoff–Chu sequence
:math:`r_u(n)` defined in 3GPP TS 36.211 §5.5.1.1 and reused for SRS in
§5.5.3.2. Zadoff–Chu sequences provide constant amplitude and ideal
autocorrelation properties that simplify uplink channel estimation.

Inputs
-----
* ``u`` — root index :math:`u \in [0, N_{ZC}-1]` coprime with :math:`N_{ZC}`.
* ``N_zc`` — sequence length :math:`N_{ZC}` (commonly 839 for LTE SRS).

Outputs
------
* ``seq`` — column vector containing :math:`r_u(n) = e^{-j\pi u n(n+1)/N_{ZC}}`
  for :math:`n=0..N_{ZC}-1`.

Computation details
-------------------
The formula follows TS 36.211 Eq. (5.5.1.1-1). The function builds a
zero-based index vector ``n`` and applies the complex exponential with the
phase quadratic in ``n``. Inputs are not revalidated here; caller ensures
``u`` and ``N_zc`` meet the coprimality condition for CAZAC properties.
%}

function seq = generate_zadoff_chu(u, N_zc)
    n = (0:N_zc-1).';
    seq = exp(-1j * pi * u .* n .* (n + 1) / N_zc);
end
