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
        column     = cellfun(@num2str, { config_struct.(col_name) }, 'UniformOutput', 0);
        col_len    = length(column);
        
        % For each column entry
        for row = 1:col_len
            
            % need to check whether it's a folder, whether there are multiple before/after texts
            
            stim = config_struct(row).('Stimuli');
            if is_dir(stim)
                stim_paths = comb_dir(stim);
            else
                
            end
            
            
            
            % ...
            
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
            for t = 1:length(expanded_elem)
                if exist('new_struct','var')
                    len = length(new_struct);
                else
                    len = 0;
                end
                
                new_struct(len+1) = config_struct(row);  %#ok<AGROW>
                % insert row into new structure
                new_struct(len+1).(col_name) = expanded_elem(t); %#ok<AGROW>
                % place the proper value in that row (e.g., replace
                % '1:36' with the value of t)
                
            end   % each row in new table
            
        end % each row in orig table
        
    end % helper function
end