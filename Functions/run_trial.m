function [new_trial_index, out_struct, key_summary] = run_trial (wind, trial_index, trial_config, out_struct, GL, trial_start_time)

global session

% Summarize Keypresses?
if isempty( session.keys_of_interest )
    key_summary = []; % will be ignored
else
    key_summary = struct(); % will be populated
end


% Show Pre-Stim:
pre_stim_type = lower( get_trial_config(trial_config, 'PreStimType') );
if strcmpi(pre_stim_type, 'slideshow')
    log_msg('Warning: Slideshow was selected for pre-stim-type, which is not allowed. Using "image" instead');
    pre_stim_type = 'image';
end
if ~isempty(pre_stim_type)
    add_data('PreStim', get_trial_config(trial_config, 'PreStim'));
    add_data('PreStimType', pre_stim_type);
    [~, out_struct, key_summary] = ...
        show_stim(wind, pre_stim_type, trial_index, trial_config, out_struct, GL, 'Pre', key_summary);
end

% Show Main-Stim:
stim_type = lower( get_trial_config(trial_config, 'StimType') );
[new_trial_index, out_struct, key_summary] = ...
    show_stim(wind, stim_type, trial_index, trial_config, out_struct, GL, '', key_summary, trial_start_time);


% Show Post-Stim:
post_stim_type = lower( get_trial_config(trial_config, 'PostStimType') );
if strcmpi(post_stim_type, 'slideshow')
    add_data('PostStim', get_trial_config(trial_config, 'PreStim'));
    add_data('PostStimType', pre_stim_type);
    log_msg('Warning: Slideshow was selected for post-stim-type, which is not allowed. Using "image" instead');
    post_stim_type = 'image';
end
if ~isempty(post_stim_type)
[~, out_struct, key_summary] = ...
    show_stim(wind, post_stim_type, trial_index, trial_config, out_struct, GL, 'Post', key_summary);
end



return

%%
    function [new_trial_index, out_struct, key_summary] = ...
            show_stim(wind, stim_type, trial_index, trial_config, out_struct, GL, stim_position, key_summary, trial_start_time)
        
        if nargin < 9
            trial_start_time = NaN;
        end
        
        if any( strcmpi( stim_type , {'image', 'img', 'slideshow'} ) )
            
            % Image:
            [new_trial_index, key_summary] = ...
                show_img(wind, trial_index, trial_config, GL, stim_position, key_summary, trial_start_time);
            
        elseif strcmpi(stim_type, 'video')
            
            % Video:
            [new_trial_index, key_summary] = ...
                show_vid(wind, trial_index, trial_config, GL, stim_position, key_summary, trial_start_time);
            
        elseif strcmpi(stim_type, 'fixation')
            
            % Fixation Cross:
            show_fixation_cross(wind)
            new_trial_index = trial_index + 1;
            
        elseif strcmpi(stim_type, 'text')
            
            % Text:
            key_summary = show_text(wind, trial_config, stim_position, key_summary, trial_start_time);
            new_trial_index = trial_index + 1;
            
        elseif strcmpi(stim_type, 'custom')
            
            % Custom Script:
            [new_trial_index, out_struct, key_summary] =...
                custom_function(wind, trial_index, trial_config, out_struct, key_summary, trial_start_time);
            
        else
            errmsg = ['StimType "' stim_type '" is unsupported.'];
            error(errmsg);
        end
    end

end

