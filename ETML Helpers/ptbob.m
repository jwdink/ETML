classdef ptbob
    
    methods(Static)
        %% Initialize Object:
        function [obj_struct] = make_new_object(type, keyframes, dim, rgb, fill, specific_params)
            % this function makes an object struct, for usage in the function draw_object
            
            % type of object: circle, rectangle, gaussian-circle, etc.
            % keyframes: a matrix, first column is time in ms (sorted!), 2nd & 3rd are x,y pos in px
            % dim: object dimensions
            % rgb: color of object
            % fill: whether it's filled (only applies to rectangles and circles
            % specific_params: a cell array with various parameters that only apply to specific types.
            
            % Check Input:
            if nargin < 6 || isempty(specific_params)
                specific_params = {};
            end
            if nargin < 5 || isempty(fill)
                fill = 1;
            end
            if nargin < 4 || isempty(rgb)
                rgb = [0 0 0];
            end
               
            if size(keyframes,1) == 1 && size(keyframes,2) == 2
                % if they just specified an xy position for a stationary object, 
                % convert it into the normal keyframe matrix format
                keyframes = [0 keyframes(1) keyframes(2); Inf keyframes(1) keyframes(2)];
            end
            if ~isempty(strfind(type, 'gauss')) || strcmpi('circle', type) || strcmpi('cross', type)
                if length(dim) > 1
                    error('For this type, please supply only diameter (in px) for "dim" arg.')
                end
                dim = [dim dim];
            elseif strcmpi('rect', type)
                error('you haven''t implemented this yet, jacob.');
                if length(dim) ~= 2
                    error('For this type, please supply width,height for "dim" arg.');
                end
            else
                error('Unknown type supplied.')
            end
            
            if ~issorted( keyframes(:,1) )
                error('Keyframes must be sorted')
            end
            
            % Make Struct:
            obj_struct = struct();
            obj_struct.type  = type;
            obj_struct.dim   = dim;
            obj_struct.kf    = keyframes;
            obj_struct.rgb   = rgb;
            obj_struct.invis = 0;
            obj_struct.fill  = fill;
            obj_struct.sp    = specific_params;
            
        end
        
        %% Modify Object:
        % function [obj_struct] = some_modifcation(obj_struct, modifcation_params, ...)
        
        %% Draw Object:
        function draw_object(obj_struct, wind, time, cm)
            % this function generates a psychtoolbox drawing/oval/texture/whatever
            % the struct specifies things like its appearance, movement path, etc.
            
            % obj_struct: the object structure, created by make_new_object
            % wind: the PTB window pointer
            % time: in ms, since the trial-start
            % cm: counter-mask. optional parameter, only for obj type="gauss." helps with equiluminance
            
            if nargin < 4
                cm = 0;
            end
                
            % Find the closest keyframe before current time:
            if time == 0; time = 10^-50; end; % if time = 0 exactly error would be thrown, this prevents
            last_kf = max(obj_struct.kf(:,1));
            if time > last_kf; time = last_kf - 10^-50; end; % if time>=last_kf, keep at last_kf
            
            kf1 = find(obj_struct.kf(:,1) - time < 0, 1, 'last');
            kf2 = kf1+1;
            
            % Extrapolate the time/position between keyframes (e.g., are we 30% between kf1 and kf2? or 99% there?)
            pos = [0 0];
            kf_prop = ( time - obj_struct.kf(kf1,1) ) / ( obj_struct.kf(kf2,1) - obj_struct.kf(kf1,1) );
            pos(1) = ( obj_struct.kf(kf2,2) - obj_struct.kf(kf1,2) ) * kf_prop + obj_struct.kf(kf1,2); % x
            pos(2) = ( obj_struct.kf(kf2,3) - obj_struct.kf(kf1,3) ) * kf_prop + obj_struct.kf(kf1,3); % y
            
            % Determine Destination Rect:
            if ~isempty(strfind(obj_struct.type, 'gauss'))
                mult = 1.35; % gauss looks smaller, so we compensate.
            else
                mult = 2;
            end
            L = pos(1) - obj_struct.dim(1)/mult;
            T = pos(2) - obj_struct.dim(2)/mult;
            R = pos(1) + obj_struct.dim(1)/mult;
            B = pos(2) + obj_struct.dim(2)/mult;
            obj_struct.dest_rect = [L T R B];
            
            % Create ImgMatrix (if needed)
            if strcmpi(obj_struct.type, 'gauss')
                imgmat = make_gauss(obj_struct.dim, obj_struct.rgb, cm);
            elseif strcmpi(obj_struct.type, 'cross')
                if isempty( obj_struct.sp ) 
                    wid = [];
                else
                    wid = obj_struct.sp{1};
                end
                imgmat = make_cross(obj_struct.dim, obj_struct.rgb, wid);
            end
            
            % Draw Object:
            if ~obj_struct.invis
                if strcmpi(obj_struct.type, 'gauss') || strcmpi(obj_struct.type, 'cross')
                    tex = Screen('MakeTexture', wind, imgmat);
                    Screen('DrawTexture', wind, tex, [], obj_struct.dest_rect);
                elseif strcmpi(obj_struct.type, 'circle')
                    if obj_struct.fill
                        Screen('FillOval', wind, obj_struct.rgb, obj_struct.dest_rect);
                    else
                        if isempty( obj_struct.sp )
                            pen_wid = obj_struct.dim(1) / 10;
                        else 
                            pen_wid = obj_struct.sp{1};
                        end
                        Screen('FrameOval', wind, obj_struct.rgb, obj_struct.dest_rect, pen_wid);
                    end
                end
            end
            
            % HELPERS:
            % Make a cross (for fixation):
            function [imgmat] = make_cross(dim, rgb, wid)
                dim = dim(1);
                
                if length(rgb) < 4
                    rgb(4) = 255;
                end
                if isempty(wid)
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
            % Make A Gaussian-Matrix (for Making a Texture):
            function [imgmat] = make_gauss(dim, rgb, cm)
                dim = dim(1);
                
                % Draw the circle in a matrix
                [x y]  = meshgrid((1:dim), (1:dim));
                
                % Draw the 3D normal distribution:
                mask = normpdf(x, dim/2, dim/5) .* normpdf(y, dim/2, dim/5);
                
                % Adjust so that it goes from 0 to 1:
                mask = mask - min(min(mask));
                mask = ( mask / max(max(mask)) );
                
                %
                if cm < 0
                    cm = 0;
                elseif cm > 1
                    cm = .8;
                end
                
                % Make Matrix:
                imgmat(:,:,1) = ones(dim) * rgb(1)/255;  % Red plane
                imgmat(:,:,1) = imgmat(:,:,1) - mask*cm;
                imgmat(:,:,2) = ones(dim) * rgb(2)/255;  % Green plane
                %imgmat(:,:,1) = imgmat(:,:,2) - mask*cm;
                imgmat(:,:,3) = ones(dim) * rgb(3)/255;  % Blue plane
                %imgmat(:,:,1) = imgmat(:,:,3) - mask*cm;
                imgmat(:,:,4) = mask/2;       % Alpha plane
                imgmat = imgmat *255;
            end
            
        end
        
        %% Helper Functions:
        function [keyframes_t] = translate_kf(keyframes, x, y, theta)
            
            % keyframes matrix
            % xy: how to translate coordinate system?
            % theta: how to rotate coordinate system?
            
            if nargin < 4 || isempty(theta)
                theta = 0;
            end
            if nargin < 3 || isempty(y)
                y = 0;
            end
            if nargin < 2 || isempty(x)
                x = 0;
            end
            
            % input:
            a = keyframes(:,2:3)';
            
            % rotate:
            b = [cos(theta)  -sin(theta) ; sin(theta)  cos(theta)] * a;
            
            % translate:
            c = b;
            c(1,:) = c(1,:) + x;
            c(2,:) = c(2,:) + y;
            
            % output:
            keyframes_t = keyframes;
            keyframes_t(:,2:3) = c';
            
            
        end
    end
end








