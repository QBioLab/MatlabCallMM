%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% | Version | Commit
%   test      
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

data_dir = 'F:\td\20201106';

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    import mmcorej.*
    mmc= CMMCore;
    config = 'C:\users\qblab\Documents\MMConfig_Ti_Color_PRIME.cfg'; % Point to PRIME configure file
    mmc.loadSystemConfiguration(config);
    mmc.waitForSystem();
    mmc.setTimeoutMs(50000);
end

% HARDWARE SETUP
mmc.setProperty('Spectra', 'State', 1); % enable lumencor
mmc.setProperty('TIXYDrive', 'SpeedX', 1);
mmc.setProperty('TIXYDrive', 'SpeedY', 1);
mmc.setProperty('TILightPath', 'State', '2'); % Use right camera
mmc.setProperty('TINosePiece', 'Label', '1-Plan Apo 4x NA 0.20 Dry'); % objective
mmc.setProperty('TIFilterBlock1', 'Label', '6-S-Qad'); % dimirror
mmc.setProperty('LudlWheel', 'State', '3'); % red emssion filter
W = 2048; H = 2048;
EXPOSURE = 10; %10ms
mmc.setExposure(EXPOSURE);

% EXPERIMENT PARAMETERS
%all_pos = importdata("Tandeng_organoid_1103_96well.csv");
all_pos = importdata("Tandeng_organoid_1106_96well.csv");
pos_num = length(all_pos(:, 1));
pos_per_well = 4;
well_num = ceil(pos_num/pos_per_well)
highest = 9000;
time_map = zeros(pos_num, 1);
z_gap = - 20; % 10um
z_len = 20;
z_map = zeros(pos_num, 1);
z_sharpness = zeros(z_len, well_num);

for ch = 1:channel_num % set excitation light intensity for each channel
    if ch == 1 %BF
        mmc.setProperty('Arduino-Switch', 'State', 16);
    end
end
mmc.setProperty('TIPFSStatus', 'State', 'Off');

for i =1:well_num
    disp(i);
    % Set new position and set PFS
    x0 = mean(all_pos(i*pos_per_well-3:i*pos_per_well, 1);
    y0 = mean(all_pos(i*pos_per_well-3:i*pos_per_well, 2);
    mmc.setXYPosition(x0, y0);
    mmc.setPosition( highest );
    img = zeros(W, H, 2, 'uint16'); % Prelocate meomer
    well = ceil(i/pos_per_well);
    mmc.sleep(2000);
    mmc.waitForSystem();
    
    % z stack
    z_map(i) = mmc.getPosition(); % save z postion
    for z = 1:z_len
        mmc.setRelativePosition(z_gap);
        mmc.sleep(100);
        mmc.snapImage();
        mmc.sleep(EXPOSURE + 10); % wait for exposure
        img(:, :, z, channel) = uint16( reshape(mmc.getImage(), W, H) );
    end
    options.overwrite = true;
    options.message = false;
    options.compress  = 'no';
    fname = sprintf('%s/well%dxy%dc%d_af.tiff', data_dir, well, i, channel);
    saveastiff(img(:, :, :, channel), fname, options);
    z_sharpness[:, i] = cal_sharpness(img);
end
save([data_dir 'all_info.mat'], 'time_map', 'z_map', 'z_sharpness');


% calculate sharpness of each slice
function sharpness = cal_sharpness(img)
    kernel = [-2 -1 0; -1 0 1; 0 1 2 ];
    z_num = size(img, 3);
    sharpness = zeros(z_num, 1);
    for z=1:z_num
        zslice = medfilt2(img(513:1536, 513:1536, z), [3 3]);
        zsilce = conv2(double(zslice), kernel, 'same');
        sharpness(z) = sum(zslice.*zslice, 'all');
    end
end

% find first maximum
function firstmax = find1max(src)
    firstmax = src(1);
    if length(src) > 1
        z = 2;
    else
        return
    end
    while(src(z) > firstmax)
        firstmax = src(z);
        z = z+1;
    end
end
