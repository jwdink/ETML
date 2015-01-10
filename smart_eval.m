%% FXN_smart_eval
function [value] = smart_eval (input)
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