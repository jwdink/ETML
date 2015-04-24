%% FXN_check_keypress
function [key_code, key_summary] = check_keypress (last_key_code, key_summary, trialend)
global session

% This function is not optimized for speed, since it depends on log_msg and session.
% Consider changing this in the future?

if nargin < 1 || isempty(last_key_code)
    last_key_code = zeros(1,256);
end
if nargin < 2
    key_summary = [];
else
    timestamp = clock;
end
if isempty(key_summary)
    if isstruct(key_summary)
        key_summary.null = 'null'; % checks below depend on empty vs. nonempty struct
    else
        key_summary = [];
    end
end
if nargin < 3
    trialend = 0;
end

[~,~,key_code] = KbCheck();

if trialend
    key_code = zeros(1,256);
end

% log keys:
key_code_diff = key_code - last_key_code;
%  0 = key state hasn't changed
%  1 = key just pressed
% -1 = key just released
released_keys = find(key_code_diff < 0);
pressed_keys  = find(key_code_diff > 0);

for i = 1:length(pressed_keys)
    % Log:
    pressed_key_name = KbName(pressed_keys(i));
    log_msg(sprintf( 'Key pressed: %s', pressed_key_name ) )
    
    % Remember in struct:
    if ~isempty(key_summary)
        if any( strcmpi(pressed_key_name, session.keys_of_interest) )
            if any( strcmpi(pressed_key_name, fieldnames(key_summary) ) )
                key_summary.(pressed_key_name){1} = key_summary.(pressed_key_name){1} + 1; % increment press count
                key_summary.(pressed_key_name){4} = timestamp; % this is the 'last' keypress
            else
                key_summary.(pressed_key_name) = {1 0 timestamp timestamp};
            end                             % count, cumulative time, first_pressed_time, last_pressed_time
        end
    end
    
end

for i = 1:length(released_keys)
    % Log:
    released_key_name = KbName(released_keys(i));
    log_msg(sprintf( 'Key released: %s', released_key_name ) )
    
    % Remember in struct:
    if ~isempty(key_summary)
        if any( strcmpi(released_key_name, session.keys_of_interest) )
            if any( strcmpi(released_key_name, fieldnames(key_summary) ) )
                key_summary.(released_key_name){2} = key_summary.(released_key_name){2} +...
                    etime(timestamp, key_summary.(released_key_name){4});
                        % cumu-time = cumu-time + (current-timestamp - last-timestamp)
            else
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
