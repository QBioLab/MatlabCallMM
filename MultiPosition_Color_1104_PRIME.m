%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% | Version | Commit
% | 20200601| low exposure change, add counte to break dead loop @HF
% | 20200615| skip well center point @HF
% | 20200624| Add multi color support
% | 20200628| Rotate emission filter
% | 20200730| For Autophagy project @ZY @HF
% | 20201104| For organoid @HF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

data_dir = 'F:\td\20201105';
PFS = 4000/40;

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
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
%all_pos = importdata("Tandeng_organoid_1103_96well.csv");
all_pos = importdata("Tandeng_organoid_1103_96well_1105.csv");

well_map =  [1 2 3 4 5 6 7 8];
pos_num = length(all_pos(:, 1));
pos_per_well = 4;
time_map = zeros(pos_num, 1);
z_gap = - 15; % 10um
z_len = 20;
z_map = zeros(pos_num, 1);

channel_name = ["BF" , "Green"]; % Bright field & mCherry
channel_exposure = [ 8 1000 ]; %ms
channel_level= [5 100]; % intensity percent
channel_num = length(channel_exposure);
for ch = 1:channel_num % set excitation light intensity for each channel
    if ch == 1 %BF
        mmc.setProperty('Arduino-Switch', 'State', 16);
    else % mCherry
        intensity = channel_level(ch);
        mmc.setProperty('Spectra', strcat(channel_name(ch), "_Level"), intensity);
        %mmc.setProperty('Lumencor', 'YG_Filter', 1);
    end
end
mmc.setProperty('TIPFSStatus', 'State', 'Off');
%mmc.setPosition(all_pos(1, 3)); % only run at the first time to set zpos

for i =1: pos_num
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
    
    % z stack
    %z_shift = all_pos(i, 4); % 10um
    %[i 1 mmc.getPosition()]
    %mmc.setRelativePosition( z_shift ); 
    %mmc.sleep(2000);
    mmc.waitForSystem();
    z_map(i) = mmc.getPosition(); % save z postion
    %[i 2 mmc.getPosition()]
    
    for z = 1:z_len
        % Capture image time by time
        mmc.setRelativePosition(z_gap);
        for channel = 1:channel_num
            % Update light source
            EXPOSURE = channel_exposure( channel );
            name = channel_name(channel);
            if channel == 1 %bf
                mmc.setProperty('Arduino-Shutter', 'OnOff', 1);
            else % enable excited light
                %if channel == 2 %YG filter
                %    mmc.setProperty('Lumencor', 'YG_Filter', 1);
                %end
                mmc.setProperty('Spectra', strcat(name, "_Enable"), 1);
            end
            
            % Update exposure for difference light source
            mmc.setExposure( EXPOSURE );
            time_map(i) = now;
            %mmc.waitForSystem();
            mmc.sleep(500);
            mmc.snapImage();
            mmc.sleep(EXPOSURE + 10); % wait for exposure
            img(:, :, z, channel) = uint16( reshape(mmc.getImage(), W, H) );
            
            if channel == 1 % close bright field light
                mmc.setProperty('Arduino-Shutter', 'OnOff', 0);
            else
                % close excited light shutter
                mmc.setProperty('Spectra', strcat(name, "_Enable"),  0);
                %if channel == 2 % GFP
                %        mmc.setProperty('LudlWheel', 'State', '0');  %change to mCherry
                %    mmc.sleep(200); % wait for 200ms
                %end
                %if channel == 4 %YG filter
                %    mmc.setProperty('Lumencor', 'YG_Filter', 0);
                %end
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
save([data_dir 'all_info.mat'], 'time_map', 'z_map');
    
