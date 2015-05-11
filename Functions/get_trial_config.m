%% FXN_get_trial_config
function out = get_trial_config(trial_config, field, default)

if any( strcmp(field, fieldnames(trial_config)) )
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
            
        case {'StimDuration', 'PreStimDuration', 'PostStimDuration', 'FlipX', 'FlipY',...
                'ShuffleBlocksInPhase', 'ShuffleTrialsInBlock'}
            out = 0;
            
        case {'PreStim', 'PostStim', 'PreStimType', 'PostStimType', 'Stim'}
            out = '';
            
        otherwise
            error(['"' field '" not found (at least for some rows) in stim_config.txt. No default for this column.'])
            
    end
end

end