%% Capture mulitpositions
% | Version | Commit
% | 20240318| integrate mm gui @HF
% | 20240416| renew metadata framework@HF

addpath ../lib
clear metainfo_file metainfo_json metainfo

tic
%metainfo_file = 'C:/Users/qblab/Downloads/plate4_20240423_rapid_scan_plate_A384_10x.json';
%% Initlize microscope
if ~exist('mmc', 'var')
    % import micro-manage studio and mmcore here
    studio =org.micromanager.internal.MMStudio(true);
    mmc = studio.core();
    mmc.waitForSystem();
    warning("Micro-manager Opened")
    return;
else
    [file_name, file_dir]= uigetfile('.json');
    metainfo_file = [file_dir file_name];
    metainfo_file(strfind(metainfo_file,'\'))='/';% avoid json error
    metainfo = read_json(metainfo_file);
    metainfo.createdfrom = metainfo_file;
    sample_name=metainfo.sample_name;  
    data_dir = metainfo.data_dir;    
end

if ~exist('epi_led', 'var') % Connect to D-LED arduino trigger
    epi_led = serial('COM6', 'BaudRate', 115200);
    fopen(epi_led);
end
p = gcp;
if ~p.Connected
    parpool(3);
end

tiff_options.overwrite = true;
tiff_options.message = false;
tiff_options.compress  = 'no';

% move to origin position     
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');
x_um = metainfo.position_list(1).x_um;
y_um = metainfo.position_list(1).y_um;
z_last_PFS = metainfo.position_list(1).z_um;
roi_x0=metainfo.roi(1);
roi_y0=metainfo.roi(2);
roi_w=metainfo.roi(3);
roi_h=metainfo.roi(4);
mmc.setXYPosition(x_um, y_um);
mmc.setProperty('XYStage', 'Speed', '51.00mm/sec');
% 6.5um/10/2=0.3250um
mmc.setProperty('XYStage', 'Tolerance', '0.30um');
mmc.waitForSystem(); 
mmc.setProperty('PFS', 'FocusMaintenance', 'On');
mmc.setROI(roi_x0, roi_y0, roi_w, roi_h);
W=mmc.getImageWidth();
H=mmc.getImageHeight();

pos_num = length(metainfo.position_list);
metainfo.log.time_list=zeros(pos_num, 1);
metainfo.log.z_list=zeros(pos_num, 1);
metainfo.log.pfs = mmc.getPosition('PFSOffset');

chsetup = metainfo.chsetup;
exposure_seq = metainfo.exposure_sequence;
channel_seq = metainfo.channel_sequence;
channel_num = int32(length(channel_seq));
exposure_seq_string = "";
led_seq_string = "&SQ";
for ch_idx=1:channel_num
    exposure=exposure_seq(ch_idx);
    exposure_seq_string = exposure_seq_string + ...
        sprintf("%0.3f;",exposure);
    led_port=channel_seq(ch_idx);
    led_seq_string = led_seq_string + sprintf("%1d", led_port);
end
for ch_idx=channel_num+1:4
    led_seq_string = led_seq_string + sprintf("%1d", 0);
end
led_seq_string=led_seq_string + "#";

% Photometrics smartstreaming and multi-trigger 
mmc.setProperty('Camera-1', 'SMARTStreamingEnabled', 'Yes');
mmc.setProperty('Camera-1', 'SMARTStreamingValues[ms]', exposure_seq_string);
mmc.setProperty('Camera-1', 'Port', 'Dynamic Range');
mmc.setProperty('Camera-1', 'Trigger-Expose Out-Mux', channel_num)
mmc.setProperty('Camera-1', 'TriggerMode', 'Edge Trigger');
mmc.setProperty('FilterTurret1', 'Label', '5-89000');
try
    fprintf(epi_led, led_seq_string); % send led control sequence
catch
    fclose(epi_led);
    fopen(epi_led);
    fprintf(epi_led, led_seq_string); % send led control sequence
end

%% continued acquisition
tic;
pos_idx = int32(1);
cur_frame = int32(1);
tags_list =[];
fname_list = [];
frame_num = channel_num * pos_num;
pos_uid = metainfo.position_list(pos_idx).id;

if mmc.isSequenceRunning()
    mmc.stopSequenceAcquisition();
end
mmc.startSequenceAcquisition(frame_num, 0, true);
mmc.sleep(1000);

x_um=metainfo.position_list(pos_idx).x_um;
y_um=metainfo.position_list(pos_idx).y_um;
mmc.setXYPosition(x_um, y_um);
mmc.waitForSystem();
trigger_camera(epi_led);
while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning())
    if mmc.getRemainingImageCount() > 0
        % obtain current from mm circliar buffer
        tagged= mmc.popNextTaggedImage();
        ch_idx=rem(cur_frame-1, channel_num)+1;
        pos_idx=ceil(double(cur_frame)/double(channel_num));% change double 
        name=metainfo.position_list(pos_idx).name;
        pos_uid = metainfo.position_list(pos_idx).id;
        metainfo.log.z_list(pos_idx)=z_last_PFS;
        metainfo.log.time_list(pos_idx)=toc;
        tag=jsondecode(tagged.tags.toString.toCharArray);
        tags_list=[tags_list tag];
        fname=sprintf('ch%d/%s_c%d.tiff', ...
                    ch_idx, name, ch_idx);
        fname_list = [fname_list string(fname)]; 
        
        disp(['Sample:' sample_name ' pos:' name ...
            ' captured/total:' num2str(int32(pos_idx)) '/' num2str(pos_num)...
            ' z(um)' num2str(int16(z_last_PFS))  ...
              ' time(s):' num2str(int32(toc))]);
        
        if pos_idx < pos_num
            % when last channel was done, move stage to next xy position
            if ch_idx==channel_num
                next_pos_idx = pos_idx+1;
                x_um=metainfo.position_list(next_pos_idx).x_um;
                y_um=metainfo.position_list(next_pos_idx).y_um;
                mmc.setXYPosition(x_um, y_um);   
                mmc.waitForSystem();   
                z_last_PFS = mmc.getPosition('ZDrive');
            end
        end
        % trigger next exposure util the end
        if cur_frame < frame_num
            trigger_camera(epi_led);
            cur_frame=cur_frame+1;
        end
        % save file during next exposure
        img_raw=typecast(tagged.pix, 'uint16');
        img=uint16(reshape(img_raw, W, H));
        %saveastiff(img, fname, tiff_options); %blocking write
        parfeval(@saveastiff, 0, img, [data_dir '/' fname], tiff_options);%non-blocking write
    else
        mmc.sleep(10)
    end
end

mmc.stopSequenceAcquisition();
disp(['Capture Finished: ' num2str(toc/3600) ' hr']);

% record all position and setting infomation
metainfo.log.tags_list=tags_list;
metainfo.log.fname_list=fname_list;
output_fname=sprintf("%s/%s.json", data_dir, sample_name);
save_json(output_fname, metainfo);

%% Home microscope setting
fprintf(epi_led, "&SQ0000#");
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');
x_ori = metainfo.position_list(1).x_um;
y_ori = metainfo.position_list(1).y_um;
mmc.setXYPosition(x_ori, y_ori);
mmc.setConfig("Kinetix-left", "multipass-89000");
