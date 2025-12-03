%% generate_prs.m — LTE Gold sequence generator (TS 36.211 7.2)
%{
Create the pseudo-random sequence :math:`c(n)` used for group and sequence
hopping in LTE SRS as specified in 3GPP TS 36.211 §7.2. The sequence is
the modulo-2 sum of two length-31 LFSRs with characteristic polynomials
:math:`x^{31} + x^3 + 1` for :math:`x_1` and :math:`x^{31} + x^3 + x^2 + x + 1`
for :math:`x_2`. The generated chips feed directly into the hopping
calculations described in §5.5.3.1.3 and §5.5.3.1.4.

Inputs
-----
* ``c_init`` — 31-bit initialization value for :math:`x_2` per §7.2, where
  bit 0 corresponds to the least significant bit of the integer input.
* ``len`` — number of PRS chips to produce; must be a positive integer.

Outputs
------
* ``c`` — column vector of length ``len`` containing binary chips in
  :math:`\{0,1\}` representing the Gold sequence :math:`c(n)`.

Computation details
-------------------
* Seeds: :math:`x_1(0)=1`, :math:`x_1(1..30)=0` (per §7.2) and :math:`x_2`
  bits derived from ``c_init`` least-significant-bit first.
* Recurrence: the implementation advances both registers forward, storing
  ``len`` additional chips to avoid negative indexing while matching the
  recursion offsets in the specification (e.g., ``x1(n+31)=x1(n+3)+x1(n)``).
* Combination: the Gold sequence is ``mod(x1 + x2, 2)`` starting at index
  32 (MATLAB 1-indexed) to align with :math:`n=0` in the standard, and the
  result is truncated to ``len`` chips for downstream use.
%}

function c = generate_prs(c_init, len)

    % Shift-register states (first 31 chips hold the seeds)
    x1 = zeros(len + 31, 1);
    x2 = zeros(len + 31, 1);

    % x1 seed: x1(1)=1, x1(2..31)=0
    x1(1) = 1;

    % x2 seed from c_init bits (LSB first)
    for n = 1:31
        x2(n) = bitand(bitshift(c_init, -(n - 1)), 1);
    end

    % Generate remaining chips (1-indexed form of x1(n+31)=x1(n+3)+x1(n))
    % Index the recurrence directly with positive offsets so MATLAB never
    % touches negative/zero indices even for small ``len``.
    for idx = 32:(len + 31)
        x1(idx) = mod(x1(idx - 3) + x1(idx - 31), 2);
        x2(idx) = mod(x2(idx - 3) + x2(idx - 2) + x2(idx - 1) + x2(idx - 31), 2);
    end

    % Gold sequence
    c = mod(x1(32:end) + x2(32:end), 2);
    c = c(1:len);
end
