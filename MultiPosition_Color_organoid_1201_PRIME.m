%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% | Version | Commit
% | 20200601| low exposure change, add counte to break dead loop @HF
% | 20200615| skip well center point @HF
% | 20200624| Add multi color support
% | 20200628| Rotate emis0sion filter
% | 20200730| For Autophagy project @ZY @HF
% | 20201104| For organoid @HF
% | 20201109| add GFP channel, update information struture
% | 20201201| remove exposure waiting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 0-5: 

data_dir = 'd:\td\20201201';
PFS = 4000/40;

if exist('mmc', 'var')
    warning('Dont initialize MMCore again!');
else
    import mmcorej.*
    mmc= CMMCore;
    config = 'C:\users\qblab\Documents\MMConfig_Ti_Color_PRIME.cfg'; % Point to PRIME configure file
    mmc.loadSystemConfiguration(config);
    mmc.waitForSystem();
    mmc.setTimeoutMs(50000);
end

% HARDWARE SETUP
mmc.setProperty('Spectra', 'State', 1); % enable lumencor
mmc.setProperty('TIXYDrive', 'SpeedX', 1);
mmc.setProperty('TIXYDrive', 'SpeedY', 1);
mmc.setProperty('TILightPath', 'State', '2'); % Use right camera
mmc.setProperty('TINosePiece', 'Label', '1-Plan Apo 4x NA 0.20 Dry'); % objective
mmc.setProperty('TIFilterBlock1', 'Label', '6-S-Qad'); % dimirror
mmc.setProperty('LudlWheel', 'State', '3'); % red emssion filter
W = 2048; H = 2048;
EXPOSURE = 10; %10ms
mmc.setExposure(EXPOSURE);

% EXPERIMENT PARAMETERS
all_pos = importdata('Tandeng_organoid_1201_96well.csv');
% 20201109 6PM, stage is knocked at y by -1400um, x is OK
all_pos(:,2)=all_pos(:,2);%
well_map =  [1 2 3 4 5 6];
pos_num = length(all_pos(:, 1));
pos_per_well = 4;
time_map = zeros(pos_num, 1);
z_gap = - 30; % 20um
z_len =24 ;
z_map = zeros(pos_num, 1);

chsetting(1).name='BF';    chsetting(1).exposure=8;      chsetting(1).level=5;  chsetting(1).em=3;
chsetting(2).name='Green'; chsetting(2).exposure=1000;   chsetting(2).level=100;chsetting(2).em=3;
chsetting(3).name='Cyan';  chsetting(3).exposure=1000;   chsetting(3).level=25; chsetting(3).em=2;

channel_num = length(chsetting);
channel_rolling = [2:channel_num 1]; % don't change it
for ch = 1:channel_num % set excitation light intensity for each channel
    if chsetting(ch).name(1:2) == 'BF'
        mmc.setProperty('Arduino-Switch', 'State', 16);
    else % GFP & mCherry
        %ntensity = chsetting(ch).level;
        mmc.setProperty('Spectra', strcat(chsetting(ch).name, '_Level'), chsetting(ch).level);
        %mmc.setProperty('Lumencor', 'YG_Filter', 1);
    end
end
mmc.setProperty('TIPFSStatus', 'State', 'Off');
%mmc.setPosition(all_pos(1, 3)); % only run at the first time to set zpos

for i =16: pos_num
     %[i 0 mmc.getPosition()]
    disp(i);
    % Set new position and set PFS
    mmc.setXYPosition(all_pos(i, 1), all_pos(i, 2 ));
    mmc.setPosition( all_pos(i, 3) + all_pos(i, 4) );
    img = zeros(W, H, channel_num, 'uint16'); % Prelocate meomer
    well = ceil(i/pos_per_well);
    if mod(i, pos_per_well) == 1
        mmc.sleep(2000);
    else
        mmc.sleep(1000);
    end
    mmc.waitForSystem();
    mmc.setExposure(EXPOSURE);
    
    mmc.waitForSystem();
    z_map(i) = mmc.getPosition(); % save z postion
    
    for z = 1:z_len
        % Capture image time by time
        mmc.setRelativePosition(z_gap);
        for ch = 1:channel_num
            % Update light source
            EXPOSURE = chsetting(ch).exposure;
            name = chsetting(ch).name;
            if chsetting(ch).name(1:2) == 'BF'
                mmc.setProperty('Arduino-Shutter', 'OnOff', 1);
            else % enable excited light
                if chsetting(ch).name(1:2) == 'Gr' %YG filter
                    mmc.setProperty('Spectra', 'YG_Filter', 1);
                end
                mmc.setProperty('Spectra', strcat(name, '_Enable'), 1);
            end
            
            % Update exposure for difference light source
            mmc.setExposure( chsetting(ch).exposure );
            time_map(i) = now;
            %mmc.waitForSystem();
            mmc.sleep(500);
            mmc.snapImage();
            %mmc.sleep(EXPOSURE + 10); % wait for exposure
            img(:, :, z, ch) = uint16( reshape(mmc.getImage(), W, H) );
            
            if chsetting(ch).name(1:2) == 'BF' % close bright field light
                mmc.setProperty('Arduino-Shutter', 'OnOff', 0);
            else
                % close excited light shutter
                mmc.setProperty('Spectra', strcat(name, '_Enable'),  0);
                mmc.setProperty('LudlWheel', 'State', chsetting(channel_rolling(ch)).em ); 
                % change to next em filter
                if chsetting(ch).name(1:2) == 'Gr' %YG filter
                    mmc.setProperty('Spectra', 'YG_Filter', 0);
                end
            end
        end
    end
     options.overwrite = true;
     options.message = false;
     options.compress  = 'no';
    for channel = 1:channel_num
            fname = sprintf('%s/well%dxy%dc%d.tiff', data_dir, well, i, channel);
            saveastiff(img(:, :, :, channel), fname, options);
     end
end
save([data_dir 'all_info.mat'], 'time_map', 'z_map', 'chsetting');
