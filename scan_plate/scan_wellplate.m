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
% | 20240318| integrate mm studio gui @HF

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 0-5:
tic

sample_name='STO-GFP-or-mCherry-sorted-sc-A384-20240316-daily';

temp=datevec(date);
date_folder=[num2str(temp(1)) num2str(temp(2)) num2str(temp(3))]
data_dir = ['E:\XJF\' sample_name '\' date_folder];

disp('continuing')


if exist('studio', 'var')
    warning('Dont initialize MMCore again!');
else
    % import micro-manage studio and mmcore here
    studio = com.micromanager.internal.MMStudio();
    %import mmcorej.*
    %mmc= CMMCore;
    mmc = studio.core();
    config = 'C:\users\qblab\Documents\MMConfig_Ti2_Kinetix.cfg';
    W1=2720; H1=2720; Woffset=0.5*(W-W1)+1;Hoffset=0.5*(H-H1)+1;
    mmc.loadSystemConfiguration(config);
    mmc.waitForSystem();
end
if exist('epi_led', 'var')
    warning('Epi LED is already initalized')
else
    % Connect to D-LED arduino trigger
    epi_led = serial('COM3', 'BaudRate', 115200);
    fopen(epi_led);
end

% HARDWARE SETUP

%mmc.setProperty('Nosepiece', 'Label', '1-Plan Apo LmbdS4.00DIC 10x'); % objective
mmc.setProperty('FilterTurret1', 'Label', '5-89000'); %filter cube
mmc.setProperty('Camera-1', 'Port', 'Dynamic Range');

EXPOSURE = 10; %10ms
mmc.setExposure(EXPOSURE);

% EXPERIMENT PARAMETERS

%reset the order of the wells at t47;

data_info=importdata('D:\multiwell_plate_calibration\A384well\A384-select-well-PFS-20240317-10XAPO_w_head.csv'); 
%% corrected the order of the wells at t41;

% position and time-lapse setting
    n_well =data_info(1,1); 
    pos_per_well =data_info(1,2); 
    NT =data_info(1,3); 
    dT =data_info(1,4); %second
% channel setting
    % TRG1->385nm, TRG2->475nm, TRG3->550nm, TRG4->621nm, TRG0->ALL
    chsetup(1).name='BF'; chsetup(2).name='1'; chsetup(3).name='2';
    chsetup(4).name='3'; chsetup(5).name='4'; 
    % em: '1-Empty', '2-DAPI', '3-FITC', '4-Texas Red','5-89000','6-Empty';
    chsetup(1).em='1-Empty'; chsetup(2).em='2-DAPI'; chsetup(3).em='3-FITC';
    chsetup(4).em='4-Texas Red'; chsetup(5).em='5-89000';chsetup(6).em='6-Empty';
    % chsetting(1).name='2';      chsetting(1).exposure=200;   
    % chsetting(1).level= 25;  chsetting(1).em='5-89000';

    channel_num=data_info(2,1);
    channel_info=data_info(1+(1:channel_num),:);
    % channel_number name exposure em
    clear chsetting
    for ch_i=1:channel_num
        chsetting(ch_i).name=chsetup(channel_info(ch_i,2)).name;
        chsetting(ch_i).exposure=channel_info(ch_i,3);% ms
        chsetting(ch_i).level=25;% cannot be setuped at this moments 2023.9.23
        chsetting(ch_i).em=chsetup(channel_info(ch_i,4)).em;
    end
    % position info
    all_pos=data_info(1+channel_num+1:end,:);
        %order for scanning;
            iw=[1:24];
            for i1=2:16
                if mod(i1,2)==1
                    iw=[iw (i1-1)*24+(1:24)];
                else
                    iw=[iw (i1-1)*24+(24:-1:1)];
                end
            end
        %%%%%
        well_map=iw(1:n_well);
        pos_num = n_well*pos_per_well;
        well_index=reshape(repmat(well_map,pos_per_well,1),pos_num,1);
    %%%%%%%%%%%%%%%%%%%
    
    PFS =all_pos(1,4);  % valids for each setup

% move to origin position     
mmc.setXYPosition(all_pos(1,1), all_pos(1,2));
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');
% Prelocate meomery
%img = zeros(W1, H1, pos_num/1 , channel_num, 'uint16');
channel_rolling = [2:channel_num 1]; % don't change it

log_file=[data_dir 'all_info.mat']; % recoded the z points of each position of each time cycle
timestamp_file=[data_dir 'all_time_stamp.mat'];  % recoded the time stamp of the starting point of every cycle
fileinfo=dir(log_file);
if length(fileinfo)==0
    tic;
    time_map = zeros(pos_num, NT);
    time_cycle_stamp(1)=datenum(datetime);
    z_map = zeros(pos_num, 1);
    z_last_PFS= all_pos(1,3); % initialized last z with PFS
    time_start=1;
else  % restart loading from log_file
    load(log_file,'time_map', 'z_map');
    load(timestamp_file,'time_cycle_stamp');
    time_start=length(z_map(1,:))+1;
      z_last_PFS= all_pos(1,3); % initialized last z with PFS
    tic
  %  time_cycle_stamp(time_start)=datenum(datetime);
end

%mmc.setProperty('DiaLamp', 'State', 0);
mmc.setPosition('ZDrive', z_last_PFS);
mmc.waitForSystem(); 
z_PFS0=z_last_PFS;
%time_start = 1;
for time_step=time_start:NT
    %%%%% timing for each cycle
    if time_step>2
        time_current=datenum(datetime);
        display('waiting');
        count_wait=0;
        % calculated the total recorded duration (from time 1) in seconds
        total_recorded_duration=86400*(time_current-time_cycle_stamp(1));
        while total_recorded_duration<(time_step-2)*dT  
            pause(1);
            count_wait=count_wait+1;
            time_current=datenum(datetime);
            total_recorded_duration=86400*(time_current-time_cycle_stamp(1));
            if mod(count_wait,600)==1
                display(['time_cycle ' num2str(time_step) ' total time(1000s)=' num2str(total_recorded_duration/1000)]);
            end
        end
        display(['time_cycle ' num2str(time_step) ' total time(1000s)=' num2str(total_recorded_duration/1000)]);
    end
    time_cycle_stamp(time_step)=datenum(datetime);
    %%%%% timing for each cycle above
    for pos_i =1: pos_num 
        % Set new position and set PFS
       if mod(pos_i, pos_per_well) == 1
            mmc.setXYPosition(all_pos(pos_i,1), all_pos(pos_i, 2));
            mmc.waitForSystem();
       end
       if all_pos(pos_i,4) > 0
           if pos_i==1
               mmc.setPosition('ZDrive', all_pos(pos_i,3));
               pfs_on =  mmc.isContinuousFocusEnabled();
               if ~pfs_on
                    mmc.setProperty('PFS', 'FocusMaintenance', 'On');
               end
                  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %send PFS On comand and check PFS status util it Locked in focus
                pfs_on = false; lock = false; timeout = 3;
                while ~(pfs_on && lock) && timeout
                    %while ~pfs_on && ~lock && timeout
                    if ~pfs_on
                        try
                            mmc.setProperty('PFS', 'FocusMaintenance', 'On');
                            mmc.waitForSystem();
                        end
                    end
                    try
                        pfs_on =  mmc.isContinuousFocusEnabled();
                    end
                    try
                        lock = mmc.isContinuousFocusLocked();
                    end            
                    mmc.waitForSystem();
                    timeout = timeout-1;
                end
                mmc.waitForSystem();
                z_last_PFS = mmc.getPosition('ZDrive');%; % save z postion
                % waiting for PFS to be settled
                    PSF_cycle=0;
                    while  abs(z_last_PFS-z_PFS0)<1 && PSF_cycle <40
                        PSF_cycle=PSF_cycle+1;
                        z_last_PFS = mmc.getPosition('ZDrive');%; % save z postion
                        mmc.sleep(50);
                    end
                mmc.sleep(1000);
                z_last_PFS = mmc.getPosition('ZDrive');%; % save z postion
                if abs(z_last_PFS-all_pos(pos_i,3))>500 % PFS escaped 
                    if pos_i==1
                        z_last_PFS=all_pos(1,3);
                    else
                        z_last_PFS=z_map(pos_i-1,time_step);
                    end
                end          
           end
        end
        % Move xyz stage
        mmc.setXYPosition(all_pos(pos_i, 1), all_pos(pos_i, 2 ));   
        mmc.waitForSystem();   
        %%%%% wait for addition 500ms for continue PFS to stablize
            if mod(pos_i, pos_per_well)==1
                mmc.sleep(1500);
            end
        %%%%%%
        z_last_PFS = mmc.getPosition('ZDrive');
        z_map(pos_i,time_step) = z_last_PFS; %mmc.getPosition('ZDrive'); % save z postion
        
        % Capture image time by time
        time_current=datenum(datetime);
            total_recorded_duration=86400*(time_current-time_cycle_stamp(1));
            pos_i_pass=pos_i-49; 
            if pos_i_pass<1 
                pos_i_pass=1;
            end
        if NT ==1
            z_dev=std(z_map(pos_i_pass:pos_i));
          disp(['Sample:' sample_name  ' well_no:' num2str(ceil(pos_i/pos_per_well)) '  well_pos:' num2str(well_index(pos_i)) ...
            ' pos:' num2str(int32(pos_i)) ' z(um):' num2str(int16(z_last_PFS)) ' dz(um): ' num2str(z_dev) ...
              ' time(s):' num2str(int32(toc))]);
        else
            z_dev=std(z_map(pos_i_pass:pos_i));
          disp(['Sample:' sample_name ' cycle:' num2str(time_step) ' well_no:' num2str(ceil(pos_i/pos_per_well)) '  well_pos:' num2str(well_index(pos_i)) ...
            ' pos:' num2str(int32(pos_i)) ' z(um):' num2str(int16(z_last_PFS)) ' dz(um): ' num2str(z_dev)...
              ' time(1000s):' num2str((total_recorded_duration/1000))]);
        end
        for ch = 1:channel_num
            % Update light source
            EXPOSURE = chsetting(ch).exposure;
            name = chsetting(ch).name;
            mmc.setProperty('FilterTurret1', 'Label', chsetting(ch).em); %filter cube
            %mmc.sleep(100); %wait for filter wheel settle down
            if chsetting(ch).name(1) == 'B' % 'BF'
                % Turn on transimitted led
                %mmc.setProperty('DiaLamp', 'State', 1);
            else % Trigger on epi-fluoscence led
                epi_led_cmd = sprintf('&TRG%s_%d#', name, 1);
                fprintf(epi_led, epi_led_cmd);
            end

            % Update exposure for difference light source
            mmc.setExposure(chsetting(ch).exposure);
            time_map(pos_i) = now;
            mmc.waitForSystem();
            mmc.sleep(20);
            mmc.snapImage();

            img_raw = typecast(mmc.getImage(), 'uint16');
            % rotate image to match orientation in NIS
            temp=uint16(reshape(img_raw, W, H)); temp=temp'; temp=temp(:,end:-1:1);
            %img(:, :, pos_i, ch) = 
            img_save = temp(Woffset+(1:W1),Hoffset+(1:H1));
            
            if channel_num>1 || mod(pos_i, pos_per_well) == 0
                if chsetting(ch).name(1) == 'B' % turn off transimitted led
                   % mmc.setProperty('DiaLamp', 'State', 0);
                else
                    % turn off epi-fluorescence led
                    epi_led_cmd = sprintf('&TRG%s_%d#', name, 0);
                    fprintf(epi_led, epi_led_cmd);
                end
            end
            options.overwrite = true;
            options.message = false;
            options.compress  = 'no';
            if NT == 1
                fname = sprintf('%s/ch%d/well%dxy%dc%d.tiff', data_dir, ch,  well_index(pos_i), pos_i, ch);
            else
                fname = sprintf('%s/ch%d/t%d/well%dxy%dc%d.tiff', data_dir,ch, time_step,  well_index(pos_i), pos_i, ch);
            end
            saveastiff(img_save, fname, options);
        end
        % turn off PFS at the last postion of the well
        if mod(pos_i, pos_per_well) == 0
           % mmc.setProperty('PFS', 'FocusMaintenance', 'Off');all
            if chsetting(ch).name(1) == 'B' % turn off transimitted led
               % mmc.setProperty('DiaLamp', 'State', 0);
            else
                % turn off epi-fluorescence led
                epi_led_cmd = sprintf('&TRG%s_%d#', name, 0);
                fprintf(epi_led, epi_led_cmd);
            end
        end
    end
    n_well =data_info(1,1); 
    pos_per_well =data_info(1,2); 
    NT =data_info(1,3); 
    dT =data_info(1,4); %second
    
    % record all position and setting infomation
    save(log_file, 'time_map', 'z_map', 'chsetting', 'all_pos', 'n_well','pos_per_well','NT','dT');
    % save the time stamp infomation
    save(timestamp_file, 'time_cycle_stamp');
end
      
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');

disp(['Capture Finished: ' num2str(toc/3600) ' hr']);
% move stage to A1 well
mmc.setXYPosition(all_pos(1,1), all_pos(1,2));
mmc.setPosition('ZDrive', all_pos(1,3));

disp(['Writing Finished: ' num2str(toc/3600) ' hr']);
