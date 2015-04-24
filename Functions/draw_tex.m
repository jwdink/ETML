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

