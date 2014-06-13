function [my_err] = anim ()
%% TO DO
% - fix image settings: each one should be a separate recording
% - fix interest areas: should be able to set diff ones for each block and stim,
% not just each phase
% - is kb_code length = 256 regardless of OS?
my_err = [];
try
%% LOAD CONFIGURATION %%

% get experiment directory
base_dir = [ uigetdir([], 'Select experiment directory') '/' ];

% load the tab-delimited configuration file
config = ReadStructsFromTextW([base_dir 'config.txt']);

sprintf('You are running %s\n\n',get_config('StudyName'));

%% SET UP EXPERIMENT AND SET SESSION VARIABLES %%

% Tell matlab to shut up, and seed it's random numbers
warning('off','all');
random_seed = sum(clock);
rand('twister',random_seed); %#ok<RAND>
PsychJavaTrouble;
commandwindow;

% Get Date/Time
[ year, month, day, hour, minute, sec ] = datevec(now);
start_time =...
    [num2str(year) '-' num2str(month) '-' num2str(day) ...
    ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];

% Get subject code
dummy_mode = get_config('DummyMode'); % not tracking eyes
debug_mode = get_config('DebugMode'); % debugging tools (e.g. windowed)
if ~debug_mode
    experimenter = input('Enter your (experimenter) initials: ','s');
    subject_code = input('Enter subject code: ', 's');
    condition = input('Enter condition: ', 's');
    condition = str2double(condition);
else
    experimenter = 'null';
    subject_code = '0';
    condition = randi(get_config('NumConditions'));
end

% Begin logging now, because we have the subject_code
create_log_file();
log_msg(sprintf('Set base dir: %s',base_dir));
log_msg('Loaded config file');
log_msg(sprintf('Study name: %s',get_config('StudyName')));
log_msg(sprintf('Random seed set as %s via "twister"',num2str(random_seed)));
log_msg(sprintf('Start time: %s',start_time));
log_msg(sprintf('Experimenter: %s',experimenter));
log_msg(sprintf('Subject Code: %s',subject_code));
log_msg(sprintf('Condition: %d ',condition));

% Initiate data structure for session file
data = struct('key',{},'value',{});

% Load in stimuli
cd(base_dir);
stimuli_paths = comb_dir(get_config('StimuliFolder'), 1);

num_phases = get_config('NumPhases'); 

% Num blocks per phase (if config has single number, assume same for all)
num_blocks = eval(get_config('NumBlocks')); 
if isempty(num_blocks); num_blocks = 1; end;
if length(num_blocks) == 1
    num_blocks = repmat(num_blocks,[1 num_phases]);
end

% Stim ordering thru phases (if nothing specified, assume phase_num = stim_num)
stim_order = eval(get_config('StimuliOrder'));
if isempty(stim_order)
    stim_order = 1:num_phases;
end

% Change within/per phase (if config has single number, assume same for all)
to_change_each_block = eval(get_config('ToChangeOnBlock'));
if isempty(to_change_each_block); to_change_each_block = ''; end;
if length(to_change_each_block) == 1
    to_change_each_block = repmat({to_change_each_block},[num_phases 1]);
end
default_stim_val = eval(get_config('ToChangeOnBlock_DefaultVal'));
change_stim_angle =...
    cell2mat(cellfun(@(x) strcmpi('flip',x), to_change_each_block, 'UniformOutput',false));
if length(change_stim_angle) < num_blocks
    padarray(change_stim_angle,[0 num_blocks-length(change_stim_angle)],0,'post')
end

% Interest Areas
IA_struct = ReadStructsFromTextW('interest_areas.txt');

% Key controls
next_key = get_config('NextIMGKey');
prev_key = get_config('PrevIMGKey');
interval = get_config('NextIMGTime');

% Create folder for dv-imgs
mkdir('data', subject_code);

% Wait for experimenter to press Enter to begin
disp(upper(sprintf('\n\nPress any key to launch the experiment window\n\n')));
KbWait([], 2);

log_msg('Experimenter has launched the experiment window');

%% SET UP SCREEN %%

if dummy_mode
    % skip sync tests for faster load
    Screen('Preference','SkipSyncTests', 1);
    log_msg('Running in DebugMode');
else
    % shut up
    Screen('Preference', 'SuppressAllWarnings', 1);
    log_msg('Not running in DebugMode');
    % disable the keyboard
    ListenChar(2);
    HideCursor();
end

% Create window
bg_color = get_config('BackgroundColor');
background_color = [bg_color bg_color bg_color];
resolution = eval(get_config('ScreenRes'));
if dummy_mode
    refresh_rate = [];
else
    refresh_rate = 75;
end
if debug_mode
    %res = [800,0,1440,480];
    res = [0, 0, 1024, 768];
    [wind, win_rect] = Screen('OpenWindow',max(Screen('Screens')),background_color,  res);
else
    SetResolution(max(Screen('Screens')),resolution(1),resolution(2),refresh_rate);
    [wind, win_rect] = Screen('OpenWindow',max(Screen('Screens')),background_color );
end

log_msg( sprintf('Using screen #',num2str(max(Screen('Screens')))) ); %#ok<CTPCT>

% we may want PNG images
Screen('BlendFunction', wind, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

% grab height and width of screen
swidth  = win_rect(3)-win_rect(1);
sheight = win_rect(4)-win_rect(2);

% Screen and text color:
Screen('TextFont', wind, 'Helvetica'); Screen('TextSize', wind, 15);
    % Make sure text color contrasts with background color:
    if mean(background_color) < 255/2;
        text_color = [255 255 255];
    else
        text_color = [0   0   0  ];
    end
Screen('TextColor', wind, text_color)

log_msg(sprintf('Screen resolution is %s by %s',num2str(swidth),num2str(sheight)));

%% SET UP EYETRACKER

% Provide Eyelink with details about the graphics environment
% and perform some initializations. The information is returned
% in a structure that also contains useful defaults
% and control codes (e.g. tracker state bit and Eyelink key values).
el = EyelinkInitDefaults(wind);
el.backgroundcolour = background_color; % might as well make things consistent

priorityLevel = MaxPriority(wind);
Priority(priorityLevel);

% Initialization of the connection with the Eyelink Gazetracker.
% exit program if this fails.
% This is where the eyetracker is set to dummy-mode, if that option was
% selected
DrawFormattedText(wind, ['If you''re seeing this for a while, ET might'...
    ' not be connected. Press anykey to quit.'], 'center', 'center');
Screen('Flip', wind);

if ~EyelinkInit(get_config('DummyMode'), 1)
    log_msg(sprintf('Eyelink Init aborted.\n'));
    post_experiment(true);
end

[~, vs] = Eyelink('GetTrackerVersion');
log_msg(sprintf('Running experiment on a ''%s'' tracker.\n', vs ));

% Set-up edf file
edf_file = [subject_code '.edf'];
edfERR  = Eyelink('Openfile', edf_file);

if edfERR~=0
    log_msg(sprintf('Cannot create EDF file ''%s'' ', edf_file));
    post_experiment(true);
end

% Send some commands to eyetracker to set up event parsing:
% (no idea what this does)
Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, win_rect(3)-1, win_rect(4)-1);
Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, win_rect(3)-1, win_rect(4)-1);

Eyelink('command', 'select_parser_configuration 1');
Eyelink('command', 'sample_rate = 1000');

% Set EDF file contents
Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
% Set link data (used for gaze cursor)
Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');

%% RUN EXPERIMENT TRIALS %%

% Wait to begin experiment:
Screen('TextSize', wind, 25);
DrawFormattedText(wind, 'Press any key to begin!', 'center', 'center');
Screen('Flip', wind);
KbWait([], 2);
log_msg('Experimenter has begun experiment.');

% Begin Experiment:
this_phase = 0;
record_phases = eval(get_config('RecordingPhases'));
while this_phase < num_phases
    this_phase = this_phase + 1;
    
    log_msg('Phase has begun. Checking if it''s a recording phase...');
    
    % Calibrate the Eye Tracker?:
    if record_phases(this_phase)
        log_msg('It is a recording phase. Attempting to calibrate...');
        DrawFormattedText(wind,...
            'We will now calibrate the eyetracker. Let the experimenter know when you''re ready.',...
            'center', 'center');
        Screen('Flip', wind);
        WaitSecs(1);
        log_msg('Calibration started.');
        EyelinkDoTrackerSetup(el);
        log_msg('Calibration finished.');
    else
        log_msg('It is NOT a recording phase.');
    end
    
    % Get Interest Areas
    cond_logical = ([IA_struct.Condition] == condition);
    phase_logical = ([IA_struct.Phase] == this_phase);
    num_IAs = max([IA_struct([IA_struct.Phase] == this_phase).InterestArea]);
    IA_coords = {IA_struct.LTRB}; 
    interest_area = cell(num_IAs,1);
    
    for q = 1:num_IAs 
        ia_logical = ([IA_struct.InterestArea] == q);
        index = cond_logical & ia_logical & phase_logical;
         interest_area{q} = eval(strrep(IA_coords{index}, '"', '')); 
    end
    
    % Run Blocks:
    this_block = 0; 
    rotation_done = 0;
    while this_block < num_blocks(this_phase)
        this_block = this_block+1;
        
        % ON EACH BLOCK:
        
            % Do drift correct:
            if record_phases(this_phase)
                log_msg('Doing drift correct...');
                drift_correct
            end

            % Get Stim
            this_phase_stim = stimuli_paths{stim_order(this_phase)};

            % Check if stimuli should be flipped (rotated)
            if change_stim_angle(this_phase)
                % in this phase, the stimuli will be flipped
                if ~rotation_done
                    % but it has not yet been flipped
                    if this_block > num_blocks(this_phase)/2
                        % now that we're halfway through the phase, we
                        % should flip it (i.e., do flip animation)
                        final_stim_angle = do_stim_flip(this_phase_stim, stim_angle);
                        stim_angle = final_stim_angle; % set stim angle to correct val
                        rotation_done = 1; % ok, stim has been flipped
                    else
                        % st
                        stim_angle = default_stim_val(this_phase);
                    end
                end
            else
                stim_angle = 0;
            end

            % Show Stimuli:
            display_stimuli( this_phase_stim, stim_angle );
    end
end

%% POST-EXPERIMENT CLEANUP %%

record_phases(this_phase) = 0; % any clean-up messages will not be sent to the ET, since it's no longer recording
post_experiment(false);

catch my_err
    record_phases(this_phase) = 0; % any clean-up messages will not be sent to the ET, since it's no longer recording
    log_msg(my_err.message);
    if ~strcmpi(my_err.message,'Experiment ended.')
        post_experiment(true);
    end
end

%% FXN_drift_correct
    function drift_correct
        % do a final check of calibration using driftcorrection
        DC_start = GetSecs();
        success = EyelinkDoDriftCorrection(el);
        % if the experimenter hits esc here, then c, she
        % can recalibrate. that means every single block, there's a
        % chance to recalibrate if necessary.
        
        % If the eyetracker is having connection troubles, this gives
        % it 15 seconds to get those sorted out. 
        while success~=1 % if it doesn't work, try it a couple more times
            success = EyelinkDoDriftCorrection(el);
            if (GetSecs() - DC_start) > 15 % give up after 15 seconds of trying
                break
            end
            WaitSecs(.1);
        end
        
        if success~=1
            log_msg(sprintf('Cannot connect to eyetracker during drift_correct.'));
            post_experiment(true);
        end
        
    end
%% FXN_display_stimuli
    function display_stimuli (this_phase_stim, stim_angle)
        % This function displays the stimuli for this phase, after
        % determining its file type. It also starts and stops recording, if
        % we're in a recording phase.
        
        [stim_type,this_stim] = determine_stim_type( this_phase_stim );
        
        if     strcmpi(stim_type,'vid')
            % video stimuli
            vid_ind = 0;
            while vid_ind < length(this_stim)
                % play each video in the current folder
                vid_ind = vid_ind + 1;
                vid_dir = this_stim{vid_ind};
                
                %%%
                if record_phases(this_phase)
                    start_recording(this_phase,this_block,vid_ind,condition,stim_angle);
                    
                    error =...
                        play_video(vid_dir, stim_angle, vid_ind);
                    
                    stop_recording(error);
                else
                    play_video(vid_dir, stim_angle, vid_ind);
                end
                %%%
            end
            
        elseif strcmpi(stim_type,'img')
            % image stimuli
            %%%
            if record_phases(this_phase)
                start_recording(this_phase,this_block,['1thru' num2str(length(this_stim))],condition,stim_angle); % <------- Please fix.
                
                % play a slideshow of the images
                error =...
                    play_slideshow(this_stim,interval);
                
                stop_recording(error);
            else
                play_slideshow(this_stim,interval);
            end
            %%%
            
        end
        
    end
%% FXN_determine_stim_type
    function [stim_type, this_stim] = determine_stim_type (this_stim,file_to_check)
        % This function figures out what type of stimuli for this phase
        % (stim_type), and what the actual path of that stimuli is
        % (this_stim) (e.g., if it's located in a sub-folder based on
        % condition)
        
        if nargin<2
            % we want to determine the filetype of the stimuli in that
            % folder. we will base that decision off of the filetype of the
            % first item in that folder.
            file_to_check = 1;
        end
        
        image_extensions = {'.png','.jpg','.jpeg','.gif'};
        video_extensions = {'.mov','.mp4'};
        
        if iscell(this_stim{file_to_check}) % this means it's a folder
            % match condition to folder
            findex = cellfun(@(x) strfind(x{1}, ['/' num2str(condition) '/']),...
                this_stim, 'UniformOutput',false);
            findex = ~cellfun(@isempty,findex);
            %  now we recursively call this function on that lower level
            %  folder, to determine the stim type of *its* contents
            [stim_type, this_stim] = determine_stim_type (this_stim{findex});
        else
            % get the extension of the file:
            [~,~,ext] = fileparts(this_stim{file_to_check}); 
            % check if it matches any of the image extension names
            is_img = cell2mat(cellfun(@(x) strcmpi(ext,x), image_extensions, 'UniformOutput',false)); 
            if sum(is_img)>0
                % if it matches one of them, it's an image.
                stim_type = 'img';
                log_msg('Stimuli is recognized as an image');
            else
                % otherwise it's a video
                is_vid = cell2mat(cellfun(@(x) strcmpi(ext,x), video_extensions, 'UniformOutput',false));
                if sum(is_vid)
                    stim_type = 'vid';
                    log_msg('Stimuli is recognized as a video');
                else
                    stim_type = determine_stim_type(this_stim,file_to_check+1);
                    log_msg('This stimuli is not recognized as a video or image, will try next file in folder.');
                end
            end
        end
        
    end
%% FXN_start_recording
    function start_recording(this_phase,this_block,stim_num,condition,stim_angle)
        
        % Start recording eye position:
        Eyelink('StartRecording');
        WaitSecs(0.100);
        
        % Send variables to session file and eyetracker (and also logs)
        add_data('phase',this_phase);
        add_data('this_block',this_block);
        add_data('stim_num',stim_num);
        add_data('condition',condition);
        add_data('stim_angle',stim_angle);
        
        % Create interest areas for this trial
        for ia = 1:length(interest_area)
            % set interest area position, flip if stim is flipped.
            [L T R B] = set_IA_rect(interest_area{ia});
            Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', ia, L, T, R, B,...
                ['phase_',  num2str(this_phase),...
                '_block_', num2str(this_block),...
                '_stim_',  num2str(stim_num), ...
                '_IA_',    num2str(ia)]);
            log_msg( sprintf('iarea rectangle %d %d %d %d %d %s', ia, L, T, R, B,...
                ['phase_',  num2str(this_phase),...
                '_block_', num2str(this_block),...
                '_stim_',  num2str(stim_num), ...
                '_IA_',    num2str(ia)]) , ...
            0); % don't redundantly send to ET
        end
        
        log_msg(['START_RECORDING_PHASE_', num2str(this_phase),...
                 '_BLOCK_',                num2str(this_block),...
                 '_STIM_',                 num2str(stim_num)]);
        
    end
%% FXN_stop_recording
    function stop_recording(error)
        % Stop Recording, End trial
   
        log_msg(['STOP_RECORDING_PHASE_', num2str(this_phase),...
                 '_BLOCK_',               num2str(this_block)]);

        Eyelink('Message','!V TRIAL_VAR error %d', error);WaitSecs(.01);
        
        log_msg('StopRecording',0);
        Eyelink('StopRecording');WaitSecs(.01);
        Screen('Close');
        Eyelink('Message', 'TRIAL_RESULT 0');
        
    end
%% FXN_do_stim_flip
    function [final_stim_angle] = do_stim_flip (this_phase_stim, stim_angle)
        
            % Display text:
            [~,ny,~] = DrawFormattedText(wind, 'Press any key to continue', 'center', 'center');
            DrawFormattedText(wind, ['We will now flip the ' get_config('ContentName') ' around.'], 'center', ny-100);
            Screen('Flip', wind);
            KbWait([], 2);
            
            % Figure out values:
            init_stim_angle = stim_angle;
            final_stim_angle = mod( default_stim_val(this_phase) + 180 , 360 );
            angle_vals = init_stim_angle : (4*sign(final_stim_angle-init_stim_angle)) : final_stim_angle;
            
            % Do animation:
            [stim_type,this_stim] = determine_stim_type( this_phase_stim );
            
            % Needs work: <--------------------------
            if     strcmpi(stim_type,'vid')
                play_video(this_stim{1},angle_vals);
            elseif strcmpi(stim_type,'img')
                % play slideshow function, "
                % "
            end
            
    end
%% FXN_play_slideshow
    function [error] = play_slideshow (img_dir,interval)
        error = 0;
        img_ind = 0;
        while img_ind <= length(img_dir)
            % note the <=. this means that img_ind will, on the last loop,
            % be greater than length(img_dir). this is intentional: they
            % view the last slide twice (so that they don't accidentally
            % advance to the next phase prematurely).

            % advance through images
            img_ind = img_ind + 1;
            if img_ind <= length(img_dir)
                this_img = img_dir{img_ind};
            else
                % show the last image twice
                this_img = img_dir{length(img_dir)};
            end
            
            save_img_for_dv(this_img,img_ind);
            
            image = imread(this_img);
            
            imtex = Screen('MakeTexture', wind, image);
            Screen('DrawTexture', wind, imtex, [], win_rect);
            if dummy_mode
                % Draw interest areas
                for ia = 1:length(interest_area)
                    % set interest area position, flip if stim is flipped.
                    [L T R B] = set_IA_rect(interest_area{ia});
                    Screen('FrameRect',wind,[0 0 0],      [L T R B],2);
                    Screen('FrameRect',wind,[255 255 255],[L T R B],3);
                end
            end
            Screen('Flip', wind);
            
            log_msg(sprintf('Displaying Image: %s', this_img));

            while KbCheck; end; % if keypress from prev slide is still happening, we wait til its over
            image_start = GetSecs();
            
            keycode = check_keypress();
            close_image = 0;
            
            while ~close_image
                
                if interval~=0
                    % if each image is only supposed to be up there for a
                    % certain amount of time, this advances the slide at
                    % that time.
                    if GetSecs() > (image_start + interval)
                        close_image = 1;
                    end
                end
                
                [error, keycode] = check_status(error, keycode);
                
                if strcmpi(KbName(keycode),next_key)
                    % if next key was pressed, end while loop, which will
                    % advance us to next slide.
                    close_image = 1;
                elseif strcmpi(KbName(keycode),prev_key)
                    % if prev key was pressed, go back two slides, so that
                    % when we advance one slide, we're actually going back
                    % one slide.
                    img_ind = img_ind - 2;
                    if img_ind < 0
                        img_ind = 1;
                    end
                    % then end while loop
                    close_image = 1;
                end
            end
            
            Screen('Close', imtex);
            check_keypress(keycode, 1); % flush currently pressed keys
            log_msg(sprintf('Closing Image: %s', this_img));
        end
        
    end
%% FXN_play_video
    function [error] = play_video (vid_dir,stim_angle,vid_ind)
        
        if nargin<3
            vid_ind = [];
        end
        
        vid_start = NaN; % this gets set below, after first frame (b/c sending image to dataviewer is slow)
        rotation_end_ts = NaN;
        screencap_taken = 0;
        
        movie = Screen('OpenMovie', wind, [base_dir vid_dir]);
        
        % Start playback engine:
        Screen('PlayMovie', movie, 1);
        
        % set scale to 0 so it will be calculated
        texRect = 0;
        error = 0;
        keycode = check_keypress();
        
        % loop indefinitely
        j = 1;
        while (1 ~= 2)
            [error, keycode] = check_status(error,keycode);
            tex = Screen('GetMovieImage', wind, movie);
            
            if debug_mode
                if (GetSecs() - vid_start) > 3
                    break
                end
            end
            
            if length(stim_angle) > 1
                % Special Behavior: rotate the movie
                if j < length(stim_angle) && (GetSecs() - vid_start > 1)
                    j = j + 1;
                end
                % Once done rotating, end movie
                if j == length(stim_angle) && isnan(rotation_end_ts)
                    rotation_end_ts = GetSecs();
                end
                if GetSecs() - rotation_end_ts > 1
                    break
                end
            end
            
            if tex < 0
                % end movie?
                break
            else
                % Draw the new texture immediately to screen:
                if (texRect == 0)
                    texRect = Screen('Rect', tex);
                    % calculate scale factors
                    scale_w = win_rect(3) / texRect(3);
                    scale_h = win_rect(4) / texRect(4);
                    % protect aspect ratio by scaling by the smaller value
                    if (get_config('VideoPreserveAspectRatio') == 1)
                        if (scale_w < scale_h)
                            scale_h = scale_w;
                        else
                            scale_w = scale_h;
                        end
                    end
                    scale_w = scale_w * get_config('VideoScale');
                    scale_h = scale_h * get_config('VideoScale');
                    dstRect = CenterRect(ScaleRect(texRect, scale_w, scale_h), Screen('Rect', wind));
                    % if we have a vertical shift, let's do it
                    if (get_config('VideoVerticalShift') ~= 0)
                        dstRect(2) = dstRect(2) + get_config('VideoVerticalShift');
                        dstRect(4) = dstRect(4) + get_config('VideoVerticalShift');
                    end
                end
                
                Screen('DrawTexture', wind, tex, [], dstRect, stim_angle(j));
                
                if debug_mode
                    % Draw interest areas
                    for ia = 1:length(interest_area)
                        % set interest area position, flip if stim is flipped.
                        [L T R B] = set_IA_rect(interest_area{ia});
                        Screen('FrameRect',wind,[0 0 0],      [L T R B],2);
                        Screen('FrameRect',wind,[255 255 255],[L T R B],3);
                    end
                end
                Screen('Flip', wind); % Update display
                
                if screencap_taken == 0
                    image_array = Screen('GetImage', wind);
                    save_img_for_dv(image_array,vid_ind)
                    screencap_taken = 1;
                    
                    log_msg(sprintf('Playing Video: %s', vid_dir));
                    vid_start = GetSecs();
                    
                end
                
                Screen('Close', tex); % Release texture
            end
        end
        
        Screen('PlayMovie', movie, 0);
        Screen('CloseMovie', movie);
        Screen('Flip', wind);
        
        Screen('Flip', wind);
        check_keypress(keycode, 1); % flush currently pressed keys
        log_msg('Video is over.');
        
    end
%% FXN_set_IA_rect
    function [L T R B] = set_IA_rect(rect)
        L = rect(1);
        L = abs(resolution(1)*rotation_done - L);
        T = rect(2);
        T = abs(resolution(2)*rotation_done - T);
        R = rect(3);
        R = abs(resolution(1)*rotation_done - R);
        B = rect(4);
        B = abs(resolution(2)*rotation_done - B);
        
        if L>R
            temp = R;
            R = L;
            L = temp;
        end
        
        if T>B
            temp = T;
            T = B;
            B = temp;
        end
        
    end
%% FXN_check_status
    function [error, keycode] = check_status (error,last_keycode)
        if nargin < 2
            last_keycode = zeros(1,256);
        end
        
        if record_phases(this_phase) && error == 0 % if we're recording, and we haven't yet registered an error
            error = Eyelink('CheckRecording'); % check if there is NOW an error
        end
        
        [keycode] = check_keypress (last_keycode);
    end
%% FXN_check_keypress
    function [keycode] = check_keypress(last_keycode, trialend)
        if nargin < 1
            last_keycode = zeros(1,256);
        end
        if nargin < 2
            trialend = 0;
        end
        
        [~,~,keycode] = KbCheck();
        
        if trialend
            keycode = zeros(1,256);
        end
        
        % LOG KEYS:
            keycode_diff = keycode - last_keycode;
            %  0 = key state hasn't changed
            %  1 = key just pressed
            % -1 = key just released
            released_keys = find(keycode_diff < 0);
            pressed_keys  = find(keycode_diff > 0);

            for i = 1:length(released_keys) 
                log_msg(sprintf( 'Key released: %s', KbName(released_keys(i)) ))
            end
            for i = 1:length(pressed_keys) 
                log_msg(sprintf( 'Key pressed: %s',  KbName(pressed_keys(i))  ))
            end
        
        % CHECK FOR ESCAPE:
            if length(pressed_keys) == 1
                if strcmpi( KbName(pressed_keys) , 'Escape' )
                    WaitSecs(.5);
                    [~,~,keycode] = KbCheck();
                    if strcmpi(KbName(keycode),'Escape')
                        log_msg('Aborting experiment due to ESCAPE key press.');
                        post_experiment(true);
                    end
                end
            end  
       
    end
%% FXN_save_img_for_dv
    function save_img_for_dv (img_in,stim_num)
        if record_phases(this_phase)
            
            if ischar(img_in)
                imgpath = img_in;
            else
                image_array = img_in;
                imgname = ['phase_', num2str(this_phase),'_block_',num2str(this_block),...
                    '_stim_',num2str(stim_num)];
                imgpath = ['data/', subject_code, '/' imgname '.jpg'];
                imwrite(image_array,imgpath);
            end
            
            log_msg(sprintf('!V IMGLOAD CENTER %s %d %d', imgpath, swidth/2, sheight/2)); % also sends to ET
        end
    end
%% FXN_add_data
    function add_data (data_key, data_value)
        data(length(data) + 1).key = data_key;
        data(length(data)).value = data_value;
        
        if isnumeric(data_key)
            data_key = num2str(data_key);
        end
        if isnumeric(data_value)
            data_value = num2str(data_value);
        end
        log_msg(sprintf('%s : %s',data_key, data_value),0);
        if record_phases(this_phase)
            Eyelink('Message','!V TRIAL_VAR %s %s', data_key, data_value);
        end
    end
%% FXN_get_config
    function [value] = get_config (name)
        matching_param = find(cellfun(@(x) strcmpi(x, name), {config.Parameter}));
        value = [config(matching_param).Setting]; %#ok<FNDSB>
        
        % replace quotes so we get pure values
        value = strrep(value, '"', '');
    end
%% FXN_post_experiment
    function post_experiment (aborted)
        log_msg('Experiment ended');
        
        ShowCursor();
        
        sca;
        
        ListenChar(0);
        Screen('CloseAll');
        Screen('Preference', 'SuppressAllWarnings', 0);
        
        commandwindow;
        Eyelink('StopRecording');
        Eyelink('closefile');
        
        try
            fprintf('Receiving data file ''%s''\n', edf_file );
            status=Eyelink('ReceiveFile');
            if status > 0
                fprintf('ReceiveFile status %d\n', status);
            end
        catch %#ok<CTCH>
            log_msg(sprintf('Problem receiving data file ''%s''\n', edf_file ));
        end
        
        Eyelink('ShutDown');
        
        if (aborted == false)
            % get experimenter comments
            comments = inputdlg('Enter your comments about attentiveness, etc.:','Comments',3);
            if isempty(comments)
                comments = {''};
            end
            
            % create empty structure for results
            results = struct('key',{},'value',{});
            
            [ year, month, day, hour, minute, sec ] = datevec(now);
            end_time = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];
            
            results(length(results) + 1).key = 'Start Time';
            results(length(results)).value = start_time;
            results(length(results) + 1).key = 'End Time';
            results(length(results)).value = end_time;
            results(length(results) + 1).key = 'Status';
            
            if (aborted == true)
                % This will never be true. Bug?
                results(length(results)).value = 'ABORTED!';
            else
                results(length(results)).value = 'Completed';
            end
            results(length(results) + 1).key = 'Experimenter';
            results(length(results)).value = experimenter;
            results(length(results) + 1).key = 'Subject Code';
            results(length(results)).value = subject_code;
            results(length(results) + 1).key = 'Condition';
            results(length(results)).value = condition;
            results(length(results) + 1).key = 'Comments';
            results(length(results)).value = comments{1};
            
            % merge in data
            for i = 1:length(data)
                results(length(results) + 1).key = data(i).key;
                results(length(results)).value = data(i).value;
            end
            
            % save session file
            filename = [base_dir 'sessions/' subject_code '.txt'];
            log_msg(sprintf('Saving results file to %s',filename));
            WriteStructsToText(filename,results)
        else
            disp('Experiment aborted - results file not saved, but there is a log.'); 
            error('Experiment Ended.');
        end
        
    end
%% FXN_comb_dir
    function [paths] = comb_dir (directory,hierarchical)
        % Recursive folder look-up
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
                    addMe=comb_dir([directory '/' dirinfo(i).name],1);
                    if ~isempty(addMe) % if the folder was empty, stop. otherwise, add it to the list
                        %if ~iscell(addMe{1}); addMe={addMe};end;
                        paths{end+1} = addMe; %#ok<AGROW>
                    end
                else
                    paths=[paths comb_dir([directory '/' dirinfo(i).name])]; %#ok<AGROW>
                end
            else
                if ~strcmpi(dirinfo(i).name,'.DS_Store')
                    pathToFile= [directory '/' dirinfo(i).name];
                    paths=[paths pathToFile]; %#ok<AGROW>
                end
            end
        end
        
    end
%% FXN_explode
    function [split,numpieces] = explode(string,delimiters) %#ok<DEFNU>
        %   Created: Sara Silva (sara@itqb.unl.pt) - 2002.04.30
        
        if isempty(string) % empty string, return empty and 0 pieces
            split{1}='';
            numpieces=0;
        elseif isempty(delimiters) % no delimiters, return whole string in 1 piece
            split{1}=string;
            numpieces=1;
        else % non-empty string and delimiters, the correct case
            remainder=string;
            i=0;
            while ~isempty(remainder)
                [piece,remainder]=strtok(remainder,delimiters); %#ok<STTOK>
                i=i+1;
                split{i}=piece; %#ok<AGROW>
            end
            numpieces=i;
        end
    end
%% FXN_create_log_file
    function create_log_file ()
        fileID = fopen([base_dir 'logs/' subject_code '-' start_time '.txt'],'w');
        fclose(fileID);
    end
%% FXN_log_msg
    function log_msg (msg,sendtoET)
        if nargin < 2
            sendtoET = 1;
        end
        fileID = fopen([base_dir 'logs/' subject_code '-' start_time '.txt'],'a');
        
        [ year, month, day, hour, minute, sec ] = datevec(now);
        timestamp = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];
        
        fprintf(fileID,'%s \t%s\n',timestamp,msg);
        fclose(fileID);
        
        if sendtoET
            if exist('record_phases','var')
                if record_phases(this_phase)
                    Eyelink('Message',msg);
                end
            end
        end
        
        fprintf('\n# %s\n',msg);
    end
end