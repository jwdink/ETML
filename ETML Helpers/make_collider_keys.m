function [keyframes1, keyframes2] = ...
    make_collider_keys(trial_config, dim, vel, stroke_dur, col_pos_x, prop_overlap, pause_jitter, num_loops)
%MAKE_COLLIDER_KEYS Makes keyframes for objects colliding back-and-forth
%   This generates the keyframes for two objects, to be fed into two separate objects of class
%   ptbob. The keyframes will make them bounce back-and-forth, pausing in between bounces for a
%   jittered amount.

dff = trial_config.('DistFromFix'); % dist from fixation (in px). negative flips to other side of fix

keyframes1 = [];
keyframes2 = [];
lte = 0; % last trial ended
for i = 1:num_loops
    % Times:
    ob1_pause = randi(pause_jitter);
    ob2_pause = randi(pause_jitter);
    ob1_start1 = ob1_pause;
    ob1_stop1  = ob1_start1 + stroke_dur;
    ob2_start1 = ob1_stop1;
    ob2_stop1  = ob2_start1 + stroke_dur;
    ob2_start2 = ob2_stop1 + ob2_pause;
    ob2_stop2  = ob2_start2 + stroke_dur;
    ob1_start2 = ob2_stop2;
    ob1_stop2  = ob1_start2 + stroke_dur;
    end_trial  = ob1_stop2;
    
    % Positions:
    ob1_mid_pos_x = col_pos_x - (dim/2 * (1-prop_overlap));  % where is object1 when it collides?
    ob1_start_pos_x = ob1_mid_pos_x - vel * stroke_dur;    % where is object1 initially?
    ob2_mid_pos_x = col_pos_x + (dim/2 * (1-prop_overlap));
    ob2_stop_pos_x = ob2_mid_pos_x + vel * stroke_dur;
    
    colnames = {'time', 'x', 'y', 'role', 'loopnum'}; %#ok<NASGU>
    
    keyframes1 = vertcat(keyframes1, ...
        [lte                 ob1_start_pos_x  dff 0    i; ... % loop start
        lte + ob1_start1     ob1_start_pos_x  dff 1    i; ... % object1 moves to collide
        lte + ob1_stop1      ob1_mid_pos_x    dff 1    i; ... % object1 collides, stops
        lte + ob2_stop1      ob1_mid_pos_x    dff 0    i; ... % object2 lands, ob1 no longer the "cause"
        lte + ob2_start2     ob1_mid_pos_x    dff 2    i; ... % object2 moves to collide
        lte + ob1_start2     ob1_mid_pos_x    dff 2    i; ... % object1 gets hit, moves
        lte + ob1_stop2      ob1_start_pos_x  dff 0    i; ... % object1 stops at border/ loop end
        ]); %#ok<AGROW>
    keyframes2 = vertcat(keyframes2, ...
        [lte                 ob2_mid_pos_x    dff 0    i; ... % loop start
        lte + ob1_start1     ob2_mid_pos_x    dff 2    i; ... % object1 moves to collide
        lte + ob2_start1     ob2_mid_pos_x    dff 2    i; ... % object2 gets hit, moves
        lte + ob2_stop1      ob2_stop_pos_x   dff 0    i; ... % object2 stops at border
        lte + ob2_start2     ob2_stop_pos_x   dff 1    i; ... % object2 moves to collide
        lte + ob2_stop2      ob2_mid_pos_x    dff 1    i; ... % object2 collides, stops
        lte + end_trial      ob2_mid_pos_x    dff 0    i; ... % loop end
        ]); %#ok<AGROW>
    lte = lte + end_trial; % this (about to be last) trial end time
    
end
end
