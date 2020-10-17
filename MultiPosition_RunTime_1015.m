%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% HF 20200601 low exposure change, add counte to break dead loop
% 20200615 skip well center point
% 20200805 WaitForSystem Work! @HF
% 20200818 accelerate speed @HF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
data_dir = 'F:/CBY3/exp1015';
EXPOSURE = 15; %15ms
PFS = 3900;
%all_pos = importdata("U24-4XAPO-EB-control-24wells-16perwell_0819.csv");
all_pos = importdata("U24-DS-QI2_4XAPO-EB-control-24wells-14perwell_1015.csv");

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti_DS-Qi2.cfg');
end
%mmc.setProperty('HamamatsuHam_DCAM', 'ScanMode', 2);
cam_ser = serial('COM11', 'BaudRate',57600);
fopen(cam_ser);
mmc.setProperty('TIXYDrive', 'SpeedX', 2);
mmc.setProperty('TIXYDrive', 'SpeedY', 2);
%mmc.setProperry('TILightPath', 'Label', '3-Right100')
mmc.setProperty('TILightPath', 'State', '2'); % Use right camera
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
t_len = 150; % 150 frame
t_gap = 200; %200ms
%w = 2304; h = 2304;
w = 2048; h = 2048; % for DS-Qi2

time_map = zeros(pos_num, 1);
z_map = zeros(pos_num, 1);
well = 0;
well_map =  [1:6 12:-1:7 13:18 24:-1:19];
%well_map =  [1:6 12:-1:7];

mmc.setProperty('TIPFSStatus', 'State', 'Off');
mmc.setPosition(all_pos(3, 1)); % only run at the first time
mmc.setProperty('TIPFSOffset', 'Position', PFS/40);
for i = 1:pos_num
    disp(i);
    mmc.setXYPosition(all_pos(1, i), all_pos(2, i ));    % Set new position
    mmc.waitForSystem; % wait stage move to new position
    if mod(i, 16) == 1
        well = well +1;
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
    
    while (clock - t_last < t_gap/1000)
        mmc.sleep(1); 
    end
    % continue acquire 
   while( t<=t_len )
        t_last = clock;  % clock in second
		fprintf(cam_ser, '1');
        mmc.sleep(EXPOSURE_WAIT); % wait for exposure
        time_map(i, t) = now;
        t = t + 1; % Update timer
        % Wait for next cycle
        while (clock - t_last < t_gap/1000)
            mmc.sleep(1); 
        end
    end
end
save([data_dir '/all_info.mat'], 'time_map', 'z_map');
