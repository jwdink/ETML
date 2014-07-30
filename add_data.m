%% FXN_add_data
function add_data (data_key, data_value, this_phase)

global session

if nargin < 3
    this_phase = [];
end

session.data(length(session.data) + 1).key = data_key;
session.data(length(session.data)).value = data_value;

if isnumeric(data_key)
    data_key = num2str(data_key);
end
if isnumeric(data_value)
    data_value = num2str(data_value);
end
log_msg(sprintf('%s : %s',data_key, data_value));
if session.record_phases(this_phase)
    WaitSecs(.002);
    Eyelink('Message','!V TRIAL_VAR %s %s', data_key, data_value);
end
end
