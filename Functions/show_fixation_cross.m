function show_fixation_cross(wind, dim, fix_time, pre_delay)
%%
global session

if nargin <2
    dim = 50;
end
if nargin <3
    fix_time = .25;
end
if nargin < 4
    pre_delay = .25;
end

imgmat = make_cross(dim, [0 0 0]);
dest_rect = CenterRect([0 0 dim dim], session.win_rect);

log_msg('Showing fixation cross');
fix_start = GetSecs();
while 1
    tex = Screen('MakeTexture', wind, imgmat);
    Screen('DrawTexture', wind, tex, [], dest_rect);
    Screen('Flip',wind);
    
    %% Change me:
    if GetSecs() - fix_start > pre_delay
        [~,~,code] = KbCheck();
        if max( strcmpi(KbName(code), 'space') ) || max( strcmpi(KbName(code), 'Escape') )
            break
        end
    end
    %%%%
end
log_msg('Done showing fixation cross');

end

%%
function [imgmat] = make_cross(dim, rgb, wid)
dim = dim(1);

if length(rgb) < 4
    rgb(4) = 255;
end
if nargin < 3
    wid=1;
end

% Make Mask:
mask = zeros(dim);
inds = round((dim * (6-wid)/12):(dim * (6+wid)/12));
if inds < 1
    imgmat = zeros(dim, dim, 4);
    return % cross is so small it's invisible
end
inds = [inds inds(end)+1];
mask(:,inds) = 1;
mask(inds,:) = 1;

% Make Matrix:
imgmat(:,:,1) = ones(dim) * rgb(1);  % Red plane
imgmat(:,:,2) = ones(dim) * rgb(2);  % Green plane
imgmat(:,:,3) = ones(dim) * rgb(3);  % Blue plane
imgmat(:,:,4) = mask      * rgb(4);  % Alpha plane
end