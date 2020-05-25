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
EXPOSURE_WAIT = EXPOSURE + 5;
timestamp = sprintf('%s', datestr(now,'mmdd-HHMMSS.FFF'));
time_map = zeros(pos_num, t_len);
well = 1;
well_map =  [1:6 12:-1:7];


fname = sprintf('well%dxy%d.tiff', well, i);
%for i = [1 6 21 22]
for i = 1:pos_num
    disp(i);
    % Set new position and set PFS
    mmc.setXYPosition(all_pos(1,i), all_pos(2,i ));
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
    mmc.setPosition(all_pos(3, i));
    mmc.setProperty('TIPFSOffset', 'Position', 4029/40);
    mmc.waitForDevice('TIZDrive');
    mmc.waitForDevice('TIXYDrive');
    if mod(i, 21) == 1
       mmc.sleep(3000);
    else
        mmc.sleep(300);
    end
	
    mmc.setProperty('TIPFSStatus', 'State', 'On');
    mmc.sleep(100);
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
   
    %img = zeros(w, h, t_len, 'uint16');
    fname = sprintf('D:/CBY/exp0525/well%dxy%d.tiff', well, i);
    for t = 1:t_len
        t_last = clock;  % clock in second
        mmc.snapImage();
        mmc.sleep(EXPOSURE_WAIT);
        img = uint16(reshape(mmc.getImage(), w, h));
        time_map(i, t) = now;
        if t ==1
            options.overwrite = true;
            options.append = false;
            options.message = false;
            saveastiff(img, fname, options)
        else
			options.overwrite = false;
			options.append = true;
            options.message = false;
			saveastiff(img, fname, options);
        end
        
        while (clock - t_last < t_gap/1000)
            mmc.sleep(1); % minial fresh time: 1ms
        end
    end
    
    % Save to stack tiff
    %options.overwrite=true;
    %%   saveastiff(img, fname, options);
    %end
end

save('D:/CBY/exp0525/time_info.mat', 'time_map');
