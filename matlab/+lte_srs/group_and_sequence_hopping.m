function hopping = group_and_sequence_hopping(config, slot_index)
%GROUP_AND_SEQUENCE_HOPPING Compute group and sequence hopping indices.
    f_ss = mod(config.cell_id, 30);
    if config.group_hopping_enabled
        c_init = mod(((floor(slot_index / 2) + 1) * (config.cell_id + 1) * (2 ^ 9) + config.cell_id), 2 ^ 31);
        c = lte_srs.generate_prs(c_init, 8 * (slot_index + 1));
        start_idx = 8 * slot_index + 1;
        f_gh = 0;
        for i = 0:7
            f_gh = f_gh + bitshift(c(start_idx + i), i);
        end
        f_gh = mod(f_gh, 30);
    else
        f_gh = 0;
    end

    group_number = mod(f_ss + f_gh, 30);

    if config.sequence_hopping_enabled
        seq_shift = mod(f_gh, 30);
    else
        seq_shift = 0;
    end

    sequence_number = mod(group_number + seq_shift, 30);
    hopping = struct('group_number', group_number, 'sequence_number', sequence_number, ...
        'f_gh', f_gh, 'f_ss', f_ss);
end
