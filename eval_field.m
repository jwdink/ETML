%% FXN_eval_field
function [value] = eval_field (input)
% Takes text from a config file, as read in by ReadStructsFromTextW.
% If it's a number, we're done.
% If it's a MATLAB expression, it'll often be wrapped in quotes we need to strip

% TO FIX: how does this act when [you want it to be] a string?


if ischar(input)
    input = strrep(input, '"', ''); 
    if isempty(input)
        value = [];
    else
        value = eval(input);
    end
else
    value = input;
end


end