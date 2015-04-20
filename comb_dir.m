%% FXN_comb_dir
function [paths] = comb_dir (directory, hierarchical)
% Recursive folder look-up
if nargin<1
    directory = cd;
end
if nargin<2
    hierarchical = 0;
end

if directory(end)=='/'
    directory = directory( 1 : (length(directory)-1) );
end

dirinfo = dir(directory);
tf = ismember( {dirinfo.name}, {'.', '..'});
dirinfo(tf) = [];  %remove current and parent directory.

paths={};

for f_ind=1:length(dirinfo)
    
    if dirinfo(f_ind).isdir==1
        if hierarchical==1
            addMe=comb_dir([directory '/' dirinfo(f_ind).name],1);
            if ~isempty(addMe) % if the folder was empty, stop. otherwise, add it to the list
                %if ~iscell(addMe{1}); addMe={addMe};end;
                paths{end+1} = addMe; %#ok<AGROW>
            end
        else
            paths=[paths comb_dir([directory '/' dirinfo(f_ind).name])]; %#ok<AGROW>
        end
    else
        if ~strcmpi(dirinfo(f_ind).name,'.DS_Store')
            pathToFile= [directory '/' dirinfo(f_ind).name];
            paths=[paths pathToFile]; %#ok<AGROW>
        end
    end
end

end