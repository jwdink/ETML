function [my_err] = ETML (base_dir, session_info)

my_err = [];

%% LOAD CONFIGURATION %%

PsychJavaTrouble;

% Global Structs for this session:
global el 
global session 

% Get experiment directory:
if nargin < 1
    session.base_dir = [ uigetdir([], 'Select experiment directory') '/' ];
else
    session.base_dir = base_dir;
end

cd(session.base_dir); %

% Load the tab-delimited configuration files:
session.config = ReadStructsFromTextW('config.txt');
stim_config = ReadStructsFromTextW('stim_config.txt');
if exist( 'interest_areas.txt', 'file')
    IA_config = ReadStructsFromTextW('interest_areas.txt');
end

% Re-Format the Interest Area Config file into a useful table:
% * TO DO *

% Create Necessary Folders:
if ~exist('logs','dir'); mkdir('logs'); end;
if ~exist('sessions', 'dir'); mkdir('sessions'); end;

sprintf('You are running %s\n\n', get_config('StudyName'));

try
    %% SET UP EXPERIMENT AND SET SESSION VARIABLES %%
    
    % Turn off warnings, set random seed:
    session.random_seed = sum(clock);
    rand('twister', session.random_seed); %#ok<RAND>
    commandwindow;
    
    % Get Date/Time
    [ year, month, day, hour, minute, sec ] = datevec(now);
    session.start_time =...
        [num2str(year) '-' num2str(month) '-' num2str(day) ...
        ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];
    
    % Get subject code
    session.dummy_mode = get_config('DummyMode'); % not tracking eyes
    session.debug_mode = get_config('DebugMode'); % debugging tools (e.g. windowed)
    if ~session.debug_mode
        if nargin < 2
            session.experimenter = input('Enter your (experimenter) initials: ','s');
            session.subject_code = input('Enter subject code: ', 's');
            session.condition = str2double( input('Enter condition: ', 's') );
        else
            session.experimenter = session_info{1};
            session.subject_code = session_info{2};
            session.condition    = session_info{3};
            if ischar(session.condition)
                session.condition = str2double(session.condition);
            end
        end
    else
        session.experimenter = 'null';
        session.subject_code = '0';
        session.condition = 1;
    end
    
    % Find out which phases will be recording (needed before calling
    % log_msg):
    session.record_phases = eval(get_config('RecordingPhases'));
    
    % Make trial-data folder:
    mkdir('data', session.subject_code);
    
    % Re-Format the Stimuli Config file into a useful table:
    stim_config_p = pad_struct(stim_config);
    path = ['data/', session.subject_code, '/' 'trial_record.txt'];
    WriteStructsToText(path, stim_config_p); % for testing
    
    % Begin logging now, because we have the subject_code
    session.fileID = fopen([ 'logs/' session.subject_code '-' session.start_time '.txt'],'w');
    fclose(session.fileID);
    log_msg(sprintf('Set base dir: %s', session.base_dir));
    log_msg('Loaded config file');
    log_msg(sprintf('Study name: %s',get_config('StudyName')));
    log_msg(sprintf('Random seed set as %s via "twister"',num2str(session.random_seed)));
    log_msg(sprintf('Start time: %s', session.start_time));
    log_msg(sprintf('Experimenter: %s', session.experimenter));
    log_msg(sprintf('Subject Code: %s', session.subject_code));
    log_msg(sprintf('Condition: %d ', session.condition));
    
    % Initiate data structure for session file
    session.data = struct('key',{},'value',{});
    
    % Key controls
    session.next_key = 'RightArrow';
    session.prev_key = 'LeftArrow';
    
    % Wait for experimenter to press Enter to begin
    disp(upper(sprintf('\n\nPress any key to launch the experiment window\n\n')));
    if ~session.debug_mode
        KbWait([], 2);
    end
    
    log_msg('Experimenter has launched the experiment window');
    
    %% SET UP SCREEN %%
    
    % An OpenGL struct needed for mirroring texture.
    % Note that this has scope that spans multiple functions, but it's not
    % global. This is to improve performance, but it means this GL var can't 
    % be used in other functions not in this script.
    GL = struct(); 
    InitializeMatlabOpenGL([],[],1); 
    
    if session.dummy_mode
        % skip sync tests for faster load
        Screen('Preference','SkipSyncTests', 1);
        log_msg('Running in DebugMode');
    else
        log_msg('Not running in DebugMode');
        % disable the keyboard
        ListenChar(2);
        HideCursor();
    end
    
    % Create window
    session.background_color = get_config('BackgroundColor');
    session.background_color = repmat(session.background_color, 1, 3);
    resolution = eval(get_config('ScreenRes'));
    if session.dummy_mode
        refresh_rate = [];
    else
        refresh_rate = get_config('RefreshRate');
    end
    if session.debug_mode
        res = [0, 0, resolution(1), resolution(2)];
        [wind, session.win_rect] = Screen('OpenWindow',max(Screen('Screens')),session.background_color,  res);
    else
        SetResolution(max(Screen('Screens')),resolution(1),resolution(2),refresh_rate);
        [wind, session.win_rect] = Screen('OpenWindow',max(Screen('Screens')),session.background_color );
    end
    
    log_msg( sprintf('Using screen #',num2str(max(Screen('Screens')))) ); %#ok<CTPCT>
    
    % we may want PNG images
    Screen('BlendFunction', wind, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    % grab height and width of screen
    session.swidth  = session.win_rect(3)-session.win_rect(1);
    session.sheight = session.win_rect(4)-session.win_rect(2);
    
    % Screen and text color:
    Screen('TextFont', wind, 'Helvetica'); Screen('TextSize', wind, 15);
    % Make sure text color contrasts with background color:
    if mean(session.background_color) < 255/2;
        text_color = [255 255 255];
    else
        text_color = [0   0   0  ];
    end
    Screen('TextColor', wind, text_color)
    
    log_msg(sprintf('Screen resolution is %s by %s',num2str(session.swidth),num2str(session.sheight)));
    
    %% SET UP EYETRACKER
    
    % Provide Eyelink with details about the graphics environment
    % and perform some initializations. The information is returned
    % in a structure that also contains useful defaults
    % and control codes (e.g. tracker state bit and Eyelink key values).
    el = EyelinkInitDefaults(wind);
    el.backgroundcolour = session.background_color; % might as well make things consistent
    
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
    session.edf_file = [session.subject_code '.edf'];
    edfERR  = Eyelink('Openfile', session.edf_file);
    
    if edfERR~=0
        log_msg(sprintf('Cannot create EDF file ''%s'' ', session.edf_file));
        post_experiment(true);
    end
    
    % Send some commands to eyetracker to set up event parsing:
    % (no idea what this does)
    Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, session.win_rect(3)-1, session.win_rect(4)-1);
    Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, session.win_rect(3)-1, session.win_rect(4)-1);
    
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

    phases = unique( [stim_config_p.('Phase')] );
    
    this_phase = 0;
    while this_phase < length(phases)
        this_phase = this_phase + 1;
        
        % On Each Phase:
        this_phase_rows = get_rows(stim_config_p, session.condition, this_phase);
        
        % Calibrate the Eye Tracker?:
        if session.record_phases(this_phase)
            log_msg('It is a recording phase.');
            
            while KbCheck(); end;
            msg = 'Before continuing, we just need to calibrate. Let the experimenter know once you''re ready.';
            DrawFormattedText(wind, msg, 'center', 'center');
            Screen('Flip', wind);
            KbWait();
            
            log_msg('Calibration started.');
            EyelinkDoTrackerSetup(el);
            log_msg('Calibration finished.');
            WaitSecs(.5);
        else
            log_msg('It is not a recording phase.');
        end
        
        % Run Blocks:
        blocks = unique( [stim_config_p(this_phase_rows).('Block')] );
        
        this_block = 0;
        while this_block < length(blocks)
            this_block = this_block + 1;
            
            % On Each Block:
            this_block_rows = get_rows(stim_config_p, session.condition, this_phase, this_block);
            
            % Do drift correct?:
            if session.record_phases(this_phase)
                log_msg('Doing drift correct...');
                drift_correct
            end
            
            % Run Trials:
            
            trials = unique( [stim_config_p(this_block_rows).('Trial')] );
            
            % Shuffle trial order?:
            if stim_config_p(this_block_rows(1)).('Random') == 1 % 1 means shuffle trials
                idx = randperm(length(trials));
                trials = trials(idx);
            end
            
            trial_index     = 0;
            new_trial_index = 1;
            while trial_index < length(trials)
                trial_index = new_trial_index;
                if trial_index < 1
                    trial_index = 1;
                end
                this_trial = trials(trial_index);
                
                % On Each Trial:
                this_trial_row = get_rows(stim_config_p, session.condition, this_phase, this_block, this_trial);
                
                if session.record_phases(this_phase)
                    start_recording(trial_index, stim_config_p(this_trial_row));
                end
                
                new_trial_index = show_stimuli(wind, trial_index , stim_config_p(this_trial_row), GL);
                
                if session.record_phases(this_phase)
                    stop_recording(trial_index, stim_config_p(this_trial_row));
                end
            end
        end
    end
    
    post_experiment(0);
    
    
catch my_err
        
    log_msg(my_err.message);
    log_msg(num2str([my_err.stack.line]));
    
    if ~strcmpi(my_err.message,'Experiment ended.')
        post_experiment(true);
    end
    
end

%% FXN_show_stimuli
    function [new_trial_index] = show_stimuli (wind, trial_index, trial_config, GL)
        
        if     ~isempty( strfind(trial_config.StimType, 'img') ) || ...
               ~isempty( strfind(trial_config.StimType, 'slideshow') )

            new_trial_index = ...
                show_img(wind, trial_index, trial_config, GL);
            
        elseif strfind(trial_config.StimType, 'vid')
            
            new_trial_index = ...
                show_vid(wind, trial_index, trial_config, GL);
            
        elseif ~isempty( strfind(trial_config.StimType, 'custom') )
            
            if ~exist('out_struct', 'var')
                out_struct = struct(); 
            end
            [new_trial_index, out_struct] =...
                custom_function(wind, trial_index, trial_config, out_struct); %#ok<NASGU>
             
        else
            errmsg = ['StimType "' trial_config.StimType '" is unsupported.'];
            error(errmsg);
        end
        
    end

%% FXN_start_recording
    function start_recording(trial_index, trial_config)
        
        % Start recording eye position:
        Eyelink('StartRecording');
        WaitSecs(0.100);
        
        % Send variables to EDF, session txt, and log txt:
        add_data('condition',   trial_config.('Condition'), trial_config.('Phase'));
        add_data('phase',       trial_config.('Phase'),     trial_config.('Phase'));
        add_data('this_block',  trial_config.('Block'),     trial_config.('Phase'));
        add_data('trial',       trial_index,                trial_config.('Phase'));
        add_data('stim',        trial_config.('Stimuli'),   trial_config.('Phase'));
        
        other_fields = {'FlipX', 'FlipY', 'DimX', 'DimY'};
        
        for f = 1:length(other_fields)
            field = other_fields{f};
            if isfield(trial_config,field)
                add_data(field, trial_config.(field), trial_config.('Phase'));
            end
        end
        
        log_msg(...
            ['START_RECORDING_PHASE_', num2str(trial_config.('Phase')),...
            '_BLOCK_',                 num2str(trial_config.('Block')),...
            '_TRIAL_',                 num2str(trial_index)], ...
        trial_config.('Phase'));
        
    end

%% FXN_stop_recording
    function stop_recording(trial_index, trial_config)
        % Stop Recording, End trial
        
        log_msg(...
            ['STOP_RECORDING_PHASE_',  num2str(trial_config.('Phase')),...
            '_BLOCK_',                 num2str(trial_config.('Block')),...
            '_TRIAL_',                 num2str(trial_index)], ...
        trial_config.('Phase') );
        
        log_msg('StopRecording');
        Eyelink('StopRecording');
        WaitSecs(.01);
        Screen('Close');
        Eyelink('Message', 'TRIAL_RESULT 0');
        
    end

%% FXN_save_img_for_dv
    function save_img_for_dv (trial_index, trial_config, tex)

        if session.record_phases(trial_config.('Phase'))
            
            if nargin < 3
                imgpath = trial_config.('Stimuli');
            else
                image_array = Screen('GetImage', tex ); 
                imgname = ['img' ...
                    '_phase_' num2str(trial_config.('Phase')) ...
                    '_block_' num2str(trial_config.('Block')) ...
                    '_trial_' num2str(trial_index) '.jpg' ];
                imgpath = ['data/', session.subject_code, '/' imgname];
                imwrite(image_array, imgpath);
            end
            
            log_msg(sprintf('!V IMGLOAD CENTER %s %d %d', imgpath, session.swidth/2, session.sheight/2), ...
                trial_config.('Phase')); % send to ET
            
        end
    end

%% FXN_is_default
    function [out] = is_default (config)
        
        if isempty(config)
            % if empty
            out = 1;
            return
        end
        
        if length(config) == 1 && config(1) == 0
            % if zero or nan
            out = 1;
            return
        end
        
        if sum(isnan(config))
            % if any nans
            out = 1;
            return
        end
        
        out = 0;
        return
        
    end

%% FXN_show_vid
    function [new_trial_index, blip_time] = show_vid(wind, trial_index, trial_config, GL)
        
        % Get trial info about blip:
        if isfield(trial_config, 'Blip')
            blip_config = smart_eval(trial_config.('Blip'));
            if is_default(blip_config)
                blip = 0;
            else
                if rand > .5 % even with blip setting on, it only happens on 50% of trials
                    blip = 0;
                else
                    blip = blip_config;
                end
            end
        else
            blip = 0;
        end
    
        mov_rate = 1;
        
        % Open Movie(s):
        win_rect = session.win_rect; % so that repetitive loop doesn't have to access global var
        [movie mov_dur fps imgw imgh] = ...
            Screen('OpenMovie', wind, [session.base_dir trial_config.('Stimuli')] ); %#ok<NASGU,ASGLU>
        if blip
            [movieb] = open_blip_movie(wind, trial_config);
            blip_time = rand(1) * (blip(2)-blip(1)) + blip(1); % random number between blip(1) & blip(2)
            blip_status = 0; % 0 = not started; 1 = in progress; -1 = completed
            log_msg(['On this trial, the blip will happen at ' num2str(blip_time) ' secs.'], trial_config.('Phase'));
            add_data('blip_time', blip_time, trial_config.('Phase'));
        else
            blip_time = NaN;
            blip_status = -1;
            if isfield(trial_config, 'Blip')
                add_data('blip_time', 'NaN', trial_config.('Phase'));
            end
        end
        
        % Custom Start time [jitter]?:
        if isfield(trial_config, 'TimeInVidToStart')
            tiv_config = smart_eval(trial_config.('TimeInVidToStart'));
            if ~is_default(tiv_config)
                max_tiv = max(tiv_config);
                min_tiv = min(tiv_config);
                tiv_tostart = (max_tiv-min_tiv)*rand() + min_tiv;
                % since we're coming into the film late, its time-left duration
                % is shoter than its total duration:
                mov_dur = mov_dur - tiv_tostart;
            else
                tiv_tostart = 0;
            end
            add_data('tiv_tostart', tiv_tostart, trial_config.('Phase'));
        else
            tiv_tostart = 0;
        end
        
        % Get trial info about stim duration:
        if isfield(trial_config, 'Duration')
            dur_config = smart_eval(trial_config.('Duration'));
            if length(dur_config) > 1
                duration = dur_config(2);
                min_duration = dur_config(1);
            else
                if is_default(dur_config)
                    duration = mov_dur * 1/mov_rate;
                    min_duration = duration;
                else
                    duration = dur_config;
                    min_duration = duration;
                end
            end
        else
            duration = mov_dur;
            min_duration = duration;
        end
        
        % Duration jitter:
        if isfield(trial_config, 'DurJitter')
            djit_config = smart_eval(trial_config.('DurJitter'));
            if ~is_default(djit_config)
                if length(djit_config) == 1
                    djit_config(2) = 0;
                end
                max_djit = max(djit_config);
                min_djit = min(djit_config);

                dur_jit = (max_djit-min_djit)*rand() + min_djit;
                duration = duration + dur_jit;
                min_duration = min_duration + dur_jit;
            end
        end  

        % Save for DV:
        tex = Screen('GetMovieImage', wind, movie, [], 1); % get image from movie 1 sec in
        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect, 'save_to_dv');
        Screen('FillRect', wind, session.background_color, session.win_rect);
        Screen('Close',tex);
        Screen('Flip', wind);
        Screen('Flip', wind);
        
        % Start playback(s):
        Screen('PlayMovie', movie , mov_rate);
        WaitSecs(.25);
        if blip
            Screen('PlayMovie', movieb, mov_rate);
            WaitSecs(.25);
            Screen('SetMovieTimeIndex', movieb, tiv_tostart);
        end
        Screen('SetMovieTimeIndex', movie, tiv_tostart);

        log_msg( sprintf('Playing Video: %s', trial_config.('Stimuli')), trial_config.('Phase') );
        vid_start = GetSecs();
        
        keycode = check_keypress([], trial_config.('Phase'));

        while 1
            keycode = check_keypress(keycode, trial_config.('Phase'));
            
            if GetSecs() - vid_start >= duration
                break % end movie
            end
            
            if sum(keycode)
                if GetSecs() - vid_start >= min_duration
                  break % end movie
                end
            end
            
            % Get Movie texture:
            tex  = Screen('GetMovieImage', wind, movie,  1);
            
            % If texture is available, draw and Flip to screen:
            if  tex > 0 && sum(~blip)
                draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
                Screen('Close', tex );
                Screen('Flip',wind, [], 0);
            end
            
            % If blip setting is on, drawing/flipping to screen is slightly more
            % complicated:
            if blip
                texb = Screen('GetMovieImage', wind, movieb, 1);
                if (tex > 0) && (texb > 0)
                    if     blip_status == -1                    % blip done or not happening
                        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
                    elseif blip_status ==  0                    % blip will happen, but when?
                        if GetSecs() - vid_start > blip_time    % check to see if it's bliptime
                            blip_start = GetSecs();
                            blip_status = 1;
                        end
                        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
                        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
                    elseif blip_status ==  1                    % blip is happening
                        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
                        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
                        if GetSecs() - blip_start > .125        % <--- 125 ms.
                            blip_status = -1;
                        end
                    end
                    Screen('Close', tex );
                    Screen('Close', texb);
                    Screen('Flip',wind, 0, 0);
                end
            end

        end % end movie loop
        
        % Close Movie(s):
        dropped_frames = Screen('PlayMovie',  movie, 0);
        log_msg( sprintf('Dropped frames: %d', dropped_frames) ,trial_config.('Phase'));
        Screen('CloseMovie', movie);
        if blip
            Screen('PlayMovie',  movieb, 0);
            Screen('CloseMovie', movieb);
        end
        Screen('Flip', wind);
        log_msg('Video is over.', trial_config.('Phase'));
        
        Screen('Flip', wind);
        check_keypress(keycode, trial_config.('Phase'), 'flush'); % flush currently pressed keys
        
        new_trial_index = trial_index + 1;
        WaitSecs(.1);
        
        function [movieb] = open_blip_movie(wind, trial_config)
            [pathstr, filename] = fileparts([session.base_dir trial_config.('Stimuli')]);
            
            
            blipdir = [pathstr, '/blip/'];
            if ~exist(blipdir, 'dir')
                 blipdir = [pathstr, '/Blip/'];
            end
            blipdirstr = dir(blipdir);
            blipfiles = {blipdirstr.name};
            
            b_i = ~cellfun(@isempty, strfind(blipfiles, filename) );
            blipfile = blipfiles(b_i);
            
            stim_blip = [blipdir blipfile{1}];

            [movieb durb fpsb imgwb imghb] = ...
                Screen('OpenMovie', wind, stim_blip ); %#ok<NASGU,ASGLU>
        end
    end

%% FXN_show_img
    function [new_trial_index] = show_img (wind, trial_index, trial_config, GL)
        
        stim_path = trial_config.('Stimuli');
        win_rect = session.win_rect;
        
        % Get trial info about stim duration:
        if isfield(trial_config, 'Duration')
            dur_config = smart_eval(trial_config.('Duration'));
            if length(dur_config) > 1
                duration = dur_config(2);
                min_duration = dur_config(1);
            else
                if is_default(dur_config)
                    % if they entered nothing, assume image until keypress
                    duration = Inf;
                    min_duration = 0;
                else
                    % if they entered 1 number, assume stim up for that
                    % amount of time (regardless of keypress)
                    duration = dur_config;
                    min_duration = duration;
                end
            end
        else
            % if they entered nothing, assume image until keypress
            duration = Inf;
            min_duration = 0;
        end
        
        % Duration jitter:
        if isfield(trial_config, 'DurJitter')
            djit_config = smart_eval(trial_config.('DurJitter'));
            if ~is_default(djit_config)
                if length(djit_config) == 1
                    djit_config(2) = 0;
                end
                max_djit = max(djit_config);
                min_djit = min(djit_config);

                dur_jit = (max_djit-min_djit)*rand() + min_djit;
                duration = duration + dur_jit;
                min_duration = min_duration + dur_jit;
            end
        end 
        
        % Slideshow:
        if strfind('slideshow', trial_config.('StimType'))
            slideshow = 1;
        else
            slideshow = 0;
        end 
        
        % Get image:
        image = imread(stim_path);                                      % read in image file
        tex = Screen('MakeTexture', wind, image, [], [], [], 1);        % make texture
        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);   % draw to window
        
        save_img_for_dv(trial_index, trial_config);
        
        if session.dummy_mode
            % Draw Interest Areas
        end
        
        while KbCheck; end; % if keypress from prev slide is still happening, we wait til its over
        log_msg( sprintf('Displaying Image: %s', stim_path) , trial_config.('Phase'));
        image_start = GetSecs();
        Screen('Flip', wind);
        
        keycode = check_keypress([], trial_config.('Phase'));
        close_image = 0;
        
        while ~close_image
            
            if duration > 0
                % if each image is only supposed to be up there for a
                % certain amount of time, this advances the slide at
                % that time.
                if GetSecs() > (image_start + duration)
                    close_image = 1;
                    new_trial_index = trial_index + 1;
                end
            end
            
            keycode = check_keypress(keycode, trial_config.('Phase'));
            
            if slideshow
                % if it's a slideshow, then they can sift thru the slides
                if     strcmpi(KbName(keycode), session.next_key)
                    close_image = 1;
                    new_trial_index = trial_index + 1;
                elseif strcmpi(KbName(keycode), session.prev_key)
                    close_image = 1;
                    new_trial_index = trial_index - 1;
                end
            else
                % if it's an image, advance on keypress, assuming it's been
                % up for minimum amount of time
                if sum(keycode)
                    if GetSecs() > (image_start + min_duration)
                        close_image = 1;
                        new_trial_index = trial_index + 1;
                    end
                end
            end
                    
            
        end
        
        check_keypress(keycode, trial_config.('Phase'), 'flush'); % flush currently pressed keys
        
    end

%% FXN_draw_tex
    function draw_tex (wind, tex, trial_index, trial_config, GL, win_rect, save_to_dv)

        % IMPORTANT: To work in this function, any tex made with
        % Screen('MakeTexture') must have been created with
        % textureOrientation = 1. See Screen('MakeTexture?')
        
        if nargin < 7
            save_to_dv = 0;
        end
        
        % Get Flip Config:
        if isfield(trial_config, 'FlipX')
            FlipX = trial_config.FlipX;
        else
            FlipX = 0;
        end
        if isfield(trial_config, 'FlipY')
            FlipY = trial_config.FlipY;
        else
            FlipY = 0;
        end
        if FlipX
            x = -1;
        else
            x =  1;
        end
        if FlipY
            y = -1;
        else
            y =  1;
        end
        
        % Get Dim config:
        tex_rect = Screen('Rect', tex);
        tex_rect_o = tex_rect; % original texrect, before stretching. required for flipX,Y to work
        if isfield(trial_config, 'DimX')
            DimX = trial_config.DimX;
            if ~( ischar(DimX) || is_default(DimX) )
                % if they specified a number in pixels
                tex_rect([1 3]) = [0 DimX];
            elseif ischar(DimX)
                % if they specified a percentage
                DimX = strrep(DimX,'%','');
                tex_rect(3) = tex_rect(3) * str2double(DimX)/100;
            end
        end
        if isfield(trial_config, 'DimY')
            DimY = trial_config.DimY;
            if ~( ischar(DimY) || is_default(DimY) )
                % if they specified a number in pixels
                tex_rect([2 4]) = [0 DimY];
            elseif ischar(DimY)
                % if they specified a percentage
                DimY = strrep(DimY,'%','');
                tex_rect(4) = tex_rect(4) * str2double(DimY)/100;
            end
        end
        
        dest_rect = CenterRect(tex_rect, win_rect);
        
        theight = tex_rect_o(4) - tex_rect_o(2);
        twidth  = tex_rect_o(3) - tex_rect_o(1);
        
        glMatrixMode(GL.TEXTURE); % don't know what this does.
        glPushMatrix; % don't know what this does.
        
        % Mirroring/Flipping the texture is done along the center of the tex.
        % Therefore, to flip/mirror properly, we need to displace the texture,
        % flip/mirror it, and then put it back in its original place:
        glTranslatef(twidth/2, theight/2, 0);
        glScalef(x,y,1);
        glTranslatef(-twidth/2, -theight/2, 0);
        
        % Draw the texture:
        if save_to_dv
            offwind = Screen('OpenOffscreenWindow', wind);
            Screen('DrawTexture', offwind, tex, [], dest_rect);
            save_img_for_dv(trial_index, trial_config, offwind);
            Screen('CopyWindow', offwind, wind);
        else
            Screen('DrawTexture', wind, tex, [], dest_rect);
        end
        
        glMatrixMode(GL.TEXTURE); % don't know what this does
        glPopMatrix; % don't know what this does
        % glMatrixMode(GL.MODELVIEW);  % don't know what this does
        
    end

%% FXN_get_config
    function [value] = get_config (name)
        matching_param = find(cellfun(@(x) strcmpi(x, name), {session.config.Parameter}));
        value = [session.config(matching_param).Setting]; %#ok<FNDSB>
        
        % replace quotes so we get pure values
        value = strrep(value, '"', '');
    end

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

%% FXN_get_rows
    function [rows] = get_rows (config_struct, condition, this_phase, this_block, this_trial)
        
        cond_logical  = ([config_struct.Condition] == condition);
        
        if nargin > 2
            phase_logical = ([config_struct.Phase] == this_phase) & cond_logical;
            if nargin > 3
                block_logical = ([config_struct.Block] == this_block) & phase_logical;
                if nargin > 4
                    trial_logical = ([config_struct.Trial] == this_trial) & block_logical;
                    % if phase and block and trial were all input, return
                    % rows for trial within block within phase:
                    rows = find( trial_logical );
                    return
                end
                % if phase and block were input but nothing else, return
                % rows for block within phase:
                rows = find( block_logical );
                return
            end
            % if phase was input but nothing else, return rows for that phase:
            rows = find( phase_logical );
            return
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

%% FXN_pad_struct
    function [struct] = pad_struct (config_struct)
        
        struct = config_struct;
        struct = pad_col('Condition' ,struct);
        struct = pad_col('Phase'     ,struct);
        struct = pad_col('Block'     ,struct);
        struct = pad_col('Trial'     ,struct);
        
        % Helper function:
        function [new_struct] = pad_col (col_name, config_struct)
            
            column     = cellfun(@num2str, { config_struct.(col_name) }, 'UniformOutput', 0);
            col_len    = length(column);
            stim_paths = cell(col_len, 1); % pre-allocate
            
            % For each column entry...
            for i = 1:col_len
                
                 if strcmpi(col_name, 'trial')
                    % For the 'trial' column, they don't have to specify
                    % number of trials, it can be determined based on
                    % stimuli path:
                    
                    % Get stim information:
                    stim_path = config_struct(i).('Stimuli');
                    if      isempty( strfind( config_struct(i).('Stimuli') , '.' ) ) ...
                        &&  isempty( strfind( config_struct(i).('StimType'), 'custom') )
                        % is directory
                        stim_paths{i} = comb_dir(stim_path, 1);
                        stim_paths{i} = stim_paths{i}(cellfun(@(x) ~iscell(x), stim_paths{i})); %no subdirs
                    else
                        % is specific file
                        stim_paths{i} = {stim_path};
                        if strcmpi(column{i}, 'auto')
                            error(['The "auto" setting may only be applied to entire blocks, whose' ...
                                ' "stimuli" field points to a folder.']);
                        end
                    end
                    
                    % Check if they specified 'auto'. if so, assign a trial
                    % length based on numstim:
                    if strcmpi(column{i}, 'auto')
                        num_trials = length( stim_paths{i} ); % num stim
                        column{i} = ['1:' num2str(num_trials)];
                    end
                end
                
                % check the entered value (e.g., '1:36'), expand it into a full vector:
                elem = column{i};
                elem_expr = strrep(elem,'"',''); % remove quotes
                expanded_elem = eval( elem_expr );
                
                if strcmpi(col_name, 'trial')
                    % For the 'trial' column, they don't have to specify
                    % specific stimuli, but instead can specify a folder.
                    
                    num_trials = length(expanded_elem);
                    num_stim   = length(stim_paths{i});
                    
                    if num_stim < num_trials
                        % If this folder's numstim < numtrials, loop over stim
                        multipl = floor( num_trials / num_stim );
                        ind = repmat( 1:num_stim, 1, multipl);
                        diff = num_trials - length(ind);
                        if config_struct(i).('Random')
                            leftover = randsample(num_stim, diff);
                        else
                            leftover = 1:diff;
                        end
                        ind = [ind leftover]; %#ok<AGROW>
                    else
                        % If this folder's numstim > numtrials, select subset:
                        % (if it's not a folder, this code does nothing)
                        if config_struct(i).('Random')
                            % randomly select num_trials # of stimuli from
                            % the folder:
                            ind = randsample(num_stim, num_trials);
                        else
                            ind = 1:num_trials; % or should it be 'ind = expanded_elem'?
                        end
                    end
                    
                    stim_paths{i} = stim_paths{i}(ind); % select the subset/superset
                    
                end
                
                % For the expanded values, make new rows, append them to
                % new struct:
                for t = 1:length(expanded_elem)
                    if exist('new_struct','var')
                        len = length(new_struct);
                    else
                        len = 0;
                    end
                    
                    new_struct(len+1) = config_struct(i);  %#ok<AGROW>
                    % insert row into new structure
                    new_struct(len+1).(col_name) = expanded_elem(t); %#ok<AGROW>
                    % place the proper value in that row (e.g., replace
                    % '1:36' with the value of t)
                    
                    if strcmpi(col_name, 'trial')
                        % Place the proper value for 'stimuli' (e.g.,
                        % specific filepath replaces folder path)
                        new_struct(len+1).('Stimuli') = stim_paths{i}{t}; %#ok<AGROW>
                    end
                end   % each row in new table
                
            end % each row in orig table
            
        end % helper function
    end

end