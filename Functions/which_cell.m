%% FXN_which_cell
function [ out ] = which_cell( str, cellarray )
ind = strfind(cellarray, str);
out = find(not(cellfun('isempty', ind)));
end
