%% FXN_et_calibrate
function et_calibrate(wind, this_phase)

global session
global el

if session.record_phases(this_phase)
    log_msg('It is a recording phase.');
    el.backgroundcolour = get_config('BackgroundColor', 80);
    
    while KbCheck(); end;
    msg = 'Before continuing, we just need to calibrate. Let the experimenter know once you''re ready.';
    DrawFormattedText(wind, msg, 'center', 'center');
    Screen('Flip', wind);
    KbWait();
    
    log_msg('Calibration started.');
    EyelinkDoTrackerSetup(el);
    log_msg('Calibration finished.');
    WaitSecs(.5);
else
    log_msg('It is not a recording phase.');
end
end

