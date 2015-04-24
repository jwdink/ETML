%% FXN_get_config
function [value] = get_config (name, default)

global session

if nargin < 2
    default = [];
end

matching_param = find(cellfun(@(x) strcmpi(x, name), {session.config.Parameter}));
value = [session.config(matching_param).Setting]; %#ok<FNDSB>

% replace quotes so we get pure values
if ischar(value) || iscell(value)
    value = strrep(value, '"', '');
end

if isempty(value)
    if strcmpi(default, 'error')
        error(['Your config file must specify ' name])
    else
        value = default;
    end
end

end