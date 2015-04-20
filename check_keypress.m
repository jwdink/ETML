%% FXN_check_keypress
function [keycode] = check_keypress (last_keycode, trialend)

% This function is not optimized for speed, since it depends on log_msg
% Consider changing this in the future?

if nargin < 1 || isempty(last_keycode)
    last_keycode = zeros(1,256);
end
if nargin < 2
    trialend = 0;
end

[~,~,keycode] = KbCheck();

if trialend
    keycode = zeros(1,256);
end

% log keys:
keycode_diff = keycode - last_keycode;
%  0 = key state hasn't changed
%  1 = key just pressed
% -1 = key just released
released_keys = find(keycode_diff < 0);
pressed_keys  = find(keycode_diff > 0);

for i = 1:length(released_keys)
    released_key_name = KbName(released_keys(i));
    log_msg(sprintf( 'Key released: %s', released_key_name ) )
end
for i = 1:length(pressed_keys)
    pressed_key_name = KbName(pressed_keys(i));
    log_msg(sprintf( 'Key pressed: %s', pressed_key_name ) )
end

% check for escape:
if length(pressed_keys) == 1
    if strcmpi( pressed_key_name , 'Escape' )
        WaitSecs(.5);
        [~,~,keycode] = KbCheck();
        if strcmpi(KbName(keycode),'Escape')
            log_msg('Aborting experiment due to ESCAPE key press.');
            post_experiment(true);
        end
    end
end

end
