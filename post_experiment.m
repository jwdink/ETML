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

% Close EL
try
    if aborted
        Eyelink('StopRecording');
    end
    Eyelink('closefile');
    log_msg(sprintf('Receiving data file "%s"', session.edf_file ));
    status = Eyelink('ReceiveFile');
    if status > 0
        log_msg(sprintf('ReceiveFile status %d', status));
    end
    Eyelink('ShutDown');
catch  err
    warning(err.message)
    log_msg(err.message)
end

% Get Comments:
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

% Add session Info:
[ year, month, day, hour, minute, sec ] = datevec(now);
end_time = ...
    [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];

sfnames= fieldnames(session);
for i = 1:length(sfnames)
    this_field = sfnames{i};
    if ~ strcmpi(this_field, {'data', 'config', 'fileID', 'skip_comments', 'this_phase', 'win_rect', 'keys_of_interest'})
        results(length(results) + 1).key = this_field;
        results(length(results)).value   = session.(this_field);
    end
end
results(length(results) + 1).key = 'end_time';
results(length(results)).value = end_time;
results(length(results) + 1).key = 'Comments';
results(length(results)).value = comments{1};

% Add in data:
for i = 1:length(session.data)
    results(length(results) + 1).key = session.data(i).key;
    
    % remove any quotes in value that will screw up log file:
    val = session.data(i).value;
    if ischar(val)
        val = strrep(val, char(39), '');
        val = strrep(val, char(34), '');
    end
    
    results(length(results)).value = val;
end

% save session file
filename = [session.base_dir '/sessions/' session.subject_code '.txt'];
log_msg(sprintf('Saving results file to %s',filename));
WriteStructsToText(filename,results)

if aborted
    error('Experiment Ended.')
end

end
