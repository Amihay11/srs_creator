%% apply_cyclic_shift.m — apply SRS cyclic shift (TS 36.211 5.5.3.1)
%{
Apply the normalized cyclic shift :math:`\alpha` to a base Zadoff–Chu
sequence per 3GPP TS 36.211 §5.5.3.1. The rotation produces one of up to
8 orthogonal SRS sequences within the same comb, enabling multiplexing of
multiple UEs on the same time–frequency resources.

Inputs
-----
* ``base_seq`` — column vector containing the complex Zadoff–Chu base
  sequence :math:`r_u(n)` prior to any comb offset.
* ``alpha`` — scalar cyclic shift in radians, usually an integer multiple
  of :math:`\pi/4` from Table 5.5.3.2-1.

Outputs
------
* ``seq`` — column vector with element-wise rotation ``exp(j*alpha*n)``
  applied, corresponding to :math:`r_u^{(\alpha)}(n) = r_u(n)\,e^{j\alpha n}`
  in the standard.

Computation details
-------------------
The function constructs the sample index ``n`` as a zero-based column
vector to match the discrete-time notation in TS 36.211 and multiplies
the base sequence by the complex exponential rotation. The result keeps
the input dimensionality, preserving compatibility with subsequent comb
mapping and frequency placement steps.
%}

function seq = apply_cyclic_shift(base_seq, alpha)
    n = (0:numel(base_seq)-1).';
    seq = base_seq(:) .* exp(1j * alpha .* n);
end
