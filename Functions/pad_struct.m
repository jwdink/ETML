function [struct] = pad_struct (config_struct)
%% Main Code:

if nargin < 1
    config_struct = ReadStructsFromTextW('./stim_config.txt');
end

struct = config_struct;
struct = pad_col('Condition' ,struct);
struct = pad_col('PhaseNum'  ,struct);
struct = pad_col('BlockNum'  ,struct);
struct = pad_trial_col(struct);

%WriteStructsToText('foo.txt', struct);

%% Make a Column
% (for any col but trial col)
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
        
        % For each row
        for row = 1:col_len
            
            % How many trials are there?
            % check the entered value (e.g., '1:36'), expand it into a full vector:
            elem = column{row};
            expanded_elem = eval_field(elem);
            
            % Expand Main Stim into cell-array of stim:
            stim_paths = get_stim(config_struct(row));
            num_stim = length(stim_paths);
            
            % Expand Pre-Stim & Post-Stim into cell-array of stim:
            [pre_stim_paths, post_stim_paths, num_pp] = get_pp_stim(config_struct(row));
            
            % How to draw stim?
            stim_order = select_draw_method(config_struct, row, num_stim, num_pp, expanded_elem);
            
            % For each row in the unexpanded struct:
            for t = 1:length(expanded_elem)
                
                % Get new struct length/existence:
                if exist('new_struct','var')
                    len = length(new_struct);
                else
                    len = 0;
                end
                
                % Get Question/Stim to add, according to stim_order:
                [pp_ind, stim_ind] = ind2sub([num_pp num_stim], stim_order(t) );
                
                % Insert a row into new struct:
                new_struct(len+1) = config_struct(row);  %#ok<AGROW>
                new_struct(len+1).('TrialNum') = expanded_elem(t); %#ok<AGROW>
                % place the proper value in that row (e.g., replace
                % '1:2:36' with 1,3,5,..., etc.)
                
                % Place the proper value for 'stimuli' (e.g.,
                % specific filepath replaces folder path, specific msg replaces cellarray)
                new_struct(len+1).('Stim') = stim_paths{stim_ind}; %#ok<AGROW>
                
                if isfield(config_struct, 'PreStim')
                    new_struct(len+1).('PreStim') = pre_stim_paths{pp_ind}; %#ok<AGROW>
                end
                if isfield(config_struct, 'PostStim')
                    new_struct(len+1).('PostStim')  = post_stim_paths{pp_ind}; %#ok<AGROW>
                end
                
            end % end element-expanding loop
            
        end % end 'for each row in non-expanded struct' loop
        
    end % end func

%% Choose Stim Order based on Draw method:
    function [stim_order] = select_draw_method(config_struct, row, num_stim, num_pp, expanded_elem)
        
        draw_meth = get_trial_config(config_struct(row), 'StimDrawFromFolderMethod');
        if num_stim < 2 && ~isempty(draw_meth) && ~strcmpi(draw_meth, 'asc')
            msg = ['You have selected a "StimDrawFromFolderMethod" for a trial, but the ' ...
                'stim for that trial is not a folder. Ignoring.'];
            warning(msg); %#ok<WNTAG>
            log_msg(msg);
            draw_meth = 'asc';
        end
        switch lower(draw_meth)
            case 'asc'
                stim_order = repv(1:(num_stim*num_pp), length(expanded_elem) );
            case 'desc'
                stim_order = repv(1:(num_stim*num_pp), length(expanded_elem) );
                stim_order = stim_order(end:-1:1); % reverse!
            case 'sample'
                stim_order = randsample_stim_order(num_pp, num_stim, length(expanded_elem), 0 );
            case 'sample_consec'
                stim_order = randsample_stim_order(num_pp, num_stim, length(expanded_elem), 1 );
            case 'sample_replace'
                stim_order = randsample(num_pp * num_stim, length(expanded_elem), 0);
            otherwise
                stim_order = 1:length(expanded_elem);
        end
        
    end

%% Repeat vector:
    function [out] = repv(vec, length_out)
        repvec = repmat(vec, 1, ceil(length_out/length(vec)));
        out = repvec(1:length_out);
    end

%% Randomly Sample Stimuli Ordering:
    function [stim_order_rs] = randsample_stim_order(num_pp, num_stim, num_trials, consec_allowed)
        if num_trials > num_stim
            if mod(num_trials, (num_stim*num_pp)) ~= 0 % num trials / num_stim is whole num
                msg = ['If randomly sampling without replacement, and number of trials is greater than ' ...
                    'number of stimuli, then number of trials must be an even multiple of number ' ...
                    'of stimuli. However, on one of your trials, you have ' num2str(num_stim*num_pp) ...
                    ' stimuli, and ' num2str(num_trials) ' trials.'];
                error(msg);
            end
        end
        
        if consec_allowed
            stim_order_rs = randsample_with_bigger(num_pp*num_stim, num_trials);
        else
            
            if num_trials > 2
                disp('stop');
            end
            
            if num_trials > (num_stim*num_pp)
                stim_hashes = sort( repv(1:num_stim, num_trials) )
                trials = 1:num_trials; 
                stim_order = sort( repv(1:(num_stim*num_pp), num_trials) ); 
                rsi = shuffle_no_consec(trials, stim_hashes);
                stim_order_rs = stim_order(rsi);
            else
                stim_hashes = sort( repv(1:num_stim, (num_stim*num_pp)) );
                trials = 1:num_trials;
                stim_order_rs = shuffle_no_consec(trials, stim_hashes);
                stim_order_rs = stim_order_rs( 1:(num_stim*num_pp) ); % take subset
            end
            
            [pp_ind, stim_ind] = ind2sub([num_pp num_stim], stim_order_rs);
            
        end

    end

%% Randsample where k can be bigger than n:
    function [y] = randsample_with_bigger(n,k)
        if k > n
            population = repmat(1:n, 1, k/n);
        else
            population = 1:n;
        end
        y = randsample(population, k);
    end


%% Parse Stim Column:
    function [stim_paths] = get_stim(trial_config, stim_position)
        if nargin < 2
            stim_position = '';
        end
        
        stim_field = get_trial_config(trial_config, [stim_position 'Stim']);
        need_a_path = any( strcmpi(get_trial_config(trial_config, [stim_position 'StimType']), {'video', 'image'}) );
        stim_paths = parse_stim_field(stim_field, need_a_path, 1);
        
    end

    function [stim_paths] = parse_stim_field(stim_field, need_a_path, top_call)
        
        if nargin < 3
            top_call = 0;
        end
        
        if isdir(stim_field)
            % it's a directory
            stim_paths = comb_dir(stim_field, 1);
            return
        end
        
        if exist(stim_field, 'file')
            % it's a filepath
            if top_call
                stim_paths = {stim_field};
            else
                stim_paths = stim_field;
            end
            return
        end
        
        try
            % maybe it's a cell array of paths/directories
            eval_attempt = eval_field(stim_field);
            if iscell(eval_attempt)
                stim_paths = cellfun(@(x)parse_stim_field(x,need_a_path), eval_attempt);
                return
            else
                if isempty(eval_attempt)
                    stim_paths = {''};
                else
                    if top_call
                        stim_paths = {eval_attempt};
                    else
                        stim_paths = eval_attempt;
                    end
                end
            end
        catch err %#ok<NASGU>
            if need_a_path
                error(sprintf(['One of your trials needs a path to a stim or stim-directory, '...
                    'but this could not be parsed from the following stim_config.txt entry: \n' ...
                    stim_field]) ); %#ok<SPERR>
            else
                if top_call
                    stim_paths = {stim_field};
                else
                    stim_paths = {stim_field};
                end
            end
            return
        end
        
    end



%% Get Pre&Post Stim
    function [pre_stim_paths, post_stim_paths, num_pp] = get_pp_stim(trial_config)
        
        pre_stim_paths = get_stim(trial_config, 'Pre');
        post_stim_paths = get_stim(trial_config, 'Post');
        
        all_stim_paths = {pre_stim_paths post_stim_paths};
        singular_path = cellfun(@(x)length(x)==1, all_stim_paths);
        
        if ~all(singular_path)
            % not all are empty/singular?
            if any(singular_path)
                % one of them is?
                % make empty one into cell array with length of nonempty
                all_stim_paths{singular_path} = repmat(all_stim_paths{singular_path}, 1, length(all_stim_paths{~singular_path}) );
                
            else
                % neither of them is
                % confirm they're same length
                if length(all_stim_paths{1}) ~= length(all_stim_paths{2})
                    log_msg(['If the PreStim for a trial is a cell array, then the' ...
                        'PostStim must be a cell array of the same length. And vice versa.'])
                    log_msg('Check your stim_config.txt file.')
                    error('See above.');
                end
            end
        end
        
        pre_stim_paths = all_stim_paths{1};
        post_stim_paths = all_stim_paths{2};
        num_pp = length(post_stim_paths); % have same length
        return
    end

end