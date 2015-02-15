function [my_err] = ETML (base_dir, condition, extra_opts)

my_err = [];

%% LOAD CONFIGURATION %%

PsychJavaTrouble;

% Global Structs for this session:
global el 
global session 

% Get experiment directory:
if nargin < 1 || isempty(base_dir)
    session.base_dir = [ uigetdir([], 'Select experiment directory') '/' ];
else
    if strcmpi(base_dir(end), '/')
        session.base_dir = base_dir;
    else
        session.base_dir = [base_dir '/'];
    end
end
if nargin < 3
    extra_opts = {0 0};
end
skip_phase_one = extra_opts{1};
force_debug = extra_opts{2};

cd(session.base_dir); % change directory

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
    
    % Dummy mode (mouse=eyes):
    session.dummy_mode = get_config('DummyMode'); % not tracking eyes
    
    % Debugging tools (e.g. windowed):
    if force_debug
        session.debug_mode = 1;
    else
        session.debug_mode = get_config('DebugMode'); 
    end
    
    if session.debug_mode
        session.experimenter = 'null';
        session.subject_code = '0';
        if nargin < 2
            session.condition = 1;
        else
            session.condition = condition;
        end
        
    else
        session.experimenter = input('Enter your (experimenter) initials: ','s');
        session.subject_code = input('Enter subject code: ', 's');
        if nargin < 2
            session.condition = str2double( input('Enter condition: ', 's') );
        else
            session.condition = condition;
        end
        cpif = get_config('CustomPInfo');
        if isempty(cpif)
            custom_p_info = [];
        else
            custom_p_info = eval(cpif);
            for qind = 1:length(custom_p_info) 
                msg = ['Enter ' custom_p_info{qind} ': '];
                session.(custom_p_info{qind}) = input(msg,'s');
            end
        end
    end
    
    % Find out which phases will be recording (needed before calling
    % log_msg):
    session.record_phases = eval(get_config('RecordingPhases'));
    
    % Make trial-data folder:
    mkdir('data', session.subject_code);
    
    % Re-Format the Stimuli Config file into a useful table:
    stim_config_p = pad_struct(stim_config);
    trial_record_path = ['data/', session.subject_code, '/' 'trial_record.txt'];
    WriteStructsToText(trial_record_path, stim_config_p); % for testing
    
    % Begin logging now
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
    if ~session.debug_mode
        for qind = 1:length(custom_p_info) 
            log_msg(sprintf( [custom_p_info{qind} ': %s '], session.(custom_p_info{qind}) ));
        end
    end
    
    % Initiate data structure for session file
    session.data = struct('key',{},'value',{});
    session.skip_comments = get_config('SkipComments');
    if isempty(session.skip_comments); session.skip_comments = 0; end;
    
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
    
    if session.debug_mode
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
    session.background_color = repmat(get_config('BackgroundColor'), 1, 3);
    resolution = eval(get_config('ScreenRes'));
    if session.debug_mode
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
        if skip_phase_one && this_phase == 1
            this_phase = 2;
        end
        
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
            if stim_config_p(this_block_rows(1)).('ShuffleTrialsInBlock') 
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
                log_msg( sprintf('Trial Index : %d', trial_index) ); % order of presentation
                this_trial = trials(trial_index);
                
                % On Each Trial:
                this_trial_row = get_rows(stim_config_p, session.condition, this_phase, this_block, this_trial);
                if length(this_trial_row) > 1
                    log_msg(['Please check: ' trial_record_path]);
                    error(['Attempted to find a unique row corresponding to this trial, but there were multiple.'...
                        ' Check trial_record (see above). Something is probably wrong with stim_config.'])
                elseif isempty(this_trial_row)
                    error(['Attempted to find a unique row corresponding to this trial, but none exists.' ...
                        'Something is probably wrong with stim_config.']);
                end
                
                %%% Run Trial:
                start_trial(trial_index, stim_config_p(this_trial_row));
                
                if ~exist('out_struct', 'var')
                    out_struct = struct();
                end
                
                [new_trial_index, out_struct] =...
                    show_stimuli(wind, trial_index , stim_config_p(this_trial_row), out_struct, GL);
                
                stop_trial(trial_index, stim_config_p(this_trial_row));
                %%%
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
    function [new_trial_index, out_struct] = show_stimuli (wind, trial_index, trial_config, out_struct, GL)
        
        add_data('stim_type', trial_config.('StimType') );
        
        if     ~isempty( strfind(trial_config.('StimType'), 'img') ) || ...
               ~isempty( strfind(trial_config.('StimType'), 'slideshow') )

            new_trial_index = ...
                show_img(wind, trial_index, trial_config, GL);
            
        elseif strfind(trial_config.('StimType'), 'vid')
            
            new_trial_index = ...
                show_vid(wind, trial_index, trial_config, GL);
            
        elseif ~isempty( strfind(trial_config.('StimType'), 'text') )
            
            new_trial_index = ... 
                show_text(wind, trial_index, trial_config);
            
        elseif ~isempty( strfind(trial_config.('StimType'), 'custom') )
            
            [new_trial_index, out_struct] =...
                custom_function(wind, trial_index, trial_config, out_struct); 
        else
            errmsg = ['StimType "' trial_config.('StimType') '" is unsupported.'];
            error(errmsg);
        end
        
    end

%% FXN_start_trial
    function start_trial(trial_index, trial_config)
        
        if session.record_phases(trial_config.('Phase'));
            % ET is recording:
            phase = trial_config.('Phase');
            
            % Start recording eye position:
            Eyelink('StartRecording');
            log_msg(...
                ['START_RECORDING_PHASE_', num2str(trial_config.('Phase')),...
                '_BLOCK_',                 num2str(trial_config.('Block')),...
                '_TRIAL_',                 num2str(trial_index)], ...
                phase);
        else
            % ET is not recording:
            phase = [];
        end

        % Send variables to EDF (if recording), session txt, and log txt:
        add_data('trial', trial_index, phase);
        other_fields1 = {'Condition', 'Phase', 'Block', 'Stimuli', 'StimType', 'FlipX', 'FlipY'};
        other_fields2 = smart_eval( get_config('CustomFields') );
        other_fields = [other_fields1 other_fields2];
        % also some fields that will be inserted at stim-presentation (because they can be dynamically set):
        % 'DimX', 'DimY','StimCenterX', 'StimCenterY'
        for f = 1:length(other_fields)
            field = other_fields{f};
            if isfield(trial_config,field)
                add_data(field, trial_config.(field), phase);
            end
        end
        
    end

%% FXN_stop_trial
    function stop_trial(trial_index, trial_config)
        
        % End trial
        if session.record_phases(trial_config.('Phase'));
            % ET was recording:
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
        else
            % ET was not recording:
            WaitSecs(.01);
            Screen('Close');
        end
        
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
%% FXN_show_text
    function [new_trial_index] = show_text(wind, trial_index, trial_config)
        
        while KbCheck; end;
        
        % What text to display?
        the_text = trial_config.('Stimuli');
        
        % How long?
        [duration, min_duration] = set_duration(trial_config);
        
        % Get Pos config:
        if isfield(trial_config, 'StimCenterX') && ~is_default(trial_config.StimCenterX)
            center_x = trial_config.StimCenterX;
        else
            center_x = session.win_rect(3) / 2;
        end
        if isfield(trial_config, 'StimCenterY') && ~is_default(trial_config.StimCenterY)
            center_y = trial_config.StimCenterY;
        else
            center_y = session.win_rect(4) / 2;
        end
        
        % Offset from center not from upper right:
        [bbox] = Screen('TextBounds', wind, the_text);
        twid = bbox(3) - bbox(1);
        center_x = center_x - twid/2;
        theight = bbox(4) - bbox(2);
        center_y = center_y - theight/2;
        
        % Draw:
        DrawFormattedText(wind, the_text, center_x, center_y);
        Screen('Flip', wind);
        text_start = GetSecs();
        
        % Wait For KeyPress:
        keycode = check_keypress([], trial_config.('Phase'));
        while 1
            keycode = check_keypress(keycode, trial_config.('Phase'));
            
            if GetSecs() - text_start >= duration
                break % end movie
            end
            
            if sum(keycode)
                if GetSecs() - text_start >= min_duration
                  break % end movie
                end
            end
        end
        
        new_trial_index = trial_index + 1;
        return
        
        %
        function [duration, min_duration] = set_duration(trial_config)
            if isfield(trial_config, 'Duration')
                dur_config = smart_eval(trial_config.('Duration'));
                if length(dur_config) > 1
                    if dur_config(2) == 0
                        duration = Inf;
                    else
                        duration = dur_config(2);
                    end
                    min_duration = dur_config(1);
                else
                    if is_default(dur_config)
                        duration = Inf;
                        min_duration = 0;
                    else
                        duration = dur_config;
                        min_duration = duration;
                    end
                end
            else
                duration = Inf;
                min_duration = 0;
            end
            
        end
        
    end
%% FXN_show_vid
    function [new_trial_index] = show_vid(wind, trial_index, trial_config, GL)
        
        mov_rate = 1;
        
        % Open Movie(s):
        win_rect = session.win_rect; % so that repetitive loop doesn't have to access global var
        [movie mov_dur fps imgw imgh] = ...
            Screen('OpenMovie', wind, [session.base_dir trial_config.('Stimuli')] ); %#ok<NASGU,ASGLU>

        % Custom Start time?:
        [tiv_to_start,mov_dur] = set_tiv_to_start(trial_config, mov_dur);
        
        % Duration, duration-jitter:
        [duration, min_duration] = set_duration(trial_config, mov_dur, mov_rate);

        % Save Stim Attributes:
        tex = Screen('GetMovieImage', wind, movie, [], 1); % get image from movie 1 sec in
        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect, 'save_stim_info');
        Screen('FillRect', wind, session.background_color, session.win_rect);
        Screen('Close',tex);
        Screen('Flip', wind); Screen('Flip', wind);
        
        % Start playback:
        Screen('PlayMovie', movie , mov_rate);
        WaitSecs(.10);
        Screen('SetMovieTimeIndex', movie, tiv_to_start);

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
            if  tex > 0
                draw_tex(wind, tex, trial_index, trial_config, GL, win_rect);
                Screen('Close', tex );
                Screen('Flip',wind, [], 0);
            end
            
        end % end movie loop
        
        % Close Movie(s):
        dropped_frames = Screen('PlayMovie',  movie, 0);
        log_msg( sprintf('Dropped frames: %d', dropped_frames) ,trial_config.('Phase'));
        Screen('CloseMovie', movie);
        Screen('Flip', wind);
        log_msg('Video is over.', trial_config.('Phase'));
        
        Screen('Flip', wind);
        check_keypress(keycode, trial_config.('Phase'), 'flush'); % flush currently pressed keys
        
        new_trial_index = trial_index + 1;
        WaitSecs(.1);

        
        function [tiv_to_start,mov_dur] = set_tiv_to_start(trial_config, mov_dur)
            if isfield(trial_config, 'TimeInVidToStart')
                tiv_config = smart_eval(trial_config.('TimeInVidToStart'));
                if ~is_default(tiv_config)
                    max_tiv = max(tiv_config);
                    min_tiv = min(tiv_config);
                    tiv_to_start = (max_tiv-min_tiv)*rand() + min_tiv;
                    % since we're coming into the film late, its time-left duration
                    % is shoter than its total duration:
                    mov_dur = mov_dur - tiv_to_start;
                else
                    tiv_to_start = 0;
                end
                add_data('tiv_tostart', tiv_to_start, trial_config.('Phase'));
            else
                tiv_to_start = 0;
            end
        end
        
        function [duration, min_duration] = set_duration(trial_config, mov_dur, mov_rate)
            if isfield(trial_config, 'Duration')
                dur_config = smart_eval(trial_config.('Duration'));
                if length(dur_config) > 1
                    if dur_config(2) == 0
                        duration = mov_dur * 1/mov_rate;
                    else
                        duration = dur_config(2);
                    end
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
        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect, 'save_stim_info'); % draw
        
        save_img_for_dv(trial_index, trial_config);
        
        if session.dummy_mode
            % Draw Interest Areas
            % --to do--
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
    function draw_tex (wind, tex, trial_index, trial_config, GL, win_rect, save_stim_info)

        % IMPORTANT: To work in this function, any tex made with
        % Screen('MakeTexture') must have been created with
        % textureOrientation = 1. See Screen('MakeTexture?')
        
        if nargin < 7
            save_stim_info = 0;
        end
        
        % Get Flip Config:
        if isfield(trial_config, 'FlipX') && ~is_default(trial_config.FlipX) && trial_config.FlipX
            x = -1;
        else
            x =  1;
        end
        if isfield(trial_config, 'FlipY') && ~is_default(trial_config.FlipY) && trial_config.FlipY
            y = -1;
        else
            y =  1;
        end
        
        % Texture Dimensions:
        tex_rect = Screen('Rect', tex);
        % original texrect, before stretching. required for flipX,Y to work:
        tex_rect_o = tex_rect;
        theight = tex_rect_o(4) - tex_rect_o(2);
        twidth  = tex_rect_o(3) - tex_rect_o(1);
        
        % Get Dim config:
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
            % else, just use dim of image/vid (tex_rect)
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
            % else, just use dim of image/vid (tex_rect)
        end
        
        % Get Pos config:
        if isfield(trial_config, 'StimCenterX') && ~is_default(trial_config.StimCenterX)
            center_x = trial_config.StimCenterX;
        else
            center_x = win_rect(3) / 2;
        end
        if isfield(trial_config, 'StimCenterY') && ~is_default(trial_config.StimCenterY)
            center_y = trial_config.StimCenterY;
        else
            center_y = win_rect(4) / 2;
        end
        dest_rect = CenterRectOnPoint(tex_rect, center_x, center_y);
        
        % Mirroring/Flipping the texture is done along the center of the tex.
        % Therefore, to flip/mirror properly, we need to displace the texture,
        % flip/mirror it, and then put it back in its original place:
        glMatrixMode(GL.TEXTURE); % needed for some obscure reason.
        glPushMatrix; % needed for some obscure reason.
        glTranslatef(twidth/2, theight/2, 0);
        glScalef(x,y,1);
        glTranslatef(-twidth/2, -theight/2, 0);
        
        % Draw the texture:
        if save_stim_info
            % Record the stimulus dimensions to the data file:
            add_data('StimDimY', theight, trial_config.('Phase') );
            add_data('StimDimX', twidth,  trial_config.('Phase') );
            add_data('StimCenterX', center_x, trial_config.('Phase') );
            add_data('StimCenterY', center_y, trial_config.('Phase') );
            
            if strcmpi( trial_config.('StimType') , 'video' )
                % Draw an example image for the background of a dataviewer
                % application:
                offwind = Screen('OpenOffscreenWindow', wind);
                Screen('DrawTexture', offwind, tex, [], dest_rect);
                save_img_for_dv(trial_index, trial_config, offwind);
                Screen('CopyWindow', offwind, wind);
            else
                Screen('DrawTexture', wind, tex, [], dest_rect);
            end
        else
            Screen('DrawTexture', wind, tex, [], dest_rect);
        end
        
        glMatrixMode(GL.TEXTURE); % don't know what this does
        glPopMatrix; % don't know what this does
        % glMatrixMode(GL.MODELVIEW);  % don't know what this does
        
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
            for row = 1:col_len
                
                 if strcmpi(col_name, 'trial')
                    % For the 'trial' column, they don't have to specify
                    % number of trials, it can be determined based on
                    % stimuli path:
                    
                    % Get stim information:
                    stim_path = config_struct(row).('Stimuli');
                    if      isempty( strfind( config_struct(row).('Stimuli') , '.' ) ) ...
                        &&  isempty( strfind( config_struct(row).('StimType'), 'custom') )
                        % is directory
                        stim_paths{row} = comb_dir(stim_path, 1);
                        stim_paths{row} = stim_paths{row}(cellfun(@(x) ~iscell(x), stim_paths{row})); %no subdirs
                    else
                        % is specific file
                        stim_paths{row} = {stim_path};
                        if strcmpi(column{row}, 'auto')
                            error(['The "auto" setting may only be applied to entire blocks, whose' ...
                                ' "stimuli" field points to a folder.']);
                        end
                    end
                    
                    % Check if they specified 'auto'. if so, assign a trial
                    % length based on numstim:
                    if strcmpi(column{row}, 'auto')
                        num_trials = length( stim_paths{row} ); % num stim
                        column{row} = ['1:' num2str(num_trials)];
                    end
                end
                
                % check the entered value (e.g., '1:36'), expand it into a full vector:
                elem = column{row};
                elem_expr = strrep(elem,'"',''); % remove quotes
                expanded_elem = eval( elem_expr );
                
                if strcmpi(col_name, 'trial')
                    % For the 'trial' column, they don't have to specify
                    % specific stimuli, but instead can specify a folder.
                    
                    num_trials = length(expanded_elem);
                    num_stim   = length(stim_paths{row});
                    
                    if ~is_default( config_struct(row).('RandStimSelection') ) && strcmpi( config_struct(row).('RandStimSelection') , 'replace' )
                        % random, without replacement
                        ind = datasample(1:num_stim, num_trials);
                    else
                        
                        if num_stim < num_trials
                            % If this folder's numstim < numtrials, loop over stim
                            multipl = floor( num_trials / num_stim );
                            ind = repmat( 1:num_stim, 1, multipl);
                            diff = num_trials - length(ind);
                            if ~is_default( config_struct(row).('RandStimSelection') )
                                leftover = randsample(num_stim, diff);
                                ind = [ind leftover]; %#ok<AGROW>
                                ind = ind(randperm(length(ind))); % shuffle
                            else
                                leftover = 1:diff;
                                ind = [ind leftover]; %#ok<AGROW>
                            end
                            
                        else
                            % If this folder's numstim >= numtrials, select subset:
                            % (if it's not a folder, this code does nothing)
                            if ~is_default( config_struct(row).('RandStimSelection') )
                                % randomly select num_trials # of stimuli from
                                % the folder with replacement
                                ind = randsample(num_stim, num_trials);
                                
                            else
                                ind = 1:num_trials; % or should it be 'ind = expanded_elem'?
                            end
                        end
                    end
                    stim_paths{row} = stim_paths{row}(ind); % select the subset/superset
                end
                
                % For the expanded values, make new rows, append them to
                % new struct:
                for t = 1:length(expanded_elem)
                    if exist('new_struct','var')
                        len = length(new_struct);
                    else
                        len = 0;
                    end
                    
                    new_struct(len+1) = config_struct(row);  %#ok<AGROW>
                    % insert row into new structure
                    new_struct(len+1).(col_name) = expanded_elem(t); %#ok<AGROW>
                    % place the proper value in that row (e.g., replace
                    % '1:36' with the value of t)
                    
                    if strcmpi(col_name, 'trial')
                        % Place the proper value for 'stimuli' (e.g.,
                        % specific filepath replaces folder path)
                        new_struct(len+1).('Stimuli') = stim_paths{row}{t}; %#ok<AGROW>
                    end
                end   % each row in new table
                
            end % each row in orig table
            
        end % helper function
    end

end