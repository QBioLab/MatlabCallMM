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
% | 20230210| Support Nikon Ti2
% | 20240318| integrate mm gui @HF
% | 20240413| new data input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 0-5:
tic
addpath C:/Users/qblab/Desktop/MMConfigure

sample_name='test';

temp=datevec(date);
date_folder=[num2str(temp(1)) num2str(temp(2)) num2str(temp(3))]
data_dir = ['E:\XJF\' sample_name '\' date_folder];

if ~exist('mmc', 'var')
    % import micro-manage studio and mmcore here
    studio =org.micromanager.internal.MMStudio(false);
    %import mmcorej.*
    %mmc= CMMCore;
    mmc = studio.core();
    config = 'C:\users\qblab\Documents\MMConfig_Ti2_Kinetix.cfg';
    W = 3200; H = 3200;
    W1=2720; H1=2720; Woffset=0.5*(W-W1)+1;Hoffset=0.5*(H-H1)+1;
    %mmc.loadSystemConfiguration(config);
    mmc.waitForSystem();
end
if ~exist('epi_led', 'var')
    % Connect to D-LED arduino trigger
    epi_led = serial('COM3', 'BaudRate', 115200);
    fopen(epi_led);
end

% HARDWARE SETUP
mmc.setProperty('Camera-1', 'Port', 'Dynamic Range');

% EXPERIMENT PARAMETERS
data_info=importdata('D:multiwell_plate_calibration\A384well\A384-select-well-PFS-20240317-10XAPO_w_head_no-border.csv'); 

% position and time-lapse setting
n_well =data_info(1,1); 
pos_per_well =data_info(1,2); 
NT =data_info(1,3); 
dT =data_info(1,4); %second
% channel setting
% TRG1->385nm, TRG2->475nm, TRG3->550nm, TRG4->621nm, TRG0->ALL
chsetup(1).name='BF';
chsetup(2).name='1'; 
chsetup(3).name='2';
chsetup(4).name='3'; 
chsetup(5).name='4'; 
% em: '1-Empty', '2-DAPI', '3-FITC', '4-Texas Red','5-89000','6-Empty';
chsetup(1).em='1-Empty'; 
chsetup(2).em='2-DAPI'; 
chsetup(3).em='3-FITC';
chsetup(4).em='4-Texas Red'; 
chsetup(5).em='5-89000';
chsetup(6).em='6-Empty';

channel_num = 1;
channel_id = 3; % 3 is for GFP, 4 is for RFP
%channel_id = 4; % mcherry
% channel_number name exposure em
clear chsetting
chsetting(1).name=chsetup(channel_id).name;
chsetting(1).exposure=200;% ms
chsetting(1).level=25;% cannot be setuped at this moments 2023.9.23
chsetting(1).em=chsetup(channel_id).em;

% position info
all_pos=data_info(1+channel_num+1:end,:);

%order for scanning;
iw=1:24;
for i1=2:16
	if mod(i1,2)==1
        iw=[iw (i1-1)*24+(1:24)];
    else
        iw=[iw (i1-1)*24+(24:-1:1)];
    end
end
exclude = [1:24 25:24:384 48:24:384 362:383] ;
filtered_well = [];
for i=iw
    flag = 0;
    for j=exclude
        if i==j
            flag = 1;
            break;
        end
    end
    if flag==0
        filtered_well = [filtered_well i];
    end
end
iw = filtered_well;

well_map=iw(1:n_well);
pos_num = n_well*pos_per_well;
well_index=reshape(repmat(well_map,pos_per_well,1),pos_num,1);
    
% move to origin position     
mmc.setXYPosition(all_pos(1,1), all_pos(1,2));
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');

log_file=[data_dir 'all_info.mat']; % recoded the z points of each position of each time cycle
timestamp_file=[data_dir 'all_time_stamp.mat'];  % recoded the time stamp of the starting point of every cycle
fileinfo=dir(log_file);

tic;
time_map = zeros(pos_num);
z_map=zeros(pos_num, 1);
z_last_PFS= all_pos(1,3); % initialized last z with PFS

mmc.setPosition('ZDrive', z_last_PFS);
mmc.waitForSystem(); 

mmc.setProperty('PFS', 'FocusMaintenance', 'On');
for pos_i =1: pos_num  
    % Move xy stage
    mmc.setXYPosition(all_pos(pos_i, 1), all_pos(pos_i, 2 ));   
    mmc.waitForSystem();   
    % wait for addition 500ms for continue PFS to stablize
    if mod(pos_i, pos_per_well)==1
        mmc.sleep(1500);
    end
    
    z_last_PFS = mmc.getPosition('ZDrive');
    z_map(pos_i) = z_last_PFS; 
        
    disp(['Sample:' sample_name  ' well_no:' num2str(ceil(pos_i/pos_per_well)) '  well_pos:' num2str(well_index(pos_i)) ...
            ' pos:' num2str(int32(pos_i)) ' z(um):' num2str(int16(z_last_PFS))  ...
              ' time(s):' num2str(int32(toc))]);
    %% snap channel by channel
    for ch = 1:channel_num
        EXPOSURE = chsetting(ch).exposure;
        name = chsetting(ch).name;
        mmc.setProperty('FilterTurret1', 'Label', chsetting(ch).em); %filter cube
        %mmc.sleep(100); %wait for filter wheel settle down

        %Trigger on epi-fluoscence led
        epi_led_cmd = sprintf('&TRG%s_%d#', name, 1);
        fprintf(epi_led, epi_led_cmd);
        
        % Update exposure for difference light source
        mmc.setExposure(chsetting(ch).exposure);
        time_map(pos_i) = now;
        mmc.waitForSystem();
        mmc.sleep(20);
        mmc.snapImage();

        img_raw = typecast(mmc.getImage(), 'uint16');
        % rotate image to match orientation in NIS
        temp=uint16(reshape(img_raw, W, H)); 
        temp=temp'; 
        temp=temp(:,end:-1:1);
        img_save = temp(Woffset+(1:W1),Hoffset+(1:H1));

        % turn off epi-fluorescence led
        epi_led_cmd = sprintf('&TRG%s_%d#', name, 0);
        fprintf(epi_led, epi_led_cmd);
        
        options.overwrite = true;
        options.message = false;
        options.compress  = 'no';
        fname = sprintf('%s/ch%d/well%dxy%dc%d.tiff', data_dir, ch,  well_index(pos_i), pos_i, ch);
        saveastiff(img_save, fname, options);
    end
end
   
% record all position and setting infomation
save(log_file, 'time_map', 'z_map', 'chsetting', 'all_pos', 'n_well','pos_per_well','NT','dT');
      
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');

disp(['Capture Finished: ' num2str(toc/3600) ' hr']);
% low objective
mmc.setPosition('ZDrive', 100);
% move stage to A1 well
mmc.setXYPosition(all_pos(1,1), all_pos(1,2));

disp(['Writing Finished: ' num2str(toc/3600) ' hr']);
