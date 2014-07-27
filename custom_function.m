function [ new_trial_index, out_struct ] = ...
    custom_function( trial_index, trial_config, out_struct, wind, now_recording) %#ok<INUSD>

% %
%
% Your Code goes here.
%
% out_struct is a struct you can use to have persistent variables across
% trials
% 
% %

out_struct = [];
new_trial_index = trial_index + 1;

end

