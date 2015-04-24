%% FXN_shuffle_trials
function trials = shuffle_trials(trials, this_trial_config)

draw_meth = get_trial_config(this_trial_config, 'StimDrawFromFolderMethod');
if strcmpi(draw_meth, 'sample')
    shufmsg = ['You''ve selected incompatible options: trial shuffling'...
        ' and non-consecutive stimuli sampling. Ignoring the former.'];
    warning(shufmsg); %#ok<WNTAG>
    log_msg(shufmsg);
else
    log_msg('Shuffling trials in this block');
    tidx = randperm(length(trials));
    trials = trials(tidx);
end

end
