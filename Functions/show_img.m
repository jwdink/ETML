%% FXN_show_img
function [new_trial_index, key_summary] = show_img (wind, trial_index, trial_config, GL, stim_position, key_summary)

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

stim_path = [session.base_dir get_trial_config(trial_config, [stim_position 'Stim'])];
win_rect = session.win_rect;

% Get trial info about stim duration:
[duration, min_duration] = set_duration(trial_config, stim_position);

% Slideshow:
if isempty(stim_position)
    slideshow = strcmpi('slideshow', trial_config.('StimType'));
else
    slideshow = 0; % no slideshows in pre/post stim
end

% Get image:
image = imread(stim_path);                                      % read in image file
tex = Screen('MakeTexture', wind, image, [], [], [], 1);        % make texture
draw_tex(wind, tex, trial_index, trial_config, GL, win_rect, 'save_stim_info'); % draw

save_img_for_dv(trial_index, trial_config);

while KbCheck; end; % if keypress from prev slide is still happening, we wait til its over
log_msg( sprintf('Displaying Image: %s', stim_path) );
img_start_clock = clock;
image_start = GetSecs();
Screen('Flip', wind);

close_image = 0;
key_code = check_keypress();
while ~close_image
    
    if duration > 0
        % if each image is only supposed to be up there for a
        % certain amount of time, this advances the slide at
        % that time.
        if GetSecs() > (image_start + duration)
            close_image = 1;
            new_trial_index = trial_index + 1;
        end
    end
    
    [key_code, key_summary] = check_keypress(key_code, key_summary);
    
    if slideshow
        % if it's a slideshow, then they can sift thru the slides
        if     strcmpi(KbName(key_code), 'RightArrow')
            close_image = 1;
            new_trial_index = trial_index + 1;
        elseif strcmpi(KbName(key_code), 'LeftArrow')
            close_image = 1;
            new_trial_index = trial_index - 1;
        end
    else
        % if it's an image, advance on keypress, given that it's been
        % up for minimum amount of time
        if any(key_code(key_codes_of_interest)) % they press one of the keys of interest
            if GetSecs() > (image_start + min_duration)
                close_image = 1;
                new_trial_index = trial_index + 1;
            end
        end
    end
    
    
end

% Stop Time:
img_stop_clock = clock;
img_stop_clock_str = time_to_timestamp(img_stop_clock);
add_data('StimStopTimestamp', img_stop_clock_str);

% Start Time:
img_start_clock_str = time_to_timestamp(img_start_clock);
add_data('StimStartTimestamp', img_start_clock_str);

% KB:
[~, key_summary] = check_keypress(key_code, key_summary, 'flush'); % flush currently pressed keys

%
    function [duration, min_duration] = set_duration(trial_config, stim_position)
        
        dur_field = get_trial_config(trial_config, [stim_position 'StimDuration']);
        dur_config = eval_field(dur_field);
        
        if length(dur_config) > 1 % they specified min and max
            duration = dur_config(2);
            min_duration = dur_config(1);
        else
            if isempty(dur_config) || dur_config == 0 % they specified nothing
                duration = Inf;
                min_duration = 0;
            else                                      % they specified single number, use as min & max
                duration = dur_config;
                min_duration = dur_config;
            end
        end
        
    end


end

