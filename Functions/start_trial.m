%% FXN_start_trial
function start_trial(trial_index, block_index, trial_config)

global session

if session.record_phases(trial_config.('PhaseNum'));
    Eyelink('StartRecording');
    WaitSecs(.01);
    log_msg(...
        ['START_RECORDING_PHASE_', num2str(trial_config.('PhaseNum')),...
        '_BLOCK_',                 num2str(block_index),...
        '_TRIAL_',                 num2str(trial_index)]);
end

%
add_data('TrialNum', trial_index);
add_data('BlockNum', block_index);
other_fields1 = {'Condition', 'PhaseNum', 'Stim', 'StimType', 'FlipX', 'FlipY'};
other_fields2 = eval_field( get_config('CustomFields') );
other_fields = [other_fields1 other_fields2];
% also some fields that will be inserted at stim-presentation (because they can be dynamically set):
% 'DimX', 'DimY','StimCenterX', 'StimCenterY', 'duration'
for f = 1:length(other_fields)
    field = other_fields{f};
    if isfield(trial_config,field)
        add_data(field, trial_config.(field));
    end
end

end
