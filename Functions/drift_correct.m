%% FXN_drift_correct
function drift_correct(this_phase)

global session
global el

if session.record_phases(this_phase)
    log_msg('Doing drift correct...');

    % do a final check of calibration using driftcorrection
    DC_start = GetSecs();
    success = EyelinkDoDriftCorrection(el);
    % if the experimenter hits esc here, then c, she
    % can recalibrate. that means every single block, there's a
    % chance to recalibrate if necessary.
    
    % If the eyetracker is having connection troubles, this gives
    % it 15 seconds to get those sorted out.
    while success~=1 % if it doesn't work, try it a couple more times
        success = EyelinkDoDriftCorrection(el);
        if (GetSecs() - DC_start) > 15 % give up after 15 seconds of trying
            break
        end
        WaitSecs(.1);
    end
    
    if success~=1
        error('Cannot connect to eyetracker during drift_correct.');
    end
    
end

end
