%% FXN_check_trial
function check_trial(this_trial_row, trial_record_path)
if length(this_trial_row) > 1
    log_msg(['Please check: ' trial_record_path]);
    error(['Attempted to find a unique row corresponding to this trial, but there were multiple.'...
        ' Check unshuffled_experiment_structure.txt (see path above). Something is probably wrong with stim_config.'])
elseif isempty(this_trial_row)
    log_msg(['Please check: ' trial_record_path]);
    error(['Attempted to find a unique row corresponding to this trial, but none exists.' ...
        'Check unshuffled_experiment_structure.txt (see path above). Something is probably wrong with stim_config.']);
end
end
