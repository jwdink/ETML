%% FXN_log_msg
function log_msg (msg, this_phase)
global session

fprintf('\n# %s\n',msg);
if nargin < 2
    % if this_phase is not given, then message will not be sent to
    % eyetracker
    this_phase = [];
end

% remove any quotes in value that will screw up log file:
% (think about removing this if speed is big priority)
msg = strrep(msg, char(39), '');
msg = strrep(msg, char(34), '');

session.fileID = fopen([ 'logs/' session.subject_code '-' session.start_time '.txt'],'a');

[ year, month, day, hour, minute, sec ] = datevec(now);
timestamp = [num2str(year) '-' num2str(month) '-' num2str(day) ...
    ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];

fprintf(session.fileID,'%s \t%s\n',timestamp,msg);
fclose(session.fileID);

if session.record_phases(this_phase)
    Eyelink('Message',msg);
end

end