%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Capture mulitpositions
% | Version | Commit
% | 20200601| low exposure change, add counte to break dead loop @HF
% | 20200615| skip well center point @HF
% | 20200624| Add multi color support
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

data_dir = 'F:/cby/exp0624';
PFS = 4036;

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti_Color.cfg');
end

mmc.setProperty('Lumencor', 'State', 1); % enable lumencor
mmc.setProperty('TIXYDrive', 'SpeedX', 2);
mmc.setProperty('TIXYDrive', 'SpeedY', 2);
%mmc.setProperry('TILightPath', 'Label', '3-Right100')
mmc.setProperty('TILightPath', 'State', '2'); % Use right camera
mmc.setProperty('TINosePiece', 'Label', '1-Plan Apo 4x NA 0.20 Dry');
mmc.setProperty('TIFilterBlock1', 'Label', '2-DIA'); % 2-DIA or 5-Conti
mmc.setProperty('LudlWheel', 'State', '2'); % Ludl filter: use green emission filter

W = 2048; H = 2048;
EXPOSURE = 15; %10ms
mmc.setExposure(EXPOSURE);

%all_pos = [1 2 3400 95; 10 20 3500 95];  % [x y z pfs_offset]
all_pos_full = importdata("U24-4XAPO-EB-control-12wells-0525.csv");
well_map =  [1:6 12:-1:7];
all_pos = all_pos_full((9-1)*21+1:10*21);
pos_num = length(all_pos(1, :));
time_map = zeros(pos_num, 1);
z_map = zeros(pos_num, 1);

channel_name = ['BF', 'Teal', 'Green'];
channel_exposure = [ 15 200 200];
channel_level= [ 10 10 10];
channel_num = length(channel_exposure);
for ch = 1:channel_num % set channel intensity
    intensity = channel_level(ch)
    if channel == 1 %BF
        mmc.setProperty('BFLED', 'Intensity', intensity);
        mmc.setProperty('BFLED', 'State', 1);
    else
        mmc.setProperty('Lumencor', [channel_name '_Level'], intensity);
end


mmc.setProperty('TIPFSStatus', 'State', 'Off');
mmc.setPosition(all_pos(3, 1)); % only run at the first time

for i = 1:pos_num
    disp(i);
    % Set new position and set PFS
    mmc.setXYPosition(all_pos(1, i), all_pos(2, i ));
    mmc.setProperty('TIPFSOffset', 'Position', PFS/40);
    mmc.waitForDevice('TIXYDrive');
    if mod(i, 21) == 1
        mmc.sleep(3000);
        well = well +1;
    else
        mmc.sleep(300);
    end
    % Use PFS for focus
    if mod(i, 21) ~= 11 % TODO: image blur at well center
        mmc.setProperty('TIPFSStatus', 'State', 'On');
        mmc.sleep(4000); %200);
        mmc.waitForSystem();
        mmc.setProperty('TIPFSStatus', 'State', 'Off');
    end
    z_map(i) = mmc.getPosition(); % save z postion
    mmc.setExposure(EXPOSURE);
    mmc.clearCircularBuffer(); % clear camera buffer
    
    fname = sprintf('%s/well%dxy%d.tiff', data_dir, well, i);
    % Capture image time by time
    for channel in 1:channel_num
         % Update light source
         EXPOSURE = channel_exposure( channel );
         % Update exposure for difference light source
         if channel == 1 %bf
             mmc.setProperty('BFLED', 'State', 1);
         else % enable excited light
             mmc.setProperty('Lumencor', [channel_name '_Enable'], 1);
         end
         mmc.setExposure( EXPOSURE );
         time_map(i) = now;
         mmc.snapImage();
         mmc.sleep(EXPOSURE + 10); % wait for exposure
         img = uint16( reshape(mmc.getImage(), W, H) );
         if channel == 1 % Write first page 
             mmc.setProperty('BFLED', 'State', 0);
             options.overwrite = true;
             options.append = false;
             options.message = false;
             saveastiff(img, fname, options);
         else % Append to tiff
             mmc.setProperty('Lumencor', [channel_name '_Enable'], 0);
             options.overwrite = false;
             options.append = true;
             options.message = false;
             saveastiff(img, fname, options);
         end
    end
end

save([data_dir 'all_info.mat'], 'time_map', 'z_map');
