%% Recursive folder look-up

function[paths] = combDir(directory,hierarchical)

if nargin<1
    directory=cd;
end
if nargin<2
    hierarchical=0;
end

if directory(end)=='/'
    directory = directory( 1 : (length(directory)-1) );
end

dirinfo = dir(directory);
tf = ismember( {dirinfo.name}, {'.', '..'});
dirinfo(tf) = [];  %remove current and parent directory.

paths={};

for i=1:length(dirinfo)
    
    if dirinfo(i).isdir==1
        if hierarchical==1
            addMe=combDir([directory '/' dirinfo(i).name],1);
            if ~isempty(addMe) % if the folder was empty, stop. otherwise, add it to the list
                 %if ~iscell(addMe{1}); addMe={addMe};end;
                paths{end+1}=addMe; %#ok<AGROW>
            end
        else
            paths=[paths combDir([directory '/' dirinfo(i).name])]; %#ok<AGROW>
        end
    else
        if ~strcmpi(dirinfo(i).name,'.DS_Store')
            pathToFile= [directory '/' dirinfo(i).name];
            paths=[paths pathToFile]; %#ok<AGROW>
        end
    end
end

end
