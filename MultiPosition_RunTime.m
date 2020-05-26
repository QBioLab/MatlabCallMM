%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% HF 20200525
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti.cfg');
end

mmc.setProperty('TIXYDrive', 'SpeedX', 2);
mmc.setProperty('TIXYDrive', 'SpeedY', 2);
%mmc.setProperry('TILightPath', 'Label', '3-Right100')
mmc.setProperty('TILightPath', 'State', '2'); % Use right camera
mmc.setProperty('TINosePiece', 'Label', '1-Plan Apo 4x NA 0.20 Dry');
%mmc.setProperty('TINosePiece', 'State', '0');% Choose 4X objective
mmc.setProperty('LudlWheel', 'State', '0'); % Ludl filter

EXPOSURE = 15; %10ms
mmc.setExposure(EXPOSURE);

%all_pos = [1 2 3400 95; 10 20 3500 95];  % [x y z pfs_offset]
all_pos = importdata("U24-4XAPO-EB-control-12wells-0525.csv");

pos_num = length(all_pos(1, :));
t_len = 150; % 150 frame
t_gap = 200; %200ms
w = 2048; h = 2048;
EXPOSURE_WAIT = EXPOSURE + 10;

time_map = zeros(pos_num, t_len);
well = 1;
well_map =  [1:6 12:-1:7];

for i = 1:pos_num
    disp(i);
    % Set new position and set PFS
    mmc.setXYPosition(all_pos(1,i), all_pos(2,i ));
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
    mmc.setPosition(all_pos(3, i));
    mmc.setProperty('TIPFSOffset', 'Position', 4042/40);
    mmc.waitForDevice('TIZDrive');
    mmc.waitForDevice('TIXYDrive');
    if mod(i, 21) == 1
        mmc.sleep(3000);
        well = well +1;
    else
        mmc.sleep(300);
    end
    % Use PFS for focus
    mmc.setProperty('TIPFSStatus', 'State', 'On');
    mmc.sleep(200);
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
    mmc.setExposure(EXPOSURE);
    mmc.clearCircularBuffer(); % clear camera buffer
    
    fname = sprintf('D:/CBY/exp0526/well%dxy%d.tiff', well, i);
    % Capture image time by time
    t = 1;
    while( t<=t_len )
        t_last = clock;  % clock in second
        mmc.snapImage();
        mmc.sleep(EXPOSURE_WAIT); % wait for exposure
        img = uint16(reshape(mmc.getImage(), w, h));
        time_map(i, t) = now;
        if t ==1
            EXPOSURE_TMP = EXPOSURE;
            while( min(img(:)) ==0 )
                EXPOSURE_TMP = EXPOSURE_TMP*0.7;
                mmc.setExposure(EXPOSURE_TMP);
                mmc.snapImage();
                mmc.sleep(EXPOSURE_TMP + 10);
                tmp = mmc.getExposure();
                disp(tmp)
                img = uint16(reshape(mmc.getImage(), w, h));
                time_map(i, t) = now;
            end
            % Write 1 page tiff
            options.overwrite = true;
            options.append = false;
            options.message = false;
            saveastiff(img, fname, options);
        else
            % Append to tiff
            options.overwrite = false;
            options.append = true;
            options.message = false;
            saveastiff(img, fname, options);
        end
        t = t + 1; % Update timer
        % Wait for next cycle
        while (clock - t_last < t_gap/1000)
            mmc.sleep(1); 
        end
    end
end

save('D:/CBY/exp0526/time_info.mat', 'time_map');
