%% FXN_is_in_cellarray
function [out] = is_in_cellarray(strs, cellarray)
if ischar(strs)
    strs = {strs};
end

out = zeros(1,length(strs));
for i = 1:length(strs)
    str = strs{i};
    out(i) = ~isempty(which_cell(str, cellarray));
end

end