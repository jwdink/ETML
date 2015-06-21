function [exp_err] = ETML (base_dir, session_info)

exp_err = [];

%% LOAD CONFIGURATION %%

PsychJavaTrouble;
KbName('UnifyKeyNames');

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
if nargin < 2
    session_info = [];
end

cd(session.base_dir); % change directory

% Load the tab-delimited configuration files:
session.config = ReadStructsFromTextW('./config.txt');
stim_config = ReadStructsFromTextW('./stim_config.txt');

sprintf('You are running %s\n\n', get_config('StudyName'));


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
        session.subject_code = input('Enter subject code (no longer than 8 chars): ', 's');
        if length(session.subject_code) > 8
            error('Subject code must be no longer than eight characters, or Eyelink will fail.')
        end
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
log_msg(sprintf('Study name: %s',get_config('StudyName', 'error')));
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

% Keys of Interest:
session.keys_of_interest = eval_field( get_config('KeysOfInterest','{}') );
KbName('UnifyKeyNames');

% Wait for experimenter to press Enter to begin
disp(upper(sprintf('\n\n********Press any key to launch the experiment window********\n\n')));
if ~session.debug_mode
    KbWait([], 2);
end

log_msg('Experimenter has launched the experiment window');

try
    %% SET UP SCREEN %%
    
    % An OpenGL struct needed for mirroring texture.
    % Note that this has scope that spans multiple functions, but it's not
    % global. This is to improve performance, but it means this GL var can't
    % be used in other functions not in this script.
    GL = struct();
    InitializeMatlabOpenGL([],[],1);
    
    if session.debug_mode
        % skip sync tests
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
    session.background_color = repmat( get_config('BackgroundColor', 80) , 1, 3); % default gray
    resolution = eval(get_config('ScreenRes', '1024,768'));
    if session.debug_mode
        refresh_rate = [];
    else
        refresh_rate = get_config('RefreshRate', []);
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
        if ~eyelink_init(get_config('DummyMode'), 1)
            error('Eyelink Init failed.'); 
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
        if session.dummy_mode
            warning(err.message)
            log_msg(err.message)
            el = struct();
            
            DrawFormattedText(wind, 'Unable to connect to Eyelink system. Press any key to continue', 'center', 'center');
            Screen('Flip', wind);
            while KbCheck; end;
            KbWait;
        else
            error(err.message)
        end
        
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
        if get_trial_config(stim_config_full(this_phase_rows(1)), 'ShuffleBlocksInPhase')
            log_msg('Shuffling blocks in this phase');
            bidx = randperm(length(blocks));
            blocks = blocks(bidx);
        end
        
        block_index = 0;
        while block_index < length(blocks)
            if block_index == 0 && this_phase == 2
                disp('')
            end
            
            % Get BlockNum:
            % block index is order of presentation
            % this_block is original block numbering from stim config
            block_index = block_index + 1; % this gets sent everywhere
            this_block = blocks(block_index); % this gets logged, but not sent to ET or session
            
            % On Each Block:
            this_block_rows = get_rows(stim_config_full, session.condition, this_phase, this_block);
            
            % Do drift correct?:
            drift_correct(this_phase);
            
            % Run Trials:
            trials = unique( [stim_config_full(this_block_rows).('TrialNum')] );
            
            % Shuffle trial order?:
            if get_trial_config(stim_config_full(this_block_rows(1)), 'ShuffleTrialsInBlock')
                trials = shuffle_trials(trials, stim_config_full, this_block_rows );
            end
            
            new_trial_index = 1;
            trial_index = 0;
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
                
                %% Run Trial:
                trial_start_time = start_trial(trial_index, block_index, stim_config_full(this_trial_row));
                
                if ~exist('out_struct', 'var')
                    out_struct = struct();
                end
                
                [new_trial_index, out_struct, key_summary] = run_trial( ...
                    wind, trial_index , stim_config_full(this_trial_row), out_struct, GL, trial_start_time);
                
                stop_trial(trial_index, block_index, stim_config_full(this_trial_row), key_summary);
                %%%
            end
        end
    end
    
    post_experiment(0); % end experiment
    
    
catch exp_err
    
    sca;
    
    if strcmpi(exp_err.message, 'Experiment Ended.')
        log_msg(exp_err.message)
    else
        log_msg('=======ERROR======')
        log_msg(exp_err.message);
        log_msg('ON LINE:')
        log_msg(num2str([exp_err.stack.line]));
        log_msg('(Last number indicates position in ETML.m)');
        log_msg('==================');
    end
    
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

end