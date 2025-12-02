function seq = apply_cyclic_shift(base_seq, alpha)
%APPLY_CYCLIC_SHIFT Apply cyclic shift alpha to a base sequence.
    n = (0:numel(base_seq)-1).';
    seq = base_seq(:) .* exp(1j * alpha .* n);
end
