function active = is_active_subframe(config, subframe)
%IS_ACTIVE_SUBFRAME Return true if the UE transmits SRS in the subframe.
    if config.subframe_config == 0
        active = false;
    else
        active = mod(subframe, config.subframe_config) == 0;
    end
end
