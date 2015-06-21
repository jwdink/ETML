%% FXN_check_keypress
function [key_code, key_summary] = check_keypress (last_key_code, key_summary, flush_keys)
global session

% This function is not optimized for speed, since it depends on log_msg and session.
% Consider changing this in the future?

if nargin < 1 || isempty(last_key_code)
    last_key_code = zeros(1,256);
end
if nargin < 2 || isempty(key_summary)
    key_summary = [];
    trial_start_time = NaN;
else
    trial_start_time = key_summary.trial_start_time;
end
if nargin < 3
    flush_keys = 0;
end

[~,~,key_code] = KbCheck();

if flush_keys
    key_code = zeros(1,256);
end

keys_of_interest = session.keys_of_interest; 

% log keys:
key_code_diff = key_code - last_key_code;
%  0 = key state hasn't changed
%  1 = key just pressed
% -1 = key just released
released_keys = find(key_code_diff < 0);
pressed_keys  = find(key_code_diff > 0);

% KEY PRESSED:
for i = 1:length(pressed_keys)
    % Log:
    pressed_key_name = KbName(pressed_keys(i));
    pressed_key_name = regexprep(pressed_key_name,'[^a-zA-Z0-9]','');
    log_msg(sprintf('Key pressed: %s', pressed_key_name ) )
    
    % Remember in struct:
    if ~isempty(key_summary)
        if any( strcmpi(pressed_key_name, keys_of_interest) )
            if any( strcmpi(pressed_key_name, fieldnames(key_summary) ) )
                % this has been pressed before
                key_summary.(pressed_key_name).count = key_summary.(pressed_key_name).count + 1;
                key_summary.(pressed_key_name).last_pressed_ts = (GetSecs() - trial_start_time)*1000;
            else
                % this is the first time it's been pressed
                ts = (GetSecs() - trial_start_time)*1000;
                key_summary.(pressed_key_name) = ...
                    struct('count', 1, 'cumu_time', 0, 'first_pressed_ts', ts, 'last_pressed_ts', ts);
            end                             
        end
    end
    
end

% KEY RELEASED:
for i = 1:length(released_keys)
    % Log:
    released_key_name = KbName(released_keys(i));
    log_msg(sprintf( 'Key released: %s', released_key_name ) )
    
    % Remember in struct:
    if ~isempty(key_summary)
        if any( strcmpi(released_key_name, keys_of_interest) )
            if any( strcmpi(released_key_name, fieldnames(key_summary) ) )
                ts = (GetSecs() - trial_start_time)*1000;
                key_summary.(released_key_name).cumu_time = key_summary.(released_key_name).cumu_time +...
                    (ts - key_summary.(released_key_name).last_pressed_ts);
                        % cumu-time = cumu-time + (current-timestamp - last-timestamp)
            else
                log_msg('Unmatched keypress');
                warning('Unmatched keypress'); %#ok<WNTAG>
            end
        end
    end
    
end


% check for escape:
if length(pressed_keys) == 1
    if strcmpi( pressed_key_name , 'Escape' )
        WaitSecs(.5);
        [~,~,key_code] = KbCheck();
        if strcmpi(KbName(key_code),'Escape')
            log_msg('Aborting experiment due to ESCAPE key press.');
            post_experiment(true);
        end
    end
end

end
