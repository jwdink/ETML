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
Eyelink('StopRecording');
Eyelink('closefile');

try
    fprintf('Receiving data file ''%s''\n', session.edf_file );
    status = Eyelink('ReceiveFile');
    if status > 0
        fprintf('ReceiveFile status %d\n', status);
    end
catch my_err
    log_msg(sprintf('Problem receiving data file ''%s''\n', session.edf_file ));
    log_msg(my_err.message);
    log_msg(num2str([my_err.stack.line]));
end

Eyelink('ShutDown');

if ~aborted
    % get experimenter comments
    comments = inputdlg('Enter your comments about attentiveness, etc.:','Comments',3);
    if isempty(comments)
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
    filename = [session.base_dir 'sessions/' subject_code '.txt'];
    log_msg(sprintf('Saving results file to %s',filename));
    WriteStructsToText(filename,results)
else
    disp('Experiment aborted - results file not saved, but there is a log.');
    error('Experiment Ended.');
end

end
