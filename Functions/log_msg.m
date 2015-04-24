%% FXN_log_msg
function log_msg (msg)

% This function is not optimized for speed, since it depends on global variables
% Consider changing this in the future?
global session

if ~ischar(msg)
    warning('MATLAB:narginchk','You''ve passed a non-char argument to log_msg.');
    msg= num2str(msg);
end

fprintf('\n# %s\n', msg);

% remove any quotes in value that will screw up log file:
msg = strrep(msg, char(39), '');
msg = strrep(msg, char(34), '');

session.fileID = fopen([ 'logs/' session.subject_code '-' session.start_time '.txt'],'a');

[ year, month, day, hour, minute, sec ] = datevec(now);
timestamp = [num2str(year) '-' num2str(month) '-' num2str(day) ...
    ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];

fprintf(session.fileID,'%s \t%s\n',timestamp,msg);
fclose(session.fileID);

if any( strcmpi('this_phase', fieldnames(session)) )
    if session.record_phases(session.this_phase)
        Eyelink('Message',msg);
    end
end


end