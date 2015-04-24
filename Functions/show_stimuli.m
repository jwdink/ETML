%% FXN_show_stimuli
function [new_trial_index, out_struct, key_summary] = show_stimuli (wind, trial_index, trial_config, out_struct, GL)

global session

% Show Before Message:
while KbCheck; end;
show_text(wind, trial_config, 'Before');

% Summarize Keypresses?
if isempty( session.keys_of_interest )
    key_summary = [];
else
    key_summary = struct();
end

% Show Stim:
stim_type = lower( get_trial_config(trial_config, 'StimType') );

if any( is_in_cellarray( stim_type , {'image', 'img', 'slideshow'} ) )
    
    % Image:
    [new_trial_index, key_summary] = ...
        show_img(wind, trial_index, trial_config, GL, key_summary);
    
elseif is_in_cellarray( stim_type , {'vid', 'video'} )
    
    % Video:
    [new_trial_index, key_summary] = ...
        show_vid(wind, trial_index, trial_config, GL, key_summary);
    
elseif strcmp(stim_type, 'custom')
    
    % Custom Script:
    [new_trial_index, out_struct, key_summary] =...
        custom_function(wind, trial_index, trial_config, out_struct, key_summary);
    
else
    errmsg = ['StimType "' stim_type '" is unsupported.'];
    error(errmsg);
end

% Show After Message:
while KbCheck; end;
key_summary = show_text(wind, trial_config, 'After', key_summary);

end


