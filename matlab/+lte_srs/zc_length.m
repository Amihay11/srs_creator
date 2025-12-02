function len = zc_length(config)
%ZC_LENGTH Return the Zadoff-Chu length for the configuration.
    if isempty(config.n_zc)
        len = 839;
    else
        len = double(config.n_zc);
    end
end
