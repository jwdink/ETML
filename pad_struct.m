function [struct] = pad_struct (config_struct)

if nargin<1
    config_struct = ReadStructsFromTextW('./stim_config.txt');
end

struct = config_struct;
struct = pad_col('Condition' ,struct);
struct = pad_col('PhaseNum'  ,struct);
struct = pad_col('BlockNum'  ,struct);
struct = pad_trial_col(struct);

WriteStructsToText('./foo.txt', struct);

% Helper functions:

    function [new_struct] = pad_trial_col ( config_struct )
        % Extract this column, convert its contents to a string (to be processed below):
        column     = cellfun(@num2str, { config_struct.('TrialNum') }, 'UniformOutput', 0);
        col_len    = length(column);
        
        % For each column entry
        for row = 1:col_len
            
            % How many stimuli are there? What are their paths?
            stim = get_trial_config(config_struct(row), 'Stim', 'null'); % in certain cases blank stim is OK (e.g., custom_func)
            if isdir(stim)
                stim_paths = comb_dir(stim, 1);
            else
                stim_paths = {stim};
            end
            num_stim = length(stim_paths);
            
            % How many Before/After Messages are there?
            [before_stim_msgs, after_stim_msgs, num_msgs] = get_before_after_msgs(config_struct);
            
            % How many trials are there?
            % check the entered value (e.g., '1:36'), expand it into a full vector:
            elem = column{row};
            expanded_elem = eval_field(elem);
            
            for i = expanded_elem
                % for each elem, sample from the folder, and from the msgs (repped to be same length as folder).
                % do so according to rules
                
                
            end
            
        end
        
        
        
    end

    function [new_struct] = pad_col (col_name, config_struct)
        
        % Extract this column, convert its contents to a string (to be processed below):
        column     = cellfun(@num2str, { config_struct.(col_name) }, 'UniformOutput', 0);
        col_len    = length(column);
        
        % For each column entry...
        for row = 1:col_len
            
            % check the entered value (e.g., '1:36'), expand it into a full vector:
            elem = column{row};
            expanded_elem = eval_field(elem);
            
            % For the expanded values, make new rows, append them to
            % new struct:
            for t = expanded_elem
                if exist('new_struct','var')
                    len = length(new_struct);
                else
                    len = 0;
                end
                
                new_struct(len+1) = config_struct(row);  %#ok<AGROW>
                % insert row into new structure
                new_struct(len+1).(col_name) = t; %#ok<AGROW>
                % place the proper value in that row (e.g., replace
                % '1:36' with the value of t)
                
            end   % each row in new table
            
        end % each row in orig table
        
    end


    function [before_stim_msgs after_stim_msgs, num_msgs] = get_before_after_msgs(config_struct)
        
        before_stim_field = get_trial_config(config_struct(row), 'BeforeStimText');   
        after_stim_field = get_trial_config(config_struct(row), 'AfterStimText');
        
        all_msgs = {eval_field(before_stim_field) eval_field(after_stim_field)};
        msg_empty = cellfun('isempty', all_msgs);
        
        if ~all(msg_empty)
            % not all are empty?
            if any(msg_empty)
                % one of them is?
                % make empty one into cell array with length of nonempty, fill with blank msgs that'll be ignored in stim presentation 
                all_msgs{msg_empty} = cell( 1, length(all_msgs{~msg_empty}) );
                
            else
                % neither of them is
                % confirm they're same length
                if length(all_msgs{1}) ~= length(all_msgs{2})
                    log_msg(['If the BeforeStimText for a trial is a cell array, then the' ...
                        'AfterStimText must be a cell array of the same length. And vice versa.'])
                    log_msg('Check your stim_config.txt file.')
                    log_msg(['BeforeStimText Entered: ' before_stim_field])
                    log_msg(['AfterStimTextEntered: ' after_stim_field]);
                    error('See above.');
                end
            end
        end
        
        before_stim_msgs = all_msgs{1};
        after_stim_msgs  = all_msgs{2};
        num_msgs = length(before_stim_msgs);
    end

end