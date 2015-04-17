function [struct] = pad_struct (config_struct)
%% Main Code:

if nargin<1
    config_struct = ReadStructsFromTextW('./stim_config.txt');
end

struct = config_struct;
struct = pad_col('Condition' ,struct);
struct = pad_col('PhaseNum'  ,struct);
struct = pad_col('BlockNum'  ,struct);
struct = pad_trial_col(struct);

WriteStructsToText('./foo.txt', struct);

%% Helper functions:

%% Make a Column 
% (not a trial column, though)
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

%% Make Trial Column:
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
            
            % How to draw stim?
            stim_order = select_draw_method(config_struct, row, num_stim, num_msgs, expanded_elem);
            
            % For each row in the unexpanded struct:
            for t = 1:length(expanded_elem)
                
                % Get struct length/existence:
                if exist('new_struct','var')
                    len = length(new_struct);
                else
                    len = 0;
                end
                
                % Get Question/Stim to add, according to stim_order:
                [question_ind, stim_ind] = ind2sub([num_msgs num_stim], stim_order(t) );
                
                % Insert a row into new struct:
                new_struct(len+1) = config_struct(row);  %#ok<AGROW>
                new_struct(len+1).('TrialNum') = expanded_elem(t); %#ok<AGROW>
                % place the proper value in that row (e.g., replace
                % '1:2:36' with 1,3,5,..., etc.)
                
                % Place the proper value for 'stimuli' (e.g.,
                % specific filepath replaces folder path, specific msg replaces cellarray)
                new_struct(len+1).('BeforeStimText') = before_stim_msgs{question_ind}; %#ok<AGROW>
                new_struct(len+1).('Stim')           = stim_paths{stim_ind}; %#ok<AGROW>
                new_struct(len+1).('AfterStimText')  = after_stim_msgs{question_ind}; %#ok<AGROW>
                
            end % end element-expanding loop
            
        end % end 'for each row in non-expanded struct' loop
        
    end % end func

% Choose Stim Order based on Draw method:
    function [stim_order] = select_draw_method(config_struct, row, num_stim, num_msgs, expanded_elem)
        
        draw_meth = get_trial_config(config_struct(row), 'StimDrawFromFolderMethod');
        if num_stim < 2 && ~isempty(draw_meth)
            msg = ['You have selected a "StimDrawFromFolderMethod" for a trial, but the ' ...
                'stim for that trial is not a folder. Ignoring.'];
            warning(msg); %#ok<WNTAG>
            log_msg(msg);
        end
        switch lower(draw_meth)
            case 'asc'
                stim_order = 1:length(expanded_elem);
            case 'desc'
                stim_order = 1:length(expanded_elem);
                stim_order = stim_order(end:-1:1); % reverse!
            case 'sample'
                stim_order = randsample_stim_order(num_msgs, num_stim, length(expanded_elem), 0 );
            case 'sample_consec'
                stim_order = randsample_stim_order(num_msgs, num_stim, length(expanded_elem), 1 );
            case 'sample_replace'
                stim_order = randsample(num_msgs * num_stim, length(expanded_elem), 0);
            otherwise
                stim_order = 1:length(expanded_elem);
        end
        
    end

% Randomly Sample Stimuli Ordering:
    function [stim_order] = randsample_stim_order(num_msgs, num_stim, num_trials, consec_allowed)
        
        if num_trials <= (num_stim*num_msgs)
            stim_order = randsample(num_msgs*num_stim, num_trials);
        else
            if mod(num_trials, (num_stim*num_msgs))
                while ~consec_allowed % if consec allowed, this just runs once
                    stim_order = randsample_w_bigger(num_msgs*num_stim, num_trials);
                    [~, stim_ind] = ind2sub([num_msgs num_stim], stim_order);
                    if all( diff( stim_ind ) )
                        return
                    end
                end
            else
                msg = ['If randomly sampling without replacement, and number of trials is greater than' ...
                    'number of stimuli, then number of trials must be an even multiple of number' ...
                    'of stimuli. However, on one of your trials, you have ' num2str(num_stim*num_msgs) ...
                    ' stimuli, and ' num2str(num_trials) ' trials.'];
                error(msg);
            end
            
        end
        
    end

    % Get Before-Stim / After-Stim Message Text:
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