%% FXN_shuffle_trials
function trials = shuffle_trials(trials, stim_config_full, this_block_rows)

log_msg('Shuffling trials in this block.');

shuffle_meth = get_trial_config(stim_config_full(this_block_rows(1), 'ShuffleTrialsInBlock'));

if strcmpi(shuffle_meth, 'allow_consec')
    
    tidx = randperm(length(trials));
    trials = trials(tidx);
    
else
    
    log_msg('Will attempt to prevent consecutive presentation of same stim.');
    
    stim_hashes = cellfun(@string2hash, {stim_config_full(this_block_rows).Stim});
    trials = shuffle_no_consec(trials, stim_hashes);
    
end

end
