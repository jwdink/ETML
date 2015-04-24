%% FXN_stop_trial
function stop_trial(trial_index, block_index, trial_config, key_summary)

global session

% Save Keypress Data
if ~isempty(key_summary)
    ks_fnames = fieldnames(key_summary);
    for f = 1:length(ks_fnames)
        field = ks_fnames{f};
        this_key_summary = key_summary.(field);
        
        % Count, CumuTime:
        add_data(['Key_' upper(field) '_PressCount'], num2str(this_key_summary{1}) );
        add_data(['Key_' upper(field) '_CumuPress'], num2str(this_key_summary{2})  );
        
        % First Press:
        add_data(['Key_' upper(field) '_FirstPressTimestamp'], time_to_timestamp(this_key_summary{3}) );
        add_data(['Key_' upper(field) '_LastPressTimestamp'], time_to_timestamp(this_key_summary{4}) );
    end
end

% End trial
if session.record_phases(trial_config.('PhaseNum'));
    % ET was recording:
    log_msg(...
        ['STOP_RECORDING_PHASE_',  num2str(trial_config.('PhaseNum')),...
        '_BLOCK_',                 num2str(block_index),...
        '_TRIAL_',                 num2str(trial_index)] );
    WaitSecs(.01);
    Eyelink('StopRecording');
    WaitSecs(.01);
    Screen('Close');
    Eyelink('Message', 'TRIAL_RESULT 0');
else
    % ET was not recording:
    WaitSecs(.01);
    Screen('Close');
end

end
