%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% | Version | Commit
% | 20200601| low exposure change, add counte to break dead loop @HF
% | 20200615| skip well center point @HF
% | 20200624| Add multi color support
% | 20200628| Rotate emission filter
% | 20200730| For Autophagy project @ZY @HF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

data_dir = 'F:\ZZ\6LED-LC3\20200803';
PFS = 7559; %cannot auto-focus? ask MM

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
	import mmcorej.*
	mmc= CMMCore;
    config = 'C:\users\qblab\Documents\MMConfig_Ti_Color_Hamamatsu.cfg';
	mmc.loadSystemConfiguration(config);
    mmc.waitForSystem();
	mmc.setTimeoutMs(50000);
end

% Set ScanMode
mmc.setProperty('HamamatsuHam_DCAM', 'ScanMode', 2); 
mmc.setProperty('Lumencor', 'State', 1); % enable lumencor
mmc.setProperty('TIXYDrive', 'SpeedX', 1);
mmc.setProperty('TIXYDrive', 'SpeedY', 1);
% mmc.setProperry('TILightPath', 'Label', '3-Right100')
mmc.setProperty('TILightPath', 'State', '2'); % Use right camera
mmc.setProperty('TINosePiece', 'Label', '3-Plan Apo 20x NA 0.75 Dry'); % objective
mmc.setProperty('TIFilterBlock1', 'Label', '6-S-Qad'); % dimirror 
mmc.setProperty('LudlWheel', 'State', '2'); % Inital emssion filter: Calibryte 500 or GFP

W = 2304; H = 2304; %What is W and H? The camera total pixel, which should fit camera
% TODO: You should fit you camera
EXPOSURE = 15; %10ms
mmc.setExposure(EXPOSURE);

z_well=[4080 4140 4190 4250 4170 4100 4120 4190 4240];
all_pos = importdata("6LED-20x6-D1-3-5-13-15-17-10x6-D8-10-12.csv");
well_ps=[0 20 40 60 80 100 120 130 140 ]; % well A1, A3, A5, C1, C3, C5, B2, B4, B6
for i1=1:9
    if i1==1
        j1(1)=1;j1(2)=20;
    elseif i1==9
        j1(2)=150;j1(1)=141;
    else
        j1(1)=well_ps(i1-1)+1;
        j1(2)=well_ps(i1);
    end
    all_pos(3,j1(1):j1(2))=z_well(i1);
end
% TODO: You should fit you objective and well plate
% well=1;
% well_map =  [9 15]; %Why 9 and 15? Just well's label
% TODO: You should fit the well number which you select in well plate
pos_num = length(all_pos(1, :));
time_map = zeros(pos_num, 1);
z_map = zeros(pos_num, 1);

% calibryte 500, GFP, RFP
% channel_name = ["Violet", "Cyan", "Green"]; 
% channel_exposure = [ 150 200 1000 ];%ms
% channel_level= [30 20 80]; % percent
channel_name = ["Violet", "Cyan", "Green"]; 
channel_exposure = [ 150 200 1000 ];%ms
channel_level= [5 20 40]; % percent
channel_num = length(channel_exposure);
for ch = 1:channel_num % set excitation light intensity for each channel
    intensity = channel_level(ch);
    mmc.setProperty('Lumencor', strcat(channel_name(ch), "_Level"), intensity);
end
mmc.setProperty('TIPFSStatus', 'State', 'Off');
% mmc.setPosition(all_pos(3, 1)); % only run at the first time to set zpos
tic;
%pos_list=[1 20 21 40 41 60 61 80];% 81 100 101 120 121 130 131 140 141 150];

dt=10;
t0=now;
t00=t0;
for i0=1:16
    if i0> 1
        t1=now;
        while (t1-t0)*1440 < dt
            pause(5);
             t1=now;
             display([ i0 (t1-t0)*1440]);
        end
        t0=t1;
    end
        
    channel_level= [5 20 40]; % percent
    for i =1:pos_num
        count_per_pos=0;
        tt=toc;
        disp([i tt]); 
        % Set new position and set PFS
        mmc.setXYPosition(all_pos(1, i), all_pos(2, i ));
        mmc.waitForDevice('TIXYDrive');
        fname = sprintf('%s/loop%03d-xy%03d.tiff', data_dir, i0,i);        
        if sum(well_ps==i-1) == 1 %sleep at the begining of each well
            mmc.sleep(4000); %shifting between wells
%             well = well +1;
            mmc.setPosition(all_pos(3, i)); % only run at the first position of every well
        else
            mmc.sleep(1000); %wait within wells % 300ms
        end
        if i==1
            mmc.sleep(6000); %wait within wells % 300ms
        end
        mmc.waitForDevice('TIXYDrive');
        % Use PFS for focus
        mmc.setProperty('TIPFSOffset', 'Position', PFS/40);
        mmc.setProperty('TIPFSStatus', 'State', 'On');
        mmc.sleep(2000); %ms? %How to determine the waiting time for PFS
        mmc.waitForSystem();
        mmc.setProperty('TIPFSStatus', 'State', 'Off');
        z_map(i) = mmc.getPosition(); % save z postion
        mmc.setExposure(EXPOSURE);
        mmc.clearCircularBuffer(); % clear camera buffer

        % Capture image time by time
        for channel = 1:channel_num
            % Update light source
            EXPOSURE = channel_exposure( channel );
            name = channel_name(channel);
            if channel == 3 % Only use for RFP: to turn on YG filter
                mmc.setProperty('Lumencor', 'YG_Filter', 1);
            end 
            % Turn on light source
            mmc.setProperty('Lumencor', strcat(name, "_Enable"), 1);
            mmc.setExposure( EXPOSURE );
            time_map(i) = now;
            if channel == 1
                for j = 1:20 % 20 frames x 150ms ~ 20seconds
                    mmc.snapImage();
                    mmc.sleep(EXPOSURE + 10); % wait for exposure
                    img = uint16( reshape(mmc.getImage(), W, H) );
                    if j == 1 % Overwrite tiff at the first image
                        options.overwrite = true;
                        options.append = false;
                        options.message = false;
                    end
                    count_per_pos=count_per_pos+1;
                    if  count_per_pos == 1 % Overwrite tiff at the first image
                        options.overwrite = true;
                        options.append = false;
                        options.message = false;
                    else % Append remaing image to previous tiff
                        options.overwrite = false;
                        options.append = true;
                        options.message = false;
                    end
                    saveastiff(img, fname, options);
                end
            else
                 mmc.snapImage();
                 mmc.sleep(EXPOSURE + 10); % wait for exposure
                 img = uint16( reshape(mmc.getImage(), W, H) );
                 count_per_pos=count_per_pos+1;
                if  count_per_pos == 1 % Overwrite tiff at the first image
                            options.overwrite = true;
                            options.append = false;
                            options.message = false;
                else % Append remaing image to previous tiff
                            options.overwrite = false;
                            options.append = true;
                            options.message = false;
                end
                saveastiff(img, fname, options);
            end
            mmc.setProperty('Lumencor', strcat(name, "_Enable"),  0);
            % Move emission filter to next channel
            if channel == 2 % When previous channel is GFP, move to red emssion filter
                mmc.setProperty('LudlWheel', 'State', '3'); 
            elseif channel == 3 % When previous channel is RFP, turn off Lumencor's YG filter
                mmc.setProperty('Lumencor', 'YG_Filter', 0);
                mmc.setProperty('LudlWheel', 'State', '2');  %change to GFP and  Calibrtyte 500
            end
            mmc.sleep(200); % wait for 200ms
        end
    end
    channel_level= [0 0 0]; % percent
    mmc.setProperty('Lumencor', strcat(name, "_Enable"),  0);
end
save([data_dir 'all_info.mat'], 'time_map', 'z_map');
