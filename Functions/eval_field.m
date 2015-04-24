%% FXN_eval_field
function [value] = eval_field (field)
% Takes text from a config file, as read in by ReadStructsFromTextW.
% If it's a number, we're done.
% If it's a MATLAB expression, it'll often be wrapped in quotes we need to strip

% TO FIX: how does this act when [you want it to be] a string?

if isempty(field)
    value = [];
    return
end

if ischar(field)
    
    % Strip Leading, Trailing, and Excess Quotes:
    if strcmp(field(1),'"')
        field = field(2:end);
    end
    if strcmp(field(end), '"')
        field = field(1:(end-1));
    end
    
    % Evaluate, Return:
    field = strrep(field, '""', '''');
    value = eval(field);
    return
    
else
    value = field;
end


end