%% FXN_get_video_events_from_user
function [keyframe_sqs, s, sdim] = get_video_events_from_user(trial_index, trial_config)

if isempty(keyframe_sqs)
    keyframe_sqs = cell(10,1);
end

% Open Movie(s):
[movie mov_dur fps imgw imgh] = Screen('OpenMovie', wind, [base_dir this_stim] );
sdim = [imgw imgh];
Screen('SetMovieTimeIndex', movie, 0);
Screen('PlayMovie', movie, 0);
ts = 0;
incr = 1/fps;
frame = 1;
total_frames = int64( fps * mov_dur );

% Init:
IA_mat = zeros(total_frames, 4);
this_frame_IA = IA_mat(frame, :);
inclick = 0;
clicking_in_box = 0;
pt1 = [0 0];
pt2 = [0 0];
unregistered_IA = [pt1 pt2];
cursor_offset = [0 0];
keycode = check_keypress();

IA_number = 1;

while 1
    
    % Get keypress:
    keycode = check_keypress(keycode);
    keyname = KbName(keycode);
    if iscell(keyname)
        keyname = keyname{1};
    end
    
    % Change frame based on keypress:
    last_frame = frame;
    [ts, frame] = control_frame(keyname, ts, frame);
    if last_frame ~= frame
        % Reload IA:
        this_frame_IA = IA_mat(frame, :);
        % Clear selection:
        pt1 = [0 0]; pt2 = [0 0];
        unregistered_IA = [0 0 0 0];
    end
    
    % Get Movie texture:
    tex = Screen('GetMovieImage', wind, movie,  0, ts);
    tex_rect = Screen('Rect', tex);
    Screen('DrawTexture', wind, tex, [], tex_rect);
    
    % Draw text:
    DrawFormattedText(wind,['IA:' num2str(IA_number)]);
    
    % Check keyframes:
    kf_sqs = keyframe_sqs{IA_number};
    if ~isempty(kf_sqs)
        keyframes = kf_sqs(:,5);
    else
        keyframes = [];
    end
    
    % Get Mouse:
    [x,y,buttons] = GetMouse(wind);
    
    % Create IA based on Command-Click:
    if strcmpi(keyname, 'LeftGUI') && ~clicking_in_box
        [inclick, pt1, pt2] = draw_IA(x, y, buttons, inclick, pt1, pt2);
        unregistered_IA = pts_to_box(pt1,pt2);
    else
        % Move Any IAs Based on Click:
        [clicking_in_box, unregistered_IA, this_frame_IA, cursor_offset] =...
            move_IA(x, y, buttons, clicking_in_box, unregistered_IA, this_frame_IA, cursor_offset);
        pt1 = unregistered_IA(1:2);
        pt2 = unregistered_IA(3:4);
    end
    
    % Draw IAs:
    draw_box(unregistered_IA, wind, [100 100 100]);
    if ismember(frame, keyframes)
        draw_box(this_frame_IA,   wind, [0 255 0]);
    else
        draw_box(this_frame_IA,   wind, [0 100 0]);
    end
    
    % If they press enter or space:
    if strcmpi(keyname, 'Return') || strcmpi(keyname, 'Space')
        while KbCheck; end
        if     max(unregistered_IA)
            % Register drawn IA:
            keyframe_sqs{IA_number} = register_IA(keyframe_sqs{IA_number}, unregistered_IA, frame);
        elseif max(this_frame_IA)
            % Re-register IA:
            keyframe_sqs{IA_number} = register_IA(keyframe_sqs{IA_number}, this_frame_IA, frame);
        end
        
        if max([unregistered_IA this_frame_IA])
            % Re-interpolate IAs:
            IA_mat = interpolate_sqs(keyframe_sqs{IA_number}, total_frames);
            this_frame_IA = IA_mat(frame, :);
        end
        
        % Clear selection:
        pt1 = [0 0]; pt2 = [0 0];
        unregistered_IA = [0 0 0 0];
    end
    
    % If they press delete:
    if strcmpi(keyname, 'DELETE')
        % Delete KF:
        ind = find(frame == keyframes);
        if ~isempty(ind)
            kf_sqs(ind,:) = [];
            keyframe_sqs{IA_number} = kf_sqs;
            % Re-interpolate IAs:
            if isempty(kf_sqs)
                IA_mat = zeros(total_frames, 4);
            else
                IA_mat = interpolate_sqs(keyframe_sqs{IA_number}, total_frames);
            end
            this_frame_IA = IA_mat(frame, :);
        end
    end
    
    % If they press Arrow keys:
    if strcmpi(keyname, 'RightArrow') || strcmpi(keyname,'LeftArrow')
        while KbCheck; end
        
        % next or prev IA:
        if     strcmpi(keyname, 'RightArrow')
            IA_number = IA_number + 1;
        elseif strcmpi(keyname,'LeftArrow')
            IA_number = IA_number - 1;
        end
        
        % wraparound:
        if IA_number == 11
            IA_number = 1;
        elseif IA_number == 0;
            IA_number = 10;
        end
        
        % Clear selection:
        pt1 = [0 0]; pt2 = [0 0];
        unregistered_IA = [0 0 0 0];
        
        % Reload IAs
        if isempty(keyframe_sqs{IA_number})
            IA_mat = zeros(total_frames, 4);
        else
            IA_mat = interpolate_sqs(keyframe_sqs{IA_number}, total_frames);
        end
        this_frame_IA = IA_mat(frame, :);
    end
    
    % If they press tab:
    if strcmpi(keyname,'Tab')
        s = s + 1;
        break
    end
    
    % Send to screen:
    Screen('Close', tex);
    Screen('Flip', wind, 0, 0);
    
end % end movie loop

% Close Movie:
Screen('CloseMovie', movie);
Screen('Flip', wind);
check_keypress(keycode, 1); % flush currently pressed keys

    function [ts, frame] = control_frame(keyname, ts, frame)
        if     strcmpi(keyname,'s')
            ts = ts + incr;
            frame = frame + 1;
        elseif strcmpi(keyname,'a')
            ts = ts - incr;
            frame = frame - 1;
        end
        if ts < 0
            ts = 0;
        elseif ts > mov_dur
            ts = mov_dur;
        end
        if frame < 1
            frame = 1;
        elseif frame > total_frames
            frame = total_frames;
        end
    end
end

