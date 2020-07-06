%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% | Version | Commit
% | 20200601| low exposure change, add counte to break dead loop @HF
% | 20200615| skip well center point @HF
% | 20200624| Add multi color support
% | 20200628| Rotate emission filter
% | 20200701| Use hamamatsu fusion @HF
% | 20200704| Update Well position
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

data_dir = 'F:/llj/exp0706';
PFS = 7431;
z_position = 4227;
if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
	import mmcorej.*
	mmc= CMMCore;
    config = 'C:\users\qblab\Documents\MMConfig_Ti_Color_Hamamatsu.cfg';
	mmc.loadSystemConfiguration(config);
    mmc.waitForSystem();
	mmc.setTimeoutMs(50000);
    %mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti_Color.cfg');
end

% Set ScanMode to Ultra-quiet
mmc.setProperty('HamamatsuHam_DCAM', 'ScanMode', 1); 
mmc.setProperty('Lumencor', 'State', 1); % open lumencor shutter
mmc.setProperty('TIXYDrive', 'SpeedX', 7); %1-9
mmc.setProperty('TIXYDrive', 'SpeedY', 7);
%mmc.setProperry('TILightPath', 'Label', '3-Right100')
mmc.setProperty('TILightPath', 'State', '2'); % Use right camera
mmc.setProperty('TINosePiece', 'Label', '3-Plan Apo 20x NA 0.75 Dry');
mmc.setProperty('TIFilterBlock1', 'Label', '6-S-Qad');
mmc.setProperty('LudlWheel', 'State', '0'); % don't use emission filter

W = 2304; H = 2304;
EXPOSURE = 15; %10ms
mmc.setExposure(EXPOSURE);

%all_pos = [1 2 3400 95; 10 20 3500 95];  % [x y z pfs_offset]
%all_pos = importdata("U24-4XAPO-EB-control-12wells-0525for10x.csv");
%all_pos = importdata("llj_24_well_2well_20x.csv");
all_pos = importdata("LLJ_24well_20x_20200706.csv");
well=0;
well_map =  [9 15];
pos_num = length(all_pos(1, :));
time_map = zeros(pos_num, 1);
z_map = zeros(pos_num, 1);

channel_name = ["BF", "Violet", "Cyan", "Green"];
channel_exposure = [ 15 1000 500 500 ];
channel_level= [ 10 30 20 40];
channel_num = length(channel_exposure);
for ch = 1:channel_num % set channel intensity
    intensity = channel_level(ch);
    if ch == 1 %BF
        mmc.setProperty('Arduino-Switch', 'State', 16);
    else
        mmc.setProperty('Lumencor', strcat(channel_name(ch), "_Level"), intensity);
    end
end

mmc.setProperty('TIPFSStatus', 'State', 'Off');
mmc.setProperty('TIPFSOffset', 'Position', PFS/40);
mmc.setPosition( z_position); % only run at the first time

for i = 1:pos_num
    disp(i);
    % Set new position and set PFS
    mmc.setXYPosition(all_pos(1, i), all_pos(2, i ));
    mmc.waitForDevice('TIXYDrive');
    if mod(i, 49) == 1
        mmc.sleep(20000);
        well = well +1;
    else
        mmc.sleep(5000);
    end
	
    % Use PFS for focus
	mmc.setProperty('TIPFSStatus', 'State', 'On');
	mmc.sleep(4000); %200);
    mmc.waitForSystem();
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
    z_map(i) = mmc.getPosition(); % save z postion
    mmc.setExposure(EXPOSURE);
    mmc.clearCircularBuffer(); % clear camera buffer
    
    fname = sprintf('%s/well%dxy%d.tiff', data_dir, well, i);
    % Capture image time by time
    for channel = 1:channel_num
        % Update light source
        EXPOSURE = channel_exposure( channel );
        name = channel_name(channel);
        % Update exposure for difference light source
        if channel == 1 %bf
            mmc.setProperty('Arduino-Shutter', 'OnOff', 1);
        else % enable excited light
            if channel == 4 %YG filter
                mmc.setProperty('Lumencor', 'YG_Filter', 1);
            end
            mmc.setProperty('Lumencor', strcat(name, "_Enable"), 1);
        end
        mmc.setExposure( EXPOSURE );
        time_map(i) = now;
        mmc.snapImage();
        mmc.sleep(EXPOSURE + 10); % wait for exposure
        img = uint16( reshape(mmc.getImage(), W, H) );
        if channel == 1 % Write first page
            mmc.setProperty('Arduino-Shutter', 'OnOff', 0);
            mmc.setProperty('LudlWheel', 'State', '1'); % change to BFP
            mmc.sleep(200); % wait for 200ms
            options.overwrite = true;
            options.append = false;
            options.message = false;
            saveastiff(img, fname, options);
        else % Append to tiff
            mmc.setProperty('Lumencor', strcat(name, "_Enable"),  0);
            if channel == 2 % BFP
                mmc.setProperty('LudlWheel', 'State', '2');  %change to GFP
                mmc.sleep(200); % wait for 200ms
            end
            if channel == 3 % GFP
                mmc.setProperty('LudlWheel', 'State', '0');  %change to mCherry
                mmc.sleep(200); % wait for 200ms
            end

            if channel == 4 %YG filter
                mmc.setProperty('Lumencor', 'YG_Filter', 0);
            end
            options.overwrite = false;
            options.append = true;
            options.message = false;
            saveastiff(img, fname, options);
        end
    end
end

save([data_dir 'all_info.mat'], 'time_map', 'z_map');
