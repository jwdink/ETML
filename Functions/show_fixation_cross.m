function show_fixation_cross(wind, dim, fix_time, pre_delay)
%%
global session
global el

if nargin <2
    dim = 50;
end
if nargin <3
    fix_time = .25;
end
if nargin < 4
    pre_delay = .5;
end

%
dummy_mode = session.dummy_mode;
esc_key = KbName('Escape');

% Check Eye:
eye_used = Eyelink('EyeAvailable'); % get eye that's tracked
if eye_used == el.BINOCULAR; % if both eyes are tracked
    eye_used = el.LEFT_EYE; % use left eye
end

% Prep Screen:
bg_col = session.background_color;
imgmat = make_cross(dim, [0 0 0]);
dest_rect = CenterRect([0 0 dim dim], session.win_rect);
tex = Screen('MakeTexture', wind, imgmat);

log_msg('Showing fixation cross');

disp_start = GetSecs();
while 1
    
    Screen('FillRect', wind, bg_col);
    Screen('DrawTexture', wind, tex, [], dest_rect);
    Screen('Flip',wind);
    
    % Get Keypress:
    [~,~,key_code] = KbCheck();
    if any(key_code)
        disp(KbName(key_code));
    end
    if key_code(esc_key) % they press the esc key
        log_msg('Calibration started.');
        EyelinkDoTrackerSetup(el);
        log_msg('Calibration finished.');
        WaitSecs(.1);
        disp_start = GetSecs();
    end
    
    
    % Get eye position:
    if dummy_mode
        [mx,my,~] = GetMouse( wind );
    else
        if Eyelink('NewFloatSampleAvailable') > 0
            % get the sample in the form of an event structure
            evt = Eyelink( 'NewestFloatSample');
            % if we do, get current gaze position from sample
            x = evt.gx(eye_used+1); % +1 as we're accessing MATLAB array
            y = evt.gy(eye_used+1);
            % do we have valid data and is the pupil visible?
            if x~=el.MISSING_DATA && y~=el.MISSING_DATA && evt.pa(eye_used+1)>0
                mx=x;
                my=y;
            else
                mx=NaN;
                my=NaN;
            end
        else
            mx=NaN;
            my=NaN;
        end
    end
    
    % they don't qualify as fixating if
    if ~IsInRect(mx,my,dest_rect) || ...          % they are not in the rectangle OR
            (GetSecs() - disp_start < pre_delay)  % the screen just came up
        last_time_they_werent_fixating = GetSecs();
    end
    
    % end on long enough fixation
    % disp(mx);
    if GetSecs() - last_time_they_werent_fixating > fix_time
        break
    end
    
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