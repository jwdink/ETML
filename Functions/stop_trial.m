%% FXN_stop_trial
function stop_trial(trial_index, block_index, trial_config, key_summary)

global session

% Save Keypress Data
if ~isempty(key_summary)
    ks_fnames = fieldnames(key_summary);
    for f = 1:length(ks_fnames)
        field = ks_fnames{f};
        if ~strcmpi(field, 'trial_start_time')
            this_key_summary = key_summary.(field);
            
            % Count, CumuTime:
            add_data(['Key_' upper(field) '_PressCount'], this_key_summary.count );
            add_data(['Key_' upper(field) '_CumuPress'], this_key_summary.cumu_time  );
            
            % First Press:
            add_data(['Key_' upper(field) '_FirstPressTimestamp'], this_key_summary.first_pressed_ts );
            add_data(['Key_' upper(field) '_LastPressTimestamp'],  this_key_summary.last_pressed_ts );
        end
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
