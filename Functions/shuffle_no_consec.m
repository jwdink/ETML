function [shuffle_out] = shuffle_no_consec(trials, stim_hashes)
%% 1. Shuffle Trials w/o Shuffling Stim:
% First, we shuffle within each stim. So if a stim appears three times, each with different
% attributes (e.g., different pre-stim, different timing, etc.), this will shuffle those the order
% of appearance of those attributes, but keep that stim appearing on the same trials.

trials_shuffled1 = trials;
unique_stim = unique(stim_hashes);

for this_stim = unique_stim
    this_stim_ind = find(stim_hashes==this_stim);
    this_stim_trials = trials_shuffled1(this_stim_ind);
    trials_shuffled1(this_stim_ind) = this_stim_trials(randperm(length(this_stim_trials)));
end

%% 2. Shuffle Stim
% Draw each trial from the pool of trials, with the contstraint that a given stim cannot
% appear twice in a row.

while 1
    failed = 0;
    trials_shuffled2 = NaN(1,length(trials_shuffled1));
    stim_pool = stim_hashes;
    trials_pool = trials_shuffled1;
    for ti = 1:length(trials)
        if ti == 1;
            
            % Pick random trial:
            ti_to_pick = randi(length(trials));
            
            % Get Stim, Remove from Pool:
            last_stim = stim_pool(ti_to_pick);
            stim_pool(ti_to_pick) = [];
            
            % Get Trial, Remove from Pool:
            trials_shuffled2(ti) = trials_pool(ti_to_pick);
            trials_pool(ti_to_pick) = [];
            
        else
            
            % Pick random trial with acceptable stim:
            tis = 1:length(trials_pool);
            avail_tis = tis(stim_pool ~= last_stim);
            if isempty(avail_tis)
                failed = 1;
            else
                if length(avail_tis)==1
                    ti_to_pick = avail_tis;
                else
                    ti_to_pick = randsample(avail_tis,1);
                end
                
                % Get Stim, Remove from Pool:
                last_stim = stim_pool(ti_to_pick);
                stim_pool(ti_to_pick) = [];
                
                % Get Trial, Remove from Pool:
                trials_shuffled2(ti) = trials_pool(ti_to_pick);
                trials_pool(ti_to_pick) = [];
            end
            
        end
        
    end
    
    if ~failed
        break
    end
    
end

shuffle_out = trials_shuffled2;

end