%% FXN_post_experiment
function post_experiment (aborted)

global session

log_msg('Experiment ended');

ShowCursor();

sca;

ListenChar(0);
Screen('CloseAll');
Screen('Preference', 'SuppressAllWarnings', 0);

commandwindow;

% Close EL (I'm not proud of this code):
try
    if aborted
        Eyelink('StopRecording');
    end
    
    Eyelink('closefile');
    try
        log_msg(sprintf('Receiving data file "%s"', session.edf_file ));
        status = Eyelink('ReceiveFile');
        if status > 0
            log_msg(sprintf('ReceiveFile status %d', status));
        end
    catch my_err
        log_msg(sprintf('Problem receiving data file ''%s''\n', session.edf_file ));
        log_msg(my_err.message);
        log_msg(num2str([my_err.stack.line]));
    end
    Eyelink('ShutDown');
catch  %#ok<CTCH>
    disp(['There seems to have been a problem shutting down the eyelink '...
        'system-- session txt file has not been generated.']);
    error('Experiment Ended.');
end


% Save session data:
if ~(session.skip_comments || session.debug_mode)
    % get experimenter comments
    comments = inputdlg('Enter your comments about attentiveness, etc.:','Comments',3);
    if isempty(comments)
        comments = {''};
    end
else
    comments = {''};
end

% create empty structure for results
results = struct('key',{},'value',{});

[ year, month, day, hour, minute, sec ] = datevec(now);
end_time = ...
    [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];

results(length(results) + 1).key = 'Start Time';
results(length(results)).value = session.start_time;
results(length(results) + 1).key = 'End Time';
results(length(results)).value = end_time;
results(length(results) + 1).key = 'Experimenter';
results(length(results)).value = session.experimenter;
results(length(results) + 1).key = 'Subject Code';
results(length(results)).value = session.subject_code;
results(length(results) + 1).key = 'Condition';
results(length(results)).value = session.condition;
results(length(results) + 1).key = 'Comments';
results(length(results)).value = comments{1};

% merge in data
for i = 1:length(session.data)
    results(length(results) + 1).key = session.data(i).key;
    results(length(results)).value = session.data(i).value;
end

% save session file
filename = [session.base_dir '/sessions/' session.subject_code '.txt'];
log_msg(sprintf('Saving results file to %s',filename));
WriteStructsToText(filename,results)

if aborted
    error('Experiment Ended.')
end

end
