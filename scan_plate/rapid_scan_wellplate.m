% Capture mulitpositions
% | Version | Commit
% | 20240318| integrate mm gui @HF
% | 20240416| renew metadata framework@HF

tic
addpath 'C:/Users/qblab/Desktop/MMConfigure'
metainfo_json = fileread('\\data.qblab.science/datahub/hardware/MMConfigure/plate_calibration/A384well/rapid_scan_plate_A384_10x.json');
metainfo = jsondecode(metainfo_json);

sample_name=metainfo.sample_name;
data_dir = metainfo.data_dir;

if ~exist('mmc', 'var')
    % import micro-manage studio and mmcore here
    studio =org.micromanager.internal.MMStudio(false);
    mmc = studio.core();
    mmc.waitForSystem();
    warning("Micro-manager Opened")
    return;
end

if ~exist('epi_led', 'var')
    % Connect to D-LED arduino trigger
    epi_led = serial('COM6', 'BaudRate', 115200);
    fopen(epi_led);
end

% EXPERIMENT PARAMETERS
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
mmc.setProperty('XYStage', 'Tolerance', '0.20um');
mmc.waitForSystem(); 
mmc.setProperty('PFS', 'FocusMaintenance', 'On');
mmc.setROI(roi_x0, roi_y0, roi_w, roi_h);
W=mmc.getImageWidth();
H=mmc.getImageHeight();

pos_num = length(metainfo.position_list);
metainfo.log.time_list=zeros(pos_num, 1);
metainfo.log.z_list=zeros(pos_num, 1);

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

tic;
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
% continued acquisition
while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning())
    if cur_frame == 1
        x_um=metainfo.position_list(pos_idx).x_um;
        y_um=metainfo.position_list(pos_idx).y_um;
        mmc.setXYPosition(x_um, y_um);   
        mmc.waitForSystem();   
        try
            fprintf(epi_led, '&CAMEXP#');
        catch
            fclose(epi_led);
            fopen(epi_led);
            fprintf(epi_led, '&CAMEXP#');
        end
    end
    if mmc.getRemainingImageCount() > 0
        % obtain current from mm circliar buffer
        tagged= mmc.popNextTaggedImage();
        ch_idx=mod(cur_frame, channel_num)+1;
        pos_idx=ceil(cur_frame/channel_num);
        name=metainfo.position_list(pos_idx).name;
       
        % when last channel was done, move stage to next xy position
        if ch_idx==channel_num              
            x_um=metainfo.position_list(pos_idx).x_um;
            y_um=metainfo.position_list(pos_idx).y_um;
            mmc.setXYPosition(x_um, y_um);   
            mmc.waitForSystem();   
        end
        z_last_PFS = mmc.getPosition('ZDrive');
        metainfo.log.z_list(pos_idx)=z_last_PFS;
        metainfo.log.time_list(pos_idx)=toc;
        tag=jsondecode(tagged.tags.toString.toCharArray);
        tags_list=[tags_list tag];
        
        % trigger next exposure
        try
            fprintf(epi_led, '&CAMEXP#');
        catch
            fclose(epi_led);
            fopen(epi_led);
            fprintf(epi_led, '&CAMEXP#');
        end
        
        % save to file during next exposure
        img_raw=typecast(tagged.pix, 'uint16');
        % rotate image to match orientation in NIS
        temp=uint16(reshape(img_raw, W, H)); 
        temp=temp'; 
        img_save=temp(:,end:-1:1);
        fname=sprintf('%s/ch%d/%s_pos%dc%d.tiff', ...
            data_dir, ch_idx, name, pos_idx, ch_idx);
        fname_list = [fname_list fname];
        
        saveastiff(img_save, fname, tiff_options);

        disp(['Sample:' sample_name ' pos:' name ...
            ' captured/total:' num2str(int32(pos_idx)) '/' num2str(pos_num)...
            ' z(um)' num2str(int16(z_last_PFS))  ...
              ' time(s):' num2str(int32(toc))]);
        cur_frame=cur_frame+1;
    else
        mmc.sleep(100)
    end
end
mmc.stopSequenceAcquisition();
disp(['Capture Finished: ' num2str(toc/3600) ' hr']);

% record all position and setting infomation
metainfo.log.tags_list=tags_list;
metainfo.log.fname_list=fname_list;
output_json_file = fopen("rapid_scan_plate_A384_10x.json", 'w');
output_json = jsonencode(metainfo);
fprintf(output_json_file, output_json);
fclose(output_json_file);

mmc.setProperty('PFS', 'FocusMaintenance', 'Off');
% move stage to origin position
x_ori = metainfo.position_list(1).x_um;
y_ori = metainfo.position_list(1).y_um;
mmc.setXYPosition(x_ori, y_ori);