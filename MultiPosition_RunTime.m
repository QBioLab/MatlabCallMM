%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% HF 20200525
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti.cfg');
end

mmc.setProperty('TIXYDrive', 'SpeedX', 2)
mmc.setProperty('TIXYDrive', 'SpeedY', 2)

%mmc.getExposure()
EXPOSURE = 15; %10ms
mmc.setExposure(EXPOSURE);

%all_pos = [1 2 3400 95; 10 20 3500 95];  % [x y z pfs_offset]
all_pos = importdata("U24-4XAPO-EB-control-12wells-0525.csv");

pos_num = length(all_pos(1, :));
t_len = 150; % 150 frame
t_gap = 200; %200ms
w = 2048;
h = 2048;
EXPOSURE_WAIT = EXPOSURE + 10;
timestamp = sprintf('%s', datestr(now,'mmdd-HHMMSS.FFF'));
time_map = zeros(pos_num, t_len);
well = 1;
well_map =  [1:6 12:-1:7];

%for i = [5 6 ]
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
    
    mmc.setProperty('TIPFSStatus', 'State', 'On');
    mmc.sleep(200);
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
    mmc.setExposure(EXPOSURE);
     mmc.clearCircularBuffer();
    
    %img = zeros(w, h, t_len, 'uint16');
    fname = sprintf('D:/CBY/exp0526/well%dxy%d.tiff', well, i);
    
    % for t = 1:t_len
    t = 1;
    while( t<=t_len )
        t_last = clock;  % clock in second
        mmc.snapImage();
        mmc.sleep(EXPOSURE_WAIT);
        img = uint16(reshape(mmc.getImage(), w, h));
        time_map(i, t) = now;
        if t ==1
            EXPOSURE_TMP = EXPOSURE;
            while( min(img(:)) ==0 )
                EXPOSURE_TMP = EXPOSURE_TMP*0.7 ;
                mmc.setExposure(EXPOSURE_TMP);
                mmc.snapImage();
                mmc.sleep(EXPOSURE_TMP + 10);
                tmp = mmc.getExposure();
                disp(tmp)
                img = uint16(reshape(mmc.getImage(), w, h));
                time_map(i, t) = now;
            end
            options.overwrite = true;
            options.append = false;
            options.message = false;
            saveastiff(img, fname, options);
        else
            options.overwrite = false;
            options.append = true;
            options.message = false;
            saveastiff(img, fname, options);
        end
        t = t + 1;
        while (clock - t_last < t_gap/1000)
            mmc.sleep(1); % minial fresh time: 1ms
        end
        % Save to stack tiff
        %options.overwrite=true;
        %   saveastiff(img, fname, options);
        %end
    end
end

save('D:/CBY/exp0526/time_info.mat', 'time_map');
