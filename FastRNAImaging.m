% Fast 3D imaging for C. elegans Neurons 
% HF 20210118

% EXPERIMENT PARAMETERS %
dataDir='H:/20210119';
W = 1900; H = 1300; % camera pixel size
EXPOSURE = 280; % camera exposure time in ms
TP = 120; % total time points
POS_NUM = 75; % total position number
Z_NUM = 20; % total z slice number
Z_GAP = -0.5; % z gap in um

% HARDWARD INITIALIZATION
% load all device under micromanager
if ~exist('mmc', 'var')
    mmc = initialize('config\spinningdisk_hamamatsu.cfg');    
end
mmc.setExposure(EXPOSURE);
% set arduino as camera external trigger
if ~exist('trigger', 'var')
    trigger = serialport('COM31', 57600);
    write(trigger, '0', 'string');
end

% AUTO GENERATE FOCUSED MAP 
if ~exist('map', 'var')
    [map, map_imgs] = buildmap(POS_NUM, mmc);
end
% park to home
mmc.setXYPosition(map(1, 1), map(2,1));
mmc.setPosition(map(3,1));

% CAPTURE DARK FRAME
if ~exist('df', 'var')
    disp("Capturing dark frame")
    df = capturedarkframe(mmc, trigger);
    dfname = sprintf('%s/darkfield.tiff', dataDir);
    saveastiff(df, dfname);
    disp("Save dark frame done");
end

% OPEN LAMP FOR LIGHTON
mmc.setProperty('TIDiaLamp', 'Intensity', 17);
mmc.setProperty('TIDiaLamp', 'State', 1); % open lamp
mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '10');

% EXPERIMENT INFORMATION %
pfs_offset = mmc.getProperty('TIPFSOffset', 'Position');
info = zeros(4, POS_NUM, TP); % x,y,z,stage

% Load laser power sequence
load('dynamic_excitation.mat', 'laser_dynamics')
% set laser to zeros for test
%mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '0'); 
mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', laser_dynamics(1))

tic
%XYZT TIMELAPSE
for t=10:TP
    for pos=1:POS_NUM
        % move to next target point
        disp(['Current: ', 't', num2str(t),' p', num2str(pos)]);
        x= map(1, pos); y= map(2, pos); z = map(3, pos);
        x_now = mmc.getXPosition();
        timeout = 2;
        mmc.waitForSystem() % maybe not necceesary
        % check stage's posotion
        while(timeout>0 && (x_now - x)>10 )
            info(4, pos, t) = info(4, pos, t) + 1;
            disp("correcting stage");
            try 
                mmc.setXYPosition(x, y);
            catch
                mmc.sleep(20);
                mmc.setXYPosition(x, y);
            end
            mmc.sleep(30); 
            x_now = mmc.getXPosition();
            timeout = timeout - 1; % try 2 times
        end

        % Open PFS at each hour
        if mod(t, 10)== 0 || t==1
            mmc.setProperty('TIPFSStatus', 'State', 'On');
            % wait util PFS is on 'LOCKED'
            pfs_on = false; lock = false; timeout = 7;
            while ~(pfs_on && lock) && timeout
                mmc.sleep(100); % wait 7ms
                if ~pfs_on
                    mmc.setProperty('TIPFSStatus', 'State', 'On');
                    mmc.sleep(100); % wait 7ms
                end
                pfs_on = strcmp(mmc.getProperty('TIPFSStatus', 'State'), 'On');
                lock = strcmp(mmc.getProperty('TIPFSStatus', 'Status'),  'Locked in focus');
                timeout = timeout-1;
            end
			mmc.sleep(100); % sleep 100ms
            while pfs_on
                mmc.setProperty('TIPFSStatus', 'State', 'Off');
                mmc.sleep(100);
                pfs_on = strcmp(mmc.getProperty('TIPFSStatus', 'State'), 'On');
            end
            map(3, pos) = mmc.getPosition();
        end
        
        info(1, pos, t) = x_now;
        info(2, pos, t) = mmc.getYPosition();
        info(3, pos, t)= mmc.getPosition();
        % begin sequenced acquitistion
        mmc.startSequenceAcquisition(Z_NUM, 0, false);
        img = zeros(W, H, Z_NUM, 'uint16');
        slice = 1;
        % trigger send pluse sequence to drive camera
        write(trigger, '1', 'string');
        while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
            if mmc.getRemainingImageCount() > 0
                % pop image from buffer
                img(:, :, slice)= uint16(reshape(mmc.popNextImage(), W, H));
                slice = slice+1;
                mmc.setRelativePosition('PiezoStage', Z_GAP);
            else
                mmc.sleep(1);
            end
        end
        
        mmc.stopSequenceAcquisition();
        if pos < POS_NUM
            % move to next position
            x= map(1, pos+1); y= map(2, pos+1); z = map(3, pos+1);
        else
            % park to home
            x= map(1, 1); y= map(2, 1); z = map(3, 1);
        end
        try 
            mmc.setXYPosition(x, y);
        catch 
            disp("Stage is lost");
            mmc.sleep(10);
            mmc.setXYPosition(x, y);
        end
        mmc.setPosition(z);
        mmc.setPosition('PiezoStage', 100); % park to home position
        fname = sprintf('%s/pos%03dt%03d.tiff', dataDir, pos, t);
        saveastiff(img, fname);
        %TODO: may move stage here
        disp([t pos 2 toc/600]);
    end
    % wait til 10 min
    save([dataDir '/all_info.mat'], 'pfs_offset', 'map', 'info');
    mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', laser_dynamics(t));
    while( toc < t*600) 
        mmc.sleep(10); % 1000ms
    end
end
% Unload all device mounted by micromanager
prompt = 'Do you want to unload all device? Y/N [N]: ';
str = input(prompt,'s');
if str =='Y'
    mmc.reset();
end
