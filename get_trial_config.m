%% FXN_get_trial_config
function out = get_trial_config(trial_config, field, default)

if is_in_cellarray(field, fieldnames(trial_config))
    % They have this column in their stim config:
    if ~isempty(trial_config.(field)); % and it's not empty
        out = trial_config.(field);
        return
    end
end

% Let's see if there's a default value
if nargin > 2
    out = default;
else
    switch field
        case 'StimDrawFromFolderMethod'
            out = 'asc';
            
        case {'Duration', 'BSTDuration', 'ASTDuration', 'FlipX', 'FlipY'}
            out = 0;
            
        case {'BeforeStimText', 'AfterStimText'}
            out = '';
            
        otherwise
            error(['Column ' field ' not found in stim_config.txt'])
            
    end
end

end