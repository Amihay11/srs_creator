function c = generate_prs(c_init, len)
%GENERATE_PRS Generate an LTE Gold pseudo-random sequence.
    x1 = zeros(len + 31, 1);
    x2 = zeros(len + 31, 1);
    x1(1) = 1;
    for n = 2:len + 31
        x1(n) = mod(x1(n - 3) + x1(n - 31), 2);
    end
    for n = 1:31
        x2(n) = bitand(bitshift(c_init, -(n - 1)), 1);
    end
    for n = 32:len + 31
        x2(n) = mod(x2(n - 3) + x2(n - 2) + x2(n - 1) + x2(n - 31), 2);
    end
    c = mod(x1(32:end) + x2(32:end), 2);
    c = c(1:len);
end
