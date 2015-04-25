%% FXN_shuffle_trials
function trials = shuffle_trials(trials, stim_config_full, this_block_rows)

log_msg('Shuffling trials in this block');
draw_meth = get_trial_config(stim_config_full(this_block_rows(1)), 'StimDrawFromFolderMethod');

if strcmpi(draw_meth, 'sample')
    
    stim_hashes = cellfun(@string2hash, {stim_config_full(this_block_rows).Stim});
    trials = shuffle_no_consec(trials, stim_hashes);
    
else
    tidx = randperm(length(trials));
    trials = trials(tidx);
end

end
