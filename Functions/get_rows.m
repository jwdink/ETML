%% FXN_get_rows
function [rows] = get_rows (config_struct, condition, this_phase, this_block, this_trial)

cond_logical  = ([config_struct.Condition] == condition);

if nargin > 2
    phase_logical = ([config_struct.PhaseNum] == this_phase) & cond_logical;
    if nargin > 3
        block_logical = ([config_struct.BlockNum] == this_block) & phase_logical;
        if nargin > 4
            trial_logical = ([config_struct.TrialNum] == this_trial) & block_logical;
            % if phase and block and trial were all input, return
            % rows for trial within block within phase:
            rows = find( trial_logical );
            return
        end
        % if phase and block were input but nothing else, return
        % rows for block within phase:
        rows = find( block_logical );
        return
    end
    % if phase was input but nothing else, return rows for that phase:
    rows = find( phase_logical );
    return
end

end
