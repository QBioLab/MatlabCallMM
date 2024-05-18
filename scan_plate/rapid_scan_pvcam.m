function [output_metainfo]=rapid_scan_pvcam(mmc, trigger, input_metainfo)
%% Rapid scan all given positions using photometrics smart streaming
% | Version | Commit
% | 20240318| integrate mm gui @HF
% | 20240416| renew metadata framework@HF

p = gcp;
if ~p.Connected
    parpool(3);
end

tiff_options.overwrite = true;
tiff_options.message = false;
tiff_options.compress  = 'no';
output_metainfo = input_metainfo;
% load input metainfo to necessary parameters
position_list = input_metainfo.position_list;
pos_num = length(position_list);
roi_x0 = input_metainfo.roi(1);
roi_y0 = input_metainfo.roi(2);
roi_w = input_metainfo.roi(3);
roi_h = input_metainfo.roi(4);
exposure_seq = input_metainfo.exposure_sequence;
channel_seq = input_metainfo.channel_sequence;
channel_num = int32(length(channel_seq));
data_dir = input_metainfo.data_dir;

% prelocate log information
output_metainfo.log.time_list=zeros(pos_num, 1);
output_metainfo.log.z_list=zeros(pos_num, 1);
output_metainfo.log.pfs = mmc.getPosition('PFSOffset');

%% Initliaze Microscope
% move to origin position     
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');
x_ori = position_list(1).x_um;
y_ori = position_list(1).y_um;
z_last_PFS = position_list(1).z_um;

mmc.setXYPosition(x_ori, y_ori);
mmc.setProperty('XYStage', 'Speed', '51.00mm/sec');
mmc.setProperty('XYStage', 'Tolerance', '0.30um');
mmc.waitForSystem(); 
mmc.setProperty('PFS', 'FocusMaintenance', 'On');
mmc.setROI(roi_x0, roi_y0, roi_w, roi_h);
W=mmc.getImageWidth();
H=mmc.getImageHeight();

SMARTStreamingValues_ms = "";
led_seq_string = "&SQ";
for ch_idx=1:channel_num % generate SMARTStreamingValues string and trigger string
    exposure=exposure_seq(ch_idx);
    SMARTStreamingValues_ms = SMARTStreamingValues_ms + sprintf("%0.3f;",exposure);
    led_port=channel_seq(ch_idx);
    led_seq_string = led_seq_string + sprintf("%1d", led_port);
end
for ch_idx=channel_num+1:4 % append remained channel to 0
    led_seq_string = led_seq_string + sprintf("%1d", 0);
end
led_seq_string=led_seq_string + "#";

% Photometrics smartstreaming and multi-trigger 
mmc.setProperty('Camera-1', 'SMARTStreamingEnabled', 'Yes');
mmc.setProperty('Camera-1', 'SMARTStreamingValues[ms]', SMARTStreamingValues_ms);
mmc.setProperty('Camera-1', 'Port', 'Dynamic Range');
mmc.setProperty('Camera-1', 'Trigger-Expose Out-Mux', channel_num)
mmc.setProperty('Camera-1', 'TriggerMode', 'Edge Trigger');
mmc.setProperty('FilterTurret1', 'Label', '5-89000');
try
    fprintf(trigger, led_seq_string); % send led control sequence
catch
    fclose(trigger);
    fopen(trigger);
    fprintf(trigger, led_seq_string); % send led control sequence
    fscanf(trigger); %clear the contents of the serial port buffe
end

%% Continued acquisition
pos_idx = int32(1);
cur_frame = int32(1);
tags_list =[];
fname_list = [];
frame_num = channel_num * pos_num;

if mmc.isSequenceRunning()
    mmc.stopSequenceAcquisition();
end
mmc.startSequenceAcquisition(frame_num, 0, true);
mmc.sleep(1000);

% move and capture first frame
x_um=position_list(pos_idx).x_um;
y_um=position_list(pos_idx).y_um;
mmc.setXYPosition(x_um, y_um);
mmc.waitForSystem();
tic;
trigger_camera(trigger);
while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning())
    if mmc.getRemainingImageCount() > 0
        % obtain current frame from mm circliar buffer
        tagged = mmc.popNextTaggedImage();
        ch_idx = rem(cur_frame-1, channel_num)+1; % careful to change
        pos_idx = ceil(double(cur_frame)/double(channel_num));% apply double to avoid lose
        name = position_list(pos_idx).name;
        output_metainfo.log.z_list(pos_idx)=z_last_PFS;
        output_metainfo.log.time_list(pos_idx)=toc;
        fname=sprintf('ch%d/%s_c%d.tiff', ch_idx, name, ch_idx);
        
        disp(['Sample:' input_metainfo.sample_name ' pos:' name ...
            ' captured/total:' num2str(int32(pos_idx)) '/' num2str(pos_num)...
            ' z(um)' num2str(int16(z_last_PFS))  ...
              ' time(s):' num2str(int32(toc))]);
        
        if pos_idx < pos_num
            % when last channel was done, move stage to next xy position
            if ch_idx == channel_num
                next_pos_idx = pos_idx+1;
                x_um = position_list(next_pos_idx).x_um;
                y_um = position_list(next_pos_idx).y_um;
                mmc.setXYPosition(x_um, y_um);   
                mmc.waitForSystem();   
                z_last_PFS = mmc.getPosition('ZDrive');
            end
        end
        % trigger next exposure util the end
        if cur_frame < frame_num
            trigger_camera(trigger);
            cur_frame=cur_frame+1;
        end
        % save file during next exposure
        tag = jsondecode(tagged.tags.toString.toCharArray);
        tags_list = [tags_list tag];
        fname_list = [fname_list string(fname)]; 
        img_raw=typecast(tagged.pix, 'uint16');
        img=reshape(img_raw, W, H); % row-major from C++
        img=img'; % transpose to column-major for matlab
        %saveastiff(img, fname, tiff_options); %blocking write
        parfeval(@saveastiff, 0, img, [data_dir '/' fname], tiff_options);%non-blocking write
    else
        mmc.sleep(10)
    end
end

mmc.stopSequenceAcquisition();
disp(['Capture Finished: ' num2str(toc/3600) ' hr']);

% record all position and setting infomation
output_metainfo.camera_affine_matrix = string(mmc.getPixelSizeAffineAsString());
output_metainfo.log.tags_list=tags_list;
output_metainfo.log.fname_list=fname_list;

%% Home microscope setting
fprintf(trigger, "&SQ0000#"); % disable SMARTStreaming on trigger
fscanf(trigger); %clear the contents of the serial port buffe
mmc.setProperty('PFS', 'FocusMaintenance', 'Off');
mmc.setXYPosition(x_ori, y_ori);
mmc.setConfig("Kinetix-left", "multipass-89000");

end
