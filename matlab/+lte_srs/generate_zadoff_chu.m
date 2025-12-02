function seq = generate_zadoff_chu(u, N_zc)
%GENERATE_ZADOFF_CHU Generate the complex Zadoff-Chu base sequence.
    n = (0:N_zc-1).';
    seq = exp(-1j * pi * u .* n .* (n + 1) / N_zc);
end
