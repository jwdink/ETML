%% FXN_save_img_for_dv
function save_img_for_dv (trial_index, trial_config, tex)

global session

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
