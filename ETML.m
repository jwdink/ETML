function [exp_err] = ETML (base_dir, session_info)

exp_err = [];

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

% Check if ETML was called with custom run info (e.g., subject number, age, etc.):
if nargin < 1
    session_info = [];
end

cd(session.base_dir); % change directory

% Load the tab-delimited configuration files:
session.config = ReadStructsFromTextW('config.txt');
stim_config = ReadStructsFromTextW('stim_config.txt');

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
        ' ' num2str(hour) '-' num2str(minute) '-' num2str(round(sec)) ];
    
    % Dummy mode (mouse=eyes):
    session.dummy_mode = get_config('DummyMode', 0); 
    
    % Debugging tools (e.g. windowed):
    session.debug_mode = get_config('DebugMode', 0);     
    if session.debug_mode
        session.experimenter = 'null';
        session.subject_code = '0';
        session.condition = 1;
    end
    
    % Prompt for information about this session
    if isempty(session_info)
        if ~session.debug_mode
            % no session info was added on call, ask for the basics:
            session.experimenter = input('Enter your (experimenter) initials: ','s');
            session.subject_code = input('Enter subject code: ', 's');
            session.condition = str2double( input('Enter condition: ', 's') );
        end
    else 
        % custom session info was added on call
        sinfo_fnames = fieldnames(session_info);
        if all( is_in_cellarray({'experimenter', 'subject_code', 'condition'}, sinfo_fnames) )
            for this_field = sinfo_fnames
                session.(this_field) = session_info.(this_field);
            end
        else
            error('Session info must have following fields: "experimenter," "subject_code," "condition."')
        end   
    end
    
    % Find out which phases will be recording:
    session.record_phases = eval(get_config('RecordingPhases', 'error'));
    
    % Make trial-data folder:
    mkdir('data', session.subject_code);
    mkdir('logs')
    mkdir('sessions')
    
    % Re-Format the Stimuli Config file into a useful table:
    stim_config_full = pad_struct(stim_config);
    trial_record_path = ['data/', session.subject_code, '/' 'unshuffled_experiment_structure.txt'];
    WriteStructsToText(trial_record_path, stim_config_full); % for debugging
    
    % Begin logging now
    session.fileID = fopen([ 'logs/' session.subject_code '-' session.start_time '.txt'],'w');
    fclose(session.fileID);
    log_msg(sprintf('Set base dir: %s', session.base_dir));
    log_msg(sprintf('Study name: %s',get_config('StudyName', 'error')));
    log_msg(sprintf('Random seed set as %s via "twister"',num2str(session.random_seed)));
    sfnames = fieldnames(session);
    for i = 1:length(sfnames)
        this_field = sfnames{i};
        if (ischar(session.(this_field)) || isnumeric(session.(this_field)))
            log_msg([this_field ' : ' num2str(session.(this_field))] );
        end
    end
    
    % Initiate data structure for session file
    session.data = struct('key',{},'value',{});
    session.skip_comments = get_config('SkipComments');
    if isempty(session.skip_comments); session.skip_comments = 0; end;
    
    % Key controls
    session.next_key = 'RightArrow';
    session.prev_key = 'LeftArrow';
    
     session.keys_of_interest = eval_field( get_config('KeysOfInterest') );
    
    % Wait for experimenter to press Enter to begin
    disp(upper(sprintf('\n\n********Press any key to launch the experiment window********\n\n')));
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
    end
    
    hc = get_config('HideCursor', 1);
    if hc && ~session.debug_mode % nohide for debug
        HideCursor();
    end
    
    % Create window
    session.background_color = repmat( get_config('BackgroundColor', 125) , 1, 3); % default gray
    resolution = eval(get_config('ScreenRes', '1024,768'));
    if session.debug_mode
        refresh_rate = [];
    else
        refresh_rate = get_config('RefreshRate', 60);
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
    Screen('TextColor', wind, text_color);
    
    log_msg(sprintf('Screen resolution is %s by %s',num2str(session.swidth),num2str(session.sheight)));
    
    %% SET UP EYETRACKER
    try
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
            ' not be connected. Press enter to continue.'], 'center', 'center');
        Screen('Flip', wind);
        
        if ~EyelinkInit(get_config('DummyMode'), 1)
            error(sprintf('Eyelink Init failed.\n')); %#ok<SPERR>
        end
        
        [~, vs] = Eyelink('GetTrackerVersion');
        log_msg(sprintf('Running experiment on a ''%d'' tracker.\n', vs ));
        
        % Set-up edf file
        session.edf_file = [session.subject_code '.edf'];
        edfERR  = Eyelink('Openfile', session.edf_file);
        
        if edfERR~=0
            error(sprintf('Cannot create EDF file ''%s'' ', session.edf_file)); %#ok<SPERR>
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
        
    catch err
        % Just give warning message if unable to connect to ET
        warning(err.message)
        log_msg(err.message)
        el = struct();
        
        DrawFormattedText(wind, 'Unable to connect to Eyelink system. Press any key to continue', 'center', 'center');
        Screen('Flip', wind);
        while KbCheck; end;
        KbWait;
        
    end
    
    %% RUN EXPERIMENT TRIALS %%
    
    % Wait to begin experiment:
    Screen('TextSize', wind, 25);
    DrawFormattedText(wind, 'Press any key to begin.', 'center', 'center');
    Screen('Flip', wind);
     KbWait([], 2);
    log_msg('Experimenter has begun experiment.');

    % Main loop:
    phases = unique( [stim_config_full.('PhaseNum')] );
    this_phase = 0;
    while this_phase < length(phases)
        this_phase = this_phase + 1;
        session.this_phase = this_phase;
        
        % On Each Phase:
        this_phase_rows = get_rows(stim_config_full, session.condition, this_phase);
        
        % Calibrate the Eye Tracker?:
        et_calibrate(wind, this_phase)
        
        % Run Blocks:
        blocks = unique( [stim_config_full(this_phase_rows).('BlockNum')] );
        
        % Shuffle block order?:
        if get_trial_config(stim_config_full(this_phase_rows(1)), 'BlockShuffle')
            log_msg('Shuffling blocks in this phase');
            bidx = randperm(length(trials));
            blocks = blocks(bidx);
        end
        
        block_index = 0;
        while block_index < length(blocks)
            % Get BlockNum:
            % block index is order of presentation
            % this_block is original block numbering from stim config
            block_index = block_index + 1; % this gets sent everywhere
            this_block = blocks(block_index); % this gets logged, but not sent to ET or session
            
            % On Each Block:
            this_block_rows = get_rows(stim_config_full, session.condition, this_phase, this_block);
            
            % Do drift correct?:
            if session.record_phases(this_phase)
                log_msg('Doing drift correct...');
                drift_correct
            end
            
            % Run Trials:
            trials = unique( [stim_config_full(this_block_rows).('TrialNum')] );
            
            % Shuffle trial order?:
            if get_trial_config(stim_config_full(this_block_rows(1)), 'TrialShuffle')
                trials = shuffle_trials(trials, stim_config_full(this_block_rows(1)) ); 
            end
            
            new_trial_index = 1;
            trial_index = 1;
            while trial_index < length(trials)
                % Update Trial Index:
                trial_index = new_trial_index; % this gets sent to ET data, session file, and log
                
                % Trial Index cannot be less than 1:
                if trial_index < 1
                    trial_index = 1;
                end
                
                % Get Trial Number:
                % Trial Index is order of presentation
                % this_trial is original numbering from stim config
                this_trial = trials(trial_index); % this gets logged, but not sent to ET or session
                
                % On Each Trial:
                this_trial_row = get_rows(stim_config_full, session.condition, this_phase, this_block, this_trial);
                check_trial(this_trial_row, trial_record_path)
                
                %%% Run Trial:
                start_trial(trial_index, block_index, stim_config_full(this_trial_row));
                
                if ~exist('out_struct', 'var')
                    out_struct = struct();
                end
                
                [new_trial_index, out_struct, key_summary] =...
                    show_stimuli(wind, trial_index , stim_config_full(this_trial_row), out_struct, GL);
                
                stop_trial(trial_index, block_index, stim_config_full(this_trial_row), key_summary);
                %%%
            end
        end
    end
    
    post_experiment(0); % end experiment
    
    
catch exp_err
        
    log_msg(exp_err.message);
    log_msg(num2str([exp_err.stack.line]));
    
    sca;
    
    if ~strcmpi('Experiment Ended.' , exp_err.message) && ~session.debug_mode
        h= msgbox({'Experiment has encountered an error and shut down.'...
            ['MSG: ' exp_err.message] ['LINE:' num2str([exp_err.stack.line])] ...
            'Press OK to save results so far, and save err msg to log.' ...
            'You should let the experiment owner know about this error.'}, ...
        'Error', 'error');
        uiwait(h)
    end
    
    if ~strcmpi(exp_err.message,'Experiment ended.')
        post_experiment(true);
    end
    
end

%% FXN_shuffle_trials
    function trials = shuffle_trials(trials, this_trial_config)
        
        draw_meth = get_trial_config(this_trial_config, 'StimDrawFromFolderMethod');
        if strcmpi(draw_meth, 'sample')
            shufmsg = ['You''ve selected incompatible options: trial shuffling'...
                ' and non-consecutive stimuli sampling. Ignoring the former.'];
            warning(shufmsg); %#ok<WNTAG>
            log_msg(shufmsg);
        else
            log_msg('Shuffling trials in this block');
            tidx = randperm(length(trials));
            trials = trials(tidx);
        end
        
    end

%% FXN_check_trial
    function check_trial(this_trial_row, trial_record_path)
        if length(this_trial_row) > 1
            log_msg(['Please check: ' trial_record_path]);
            error(['Attempted to find a unique row corresponding to this trial, but there were multiple.'...
            ' Check unshuffled_experiment_structure.txt (see path above). Something is probably wrong with stim_config.'])
        elseif isempty(this_trial_row)
            log_msg(['Please check: ' trial_record_path]);
            error(['Attempted to find a unique row corresponding to this trial, but none exists.' ...
            'Check unshuffled_experiment_structure.txt (see path above). Something is probably wrong with stim_config.']);
        end
    end

%% FXN_et_calibrate
    function et_calibrate(wind, this_phase)
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
    end

%% FXN_show_stimuli
    function [new_trial_index, out_struct, key_summary] = show_stimuli (wind, trial_index, trial_config, out_struct, GL)
        
        % Show Before Message:
        while KbCheck; end;
        show_text(wind, trial_config, 'Before');
        
        % Summarize Keypresses?
        if isempty( session.keys_of_interest )
            key_summary = [];
        else
            key_summary = struct();
        end
        
        % Show Stim:
        stim_type = lower( get_trial_config(trial_config, 'StimType') );
        
        if any( is_in_cellarray( stim_type , {'image', 'img', 'slideshow'} ) )
            
            % Image: 
            [new_trial_index, key_summary] = ...
                show_img(wind, trial_index, trial_config, GL, key_summary);
            
        elseif is_in_cellarray( stim_type , {'vid', 'video'} )
            
            % Video: 
            [new_trial_index, key_summary] = ...
                show_vid(wind, trial_index, trial_config, GL, key_summary);
            
        elseif strcmp(stim_type, 'custom')
            
            % Custom Script: 
            [new_trial_index, out_struct] =...
                custom_function(wind, trial_index, trial_config, out_struct);
            
        else
            errmsg = ['StimType "' stim_type '" is unsupported.'];
            error(errmsg);
        end
        
        % Show After Message: 
        while KbCheck; end;
        key_summary = show_text(wind, trial_config, 'After', key_summary);
        
    end

%% FXN_start_trial
    function start_trial(trial_index, block_index, trial_config)
        
        if session.record_phases(trial_config.('PhaseNum'));
            Eyelink('StartRecording');
            log_msg(...
                ['START_RECORDING_PHASE_', num2str(trial_config.('PhaseNum')),...
                '_BLOCK_',                 num2str(block_index),...
                '_TRIAL_',                 num2str(trial_index)]);
        end

        % 
        add_data('TrialNum', trial_index);
        add_data('BlockNum', block_index);
        other_fields1 = {'Condition', 'PhaseNum', 'Stim', 'StimType', 'FlipX', 'FlipY'};
        other_fields2 = eval_field( get_config('CustomFields') );
        other_fields = [other_fields1 other_fields2];
        % also some fields that will be inserted at stim-presentation (because they can be dynamically set):
        % 'DimX', 'DimY','StimCenterX', 'StimCenterY', 'duration'
        for f = 1:length(other_fields)
            field = other_fields{f};
            if isfield(trial_config,field)
                add_data(field, trial_config.(field));
            end
        end

    end

%% FXN_stop_trial
    function stop_trial(trial_index, block_index, trial_config, key_summary)
       
        % Save Keypress Data
        if ~isempty(key_summary)
            ks_fnames = fieldnames(key_summary);
            for f = 1:length(ks_fnames)
                field = ks_fnames{f};
                this_key_summary = key_summary.(field);
                
                % Count, CumuTime:
                add_data(['Key_' upper(field) '_PressCount'], num2str(this_key_summary{1}) );
                add_data(['Key_' upper(field) '_CumuPress'], num2str(this_key_summary{2})  );
                
                % First Press:
                add_data(['Key_' upper(field) '_FirstPressTimestamp'], time_to_timestamp(this_key_summary{3}) );
                add_data(['Key_' upper(field) '_LastPressTimestamp'], time_to_timestamp(this_key_summary{4}) );
            end
        end
        
        % End trial
        if session.record_phases(trial_config.('PhaseNum'));
            % ET was recording:
            log_msg(...
                ['STOP_RECORDING_PHASE_',  num2str(trial_config.('PhaseNum')),...
                '_BLOCK_',                 num2str(block_index),...
                '_TRIAL_',                 num2str(trial_index)] );
            log_msg('StopRecording');
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

        if session.record_phases(trial_config.('PhaseNum'))
            
            if nargin < 3
                imgpath = trial_config.('Stim');
            else
                image_array = Screen('GetImage', tex ); 
                imgname = ['img' ...
                    '_phase_' num2str(trial_config.('PhaseNum')) ...
                    '_block_' num2str(trial_config.('BlockNum')) ...
                    '_trial_' num2str(trial_index) '.jpg' ];
                imgpath = ['data/', session.subject_code, '/' imgname];
                imwrite(image_array, imgpath);
            end
            
            log_msg(sprintf('!V IMGLOAD CENTER %s %d %d', imgpath, session.swidth/2, session.sheight/2)); % send to ET
            
        end
    end

%% FXN_show_text
    function key_summary = show_text(wind, trial_config, before_or_after, key_summary)
        
        if nargin < 4
            key_summary = [];
        end
        
        while KbCheck; end;
        
        before_or_after(1) = upper( before_or_after(1) ); % camelcase
        
        % What text to display?
        the_text = get_trial_config(trial_config, [before_or_after 'StimText'] );
        if isempty(the_text)
            return
        end
        
        % How long?
        [duration, min_duration] = set_duration(trial_config, before_or_after);
        
        % Draw:
        DrawFormattedText(wind, the_text, 'center', 'center');
        Screen('Flip', wind);
        text_start = GetSecs();
        
        % Wait For KeyPress:
        key_code = check_keypress();
        while 1
            [key_code, key_summary] = check_keypress(key_code, key_summary);
            
            if GetSecs() - text_start >= duration
                break % end 
            end
            
            if any(key_code)
                if GetSecs() - text_start >= min_duration
                    break % end
                end
            end
        end
        
        [~, key_summary] = check_keypress(key_code, key_summary, 'flush');
        
        return
        
        %
        function [duration, min_duration] = set_duration(trial_config, before_or_after)
            
            dur_field = get_trial_config(trial_config, [before_or_after(1) 'STDuration']);
            dur_config = eval_field(dur_field);
            
            if length(dur_config) > 1
                duration = dur_config(2);
                min_duration = dur_config(1);
            else
                if isempty(dur_config) || dur_config == 0
                    duration = Inf;
                    min_duration = 0;
                else
                    duration = dur_config;
                    min_duration = duration;
                end
            end
            
        end
        
    end

%% FXN_show_vid
    function [new_trial_index, key_summary] = show_vid(wind, trial_index, trial_config, GL, key_summary)
        
        if nargin < 5
            key_summary = [];
        end
        
        % Open Movie(s):
        win_rect = session.win_rect; % so that repetitive loop doesn't have to access global var
        [movie mov_dur fps imgw imgh] = ...
            Screen('OpenMovie', wind, [session.base_dir trial_config.('Stim')] ); %#ok<NASGU,ASGLU>

        % Duration, duration-jitter:
        [duration, min_duration] = set_duration(trial_config, mov_dur);

        % Save Stim Attributes:
        tex = Screen('GetMovieImage', wind, movie, [], 1); % get image from movie 1 sec in
        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect, 'save_stim_info');
        Screen('FillRect', wind, session.background_color, session.win_rect);
        Screen('Close',tex);
        Screen('Flip', wind); Screen('Flip', wind);
        
        % Start playback:
        Screen('PlayMovie', movie , mov_rate);
        WaitSecs(.10);
        Screen('SetMovieTimeIndex', movie, 0);

        log_msg( sprintf('Playing Video: %s', trial_config.('Stim')) );
        vid_start_clock = clock;
        vid_start = GetSecs();
        
        key_code = check_keypress();
        while 1
            [key_code,key_summary] = check_keypress(key_code, key_summary);
            
            if GetSecs() - vid_start >= duration
                break % end movie
            end
            
            if any(key_code)
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
        log_msg( sprintf('Dropped frames: %d', dropped_frames) );
        Screen('CloseMovie', movie);
        Screen('Flip', wind);
        log_msg('Video is over.');
        
        % Stop Time:
        vid_stop_clock = clock;
        vid_stop_clock_str = time_to_timestamp(vid_stop_clock);
        add_data('StimStopTimestamp', vid_stop_clock_str);
        
        % Start Time:
        vid_start_clock_str = time_to_timestamp(vid_start_clock);
        add_data('StimStartTimestamp', vid_start_clock_str);
        
        % KB:
        [~, key_summary] = check_keypress(key_code, key_summary, 'flush'); % flush currently pressed keys
        
        Screen('Flip', wind);
        new_trial_index = trial_index + 1;

        %
        function [duration, min_duration] = set_duration(trial_config, mov_dur)
            
            dur_field = get_trial_config(trial_config, 'StimDuration');
            dur_config = eval_field(dur_field);
            
            if length(dur_config) > 1 % they specified min and max
                duration = dur_config(2);
                min_duration = dur_config(1);
            else
                if isempty(dur_config) || dur_config == 0 % they specified nothing
                    duration = mov_dur;
                    min_duration = mov_dur;
                else                                      % they specified single number, use as min & max
                    duration = dur_config;
                    min_duration = dur_config;
                end
            end
            
        end
       
    end

%% FXN_show_img
    function [new_trial_index, key_summary] = show_img (wind, trial_index, trial_config, GL, key_summary)
        
        stim_path = trial_config.('Stim');
        win_rect = session.win_rect;
        
        % Get trial info about stim duration:
        [duration, min_duration] = set_duration(trial_config);
        
        % Slideshow:
        slideshow = strcmpi('slideshow', trial_config.('StimType'));

        % Get image:
        image = imread(stim_path);                                      % read in image file
        tex = Screen('MakeTexture', wind, image, [], [], [], 1);        % make texture
        draw_tex(wind, tex, trial_index, trial_config, GL, win_rect, 'save_stim_info'); % draw
        
        save_img_for_dv(trial_index, trial_config);
        
        while KbCheck; end; % if keypress from prev slide is still happening, we wait til its over
        log_msg( sprintf('Displaying Image: %s', stim_path) );
        img_start_clock = clock;
        image_start = GetSecs();
        Screen('Flip', wind);
        
        close_image = 0;
        key_code = check_keypress();
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
            
            [key_code, key_summary] = check_keypress(key_code, key_summary);
            
            if slideshow
                % if it's a slideshow, then they can sift thru the slides
                if     strcmpi(KbName(key_code), session.next_key)
                    close_image = 1;
                    new_trial_index = trial_index + 1;
                elseif strcmpi(KbName(key_code), session.prev_key)
                    close_image = 1;
                    new_trial_index = trial_index - 1;
                end
            else
                % if it's an image, advance on keypress, assuming it's been
                % up for minimum amount of time
                if any(key_code)
                    if GetSecs() > (image_start + min_duration)
                        close_image = 1;
                        new_trial_index = trial_index + 1;
                    end
                end
            end
                    
            
        end
        
        % Stop Time:
        img_stop_clock = clock;
        img_stop_clock_str = time_to_timestamp(img_stop_clock);
        add_data('StimStopTimestamp', img_stop_clock_str);
        
        % Start Time:
        img_start_clock_str = time_to_timestamp(img_start_clock);
        add_data('StimStartTimestamp', img_start_clock_str);
        
        % KB:
        [~, key_summary] = check_keypress(key_code, key_summary, 'flush'); % flush currently pressed keys
        
        %
        function [duration, min_duration] = set_duration(trial_config)
            
            dur_field = get_trial_config(trial_config, 'StimDuration');
            dur_config = eval_field(dur_field);
            
            if length(dur_config) > 1 % they specified min and max
                duration = dur_config(2);
                min_duration = dur_config(1);
            else
                if isempty(dur_config) || dur_config == 0 % they specified nothing
                    duration = Inf;
                    min_duration = 0;
                else                                      % they specified single number, use as min & max
                    duration = dur_config;
                    min_duration = dur_config;
                end
            end
            
        end
       
        
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
        flipx = get_trial_config(trial_config, 'FlipX');
        flipy = get_trial_config(trial_config, 'FlipY');
        if flipx; x = -1; else x = 1; end;
        if flipy; y = -1; else y = 1; end
        
        % Texture Dimensions:
        tex_rect = Screen('Rect', tex);
        % original texrect, before stretching. required for flipX,Y to work:
        tex_rect_o = tex_rect;
        theight = tex_rect_o(4) - tex_rect_o(2);
        twidth  = tex_rect_o(3) - tex_rect_o(1);
        
        % Get Dim config:
        dim_x = get_trial_config(trial_config, 'DimX', tex_rect(3) );
        dim_y = get_trial_config(trial_config, 'DimY', tex_rect(4) );
        tex_rect([1 3]) = [0 dim_x];
        tex_rect([2 4]) = [0 dim_y];
        
        % Get Pos config:
        center_x = get_trial_config(trial_config, 'StimCenterX', win_rect(3) / 2);
        center_y = get_trial_config(trial_config, 'StimCenterY', win_rect(4) / 2);
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
            add_data('StimDimY', theight );
            add_data('StimDimX', twidth );
            add_data('StimCenterX', center_x );
            add_data('StimCenterY', center_y );
            
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
            phase_logical = ([config_struct.PhaseNum] == this_phase) & cond_logical;
            if nargin > 3
                block_logical = ([config_struct.BlockNum] == this_block) & phase_logical;
                if nargin > 4
                    trial_logical = ([config_struct.TrialNum] == this_trial) & block_logical;
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

end