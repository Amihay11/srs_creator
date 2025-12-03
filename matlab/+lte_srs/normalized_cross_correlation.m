function value = normalized_cross_correlation(a, b)
%NORMALIZED_CROSS_CORRELATION Compute normalized cross-correlation magnitude.
    if numel(a) ~= numel(b)
        error('Signals must be the same length for correlation.');
    end
    norm_a = norm(a);
    norm_b = norm(b);
    if norm_a == 0 || norm_b == 0
        value = 0.0;
        return;
    end
    corr = sum(conj(a(:)) .* b(:));
    value = abs(corr) / (norm_a * norm_b);
end
