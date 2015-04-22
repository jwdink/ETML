function [ new_trial_index, out_struct, key_summary ] = ...
    custom_function(wind, trial_index, trial_config, out_struct, key_summary) 
%CUSTOM_FUNCTION Run a custom trial within an ETML experiment
%   [new_trial_index, out_struct = custom_function(wind, trial_index, trial_config, out_struct) 
%   runs a custom script, which can be specific to each experiment. Simply
%   copy this template into the base directory of your experiment.
%
%   To save any information about the trial, you have a few options. You
%   still have access to the log_msg and add_data functions. These will
%   save your data to the tab-delimited text files where all other data is
%   stored-- and on trials where the ET is recording, these functions will
%   also send your data to the eyetracker. If you want to save keypress
%   information, you should use check_keypress, which automatically saves
%   key pressed and released messages to the log (and eyetracker when
%   recording). Finally, if the data is particularly unique or oddly
%   formatted, you can write data to a file yourself. For a tutorial on
%   this, see:
%   http://wiki.stdout.org/matlabcookbook/File%20IO/Writing%20data%20to%20a%20file
%
%   This function gives you access to several useful experiment variables. 
%
%   'WIND' is the Psych Toolbox window. 
%
%   'TRIAL_INDEX' is the number of the trial we're on within the
%   block/phase.
%
%   'TRIAL_CONFIG' is a struct containing all relevant information about
%   the trial. In show_vid or show_img, the 'stimuli' field would be a path
%   to the media being presented, but here it can be used to make your
%   custom function do different things on different trials (e.g., 'if
%   trial_config.('Stimuli') == 'custom_1' ...). Or you can use the
%   phase/block/trial fields to do so-- it's all up to you (that's the
%   point of a custom function). Note that trial_index is not the same as
%   trial_config('Trial'), if the block is randomized: the former
%   corresponds to presentation order, the latter corresponds to the trial
%   number (as used in the stim_config.txt file).
%
%   'OUT_STRUCT' is a structure to which you can assign anything that you'd
%   like to persist from trial-to-trial. For example, if what they see on
%   trial n depends on how they performed on trial n-1, you could use the
%   command 'out_struct.performance = this_trial_performance' on trial n-1
%   and access out_struct.performance on trial n.
%
%   'KEY_SUMMARY' is a structure which you can pass to 'check_keypress'. At 
%   the end of the trial, information about keys of interest will be summarized
%   and added to the data
%
%   In this function don't forget to change the trial index. The default
%   template code below simply advances the trial.


global session  % struct w/useful information about this session; you should not modify
global el       % struct w/useful information about the eyetracker; you should not modify

% %
%
% Your Code goes here.
% 
% %

new_trial_index = trial_index + 1; % this can be modified; e.g., for possibility of going backward thru trials

end

