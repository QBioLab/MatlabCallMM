%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% HF 20200601 low exposure change, add counte to break dead loop
% 20200615 skip well center point
% 20200805 WaitForSystem Work! @HF
% 20200818 accelerate speed @HF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
data_dir = 'D:\cby\exp1016-1';
EXPOSURE = 15; %15ms
PFS = 100.32*40;
all_pos = importdata("U24-Zyla55_4XAPO-EB-control-24wells-14perwell_1015.csv");

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti_Andor_NoCooling.cfg');
end
%mmc.setProperty('HamamatsuHam_DCAM', 'ScanMode', 2);
mmc.setProperty('TIXYDrive', 'SpeedX', 2);
mmc.setProperty('TIXYDrive', 'SpeedY', 2);
%mmc.setProperry('TILightPath', 'Label', '2-Lef100')
mmc.setProperty('TILightPath', 'State', '1'); % Use left camera
mmc.setProperty('TINosePiece', 'Label', '1-Plan Apo 4x NA 0.20 Dry');
%mmc.setProperty('TINosePiece', 'State', '0');% Choose 4X objective
mmc.setProperty('TIFilterBlock1', 'Label', '2-DIA'); % use DIA filter block
%mmc.setPrpperty('TIFilterBlock1', 'State', '2');
mmc.setProperty('LudlWheel', 'State', '3'); % Ludl filter: use green emission filter
% TODO: update emssion filter
%mmc.setROI(128, 128, 2048, 2048) % set hamamatsu camera to ROI
mmc.setCircularBufferMemoryFootprint(2048); % Buffer for image
mmc.initializeCircularBuffer;

%all_pos = [1 2 3400 95; 10 20 3500 95];  % [x y z pfs_offset]
pos_num = length(all_pos(1, :));
pos_per_well = 14;
t_len = 150; % 150 frame
t_gap = 200; %200ms
w = 2560; h = 2160;
%w = 2048; h = 2048;

time_map = zeros(pos_num, 1);
z_map = zeros(pos_num, 1);
well = 0;
well_map =  [1:6 12:-1:7 13:18 24:-1:19];
%well_map =  [1:6 12:-1:7];

mmc.setProperty('TIPFSStatus', 'State', 'Off');
mmc.setPosition(all_pos(3, 1)); % only run at the first time
mmc.setProperty('TIPFSOffset', 'Position', PFS/40);
%mmc.sleep(1800000); % wait camera to remove frog

for i =  1:pos_num
    disp(i);
    mmc.setXYPosition(all_pos(1, i), all_pos(2, i ));    % Set new position
    mmc.waitForSystem; % wait stage move to new position
    mmc.sleep(700);
    if mod(i, pos_per_well) == 1
        %well = well +1;
        well = ceil(i/pos_per_well);
        % Use PFS for focus
        mmc.setProperty('TIPFSStatus', 'State', 'On');
        mmc.waitForSystem();
        mmc.sleep(4000);
        mmc.setProperty('TIPFSStatus', 'State', 'Off');
    end
    z_map(i) = mmc.getPosition(); % save z postion
    mmc.setExposure(EXPOSURE);
    fname = sprintf('%s/well%dxy%d.tiff', data_dir, well, i);

    % capture first image and find right exposure 
    t_last = clock;  % clock in second
	mmc.snapImage();
	img = uint16(reshape(mmc.getImage(), w, h));
	time_map(i) = now;
	EXPOSURE_TMP = EXPOSURE;
    try_num = 0;
    % Auto exposure to avoid over exposure
    while ( min(img(:)) ==0 && try_num <10)
        EXPOSURE_TMP = EXPOSURE_TMP*0.8;
		mmc.setExposure(EXPOSURE_TMP);
        mmc.snapImage();
        disp( mmc.getExposure())
        img = uint16(reshape(mmc.getImage(), w, h));
        t_last = clock;  % clock in second
        try_num = try_num +1;
    end
    % Write 1st page in tiff
    options.overwrite = true;
    options.append = false;
    options.message = false;
    saveastiff(img, fname, options);
     % update options to append image to tiff
    options.overwrite = false;
    options.append = true;
    options.message = false;
    
    while (clock - t_last < t_gap/1000)
        mmc.sleep(1); 
    end
    % continue acquire 
    mmc.startSequenceAcquisition( t_len-1, 0, true );
    while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice())) 
        t_last = clock;
        if mmc.getRemainingImageCount() > 0 
            img= uint16(reshape(mmc.popNextImage(), w, h));
            saveastiff(img, fname, options);
        else 
            mmc.sleep(min(.5 * EXPOSURE, 20)); 
        end
        while(clock - t_last < t_gap/1000)
            mmc.sleep(1);
         end
    end
    mmc.stopSequenceAcquisition();
end
save([data_dir '/all_info.mat'], 'time_map', 'z_map');
