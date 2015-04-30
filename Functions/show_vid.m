%% FXN_show_vid
function [new_trial_index, key_summary] = show_vid(wind, trial_index, trial_config, GL, stim_position, key_summary, trial_start_time)

global session

if nargin < 5
    stim_position = '';
end
if nargin < 6
    key_summary = [];
end

while KbCheck; end;

% Keys of Interest:
if ~isempty(session.keys_of_interest)
    key_codes_of_interest = cellfun(@KbName, session.keys_of_interest);
else
    key_codes_of_interest = 1:255;
end

% Open Movie(s):
stim_path = [session.base_dir get_trial_config(trial_config, [stim_position 'Stim'])];
win_rect = session.win_rect; 
[movie mov_dur fps imgw imgh] = ...
    Screen('OpenMovie', wind, stim_path ); %#ok<NASGU,ASGLU>

% Duration, duration-jitter:
[duration, min_duration] = set_duration(trial_config, mov_dur, stim_position);

% Save Stim Attributes:
tex = Screen('GetMovieImage', wind, movie, [], 1); % get image from movie 1 sec in
draw_tex(wind, tex, trial_index, trial_config, GL, win_rect, 'save_stim_info');
Screen('FillRect', wind, session.background_color, session.win_rect);
Screen('Close',tex);
Screen('Flip', wind); Screen('Flip', wind);

% Start playback:
Screen('PlayMovie', movie , mov_rate);
WaitSecs(.10);
Screen('SetMovieTimeIndex', movie, 0);

vid_start = GetSecs();
if ~isnan(trial_start_time)
    add_data('StimStartMS', (vid_start - trial_start_time)*1000 );
end
log_msg( sprintf('Playing Video: %s', trial_config.([stim_position 'Stim'])) );


key_code = check_keypress();
while 1
    [key_code,key_summary] = check_keypress(key_code, key_summary);
    
    if GetSecs() - vid_start >= duration
        break % end movie
    end
    
    if any(key_code(key_codes_of_interest)) % they press one of the keys of interest
        if GetSecs() - vid_start >= min_duration
            break % end movie
        end
    end
    
    % Get Movie texture:
    tex  = Screen('GetMovieImage', wind, movie,  1);
    
    % If texture is available, draw and Flip to screen:
    if  tex > 0
        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
        Screen('Close', tex );
        Screen('Flip',wind, [], 0);
    end
    
end % end movie loop

% Close Movie(s):
dropped_frames = Screen('PlayMovie',  movie, 0);
log_msg( sprintf('Dropped frames: %d', dropped_frames) );
Screen('CloseMovie', movie);
Screen('Flip', wind);
log_msg('Done showing video');
if ~isnan(trial_start_time)
    add_data('StimStopMS', (vid_start - trial_start_time)*1000 );
end

% KB:
[~, key_summary] = check_keypress(key_code, key_summary, 'flush'); % flush currently pressed keys

Screen('Flip', wind);
new_trial_index = trial_index + 1;

%
    function [duration, min_duration] = set_duration(trial_config, mov_dur, stim_position)
        
        dur_field = get_trial_config(trial_config, [stim_position 'StimDuration']);
        dur_config = eval_field(dur_field);
        
        if length(dur_config) > 1 % they specified min and max
            duration = dur_config(2);
            min_duration = dur_config(1);
        else
            if isempty(dur_config) || dur_config == 0 % they specified nothing
                duration = mov_dur;
                min_duration = mov_dur;
            else                                      % they specified single number, use as min & max
                duration = dur_config;
                min_duration = dur_config;
            end
        end
        
    end

end
