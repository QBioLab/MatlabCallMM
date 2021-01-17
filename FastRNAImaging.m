% Fast 3D imaging for C. elegans Neurons 
% HF 20210113

if exist('mmc', 'var')
     warning("Don't initialize MMCore again!");
else
     mmc = initialize('config\spinningdisk_hamamatsu.cfg');    
 end
% 
% EXPERIMENT PARAMETERS %
dataDir='H:/20210117/';
W = 1900; 
H = 1300; % camera ROI
EXPOSURE = 250; % camera exposure time in ms
TP = 120; % total time points
POS_NUM = 81; % total position number
Z_NUM = 17; % total z slice number
Z_GAP = -0.5; % z gap in um
% 
% EXPERIMENT INFORMATION %
pfs_offset = mmc.getProperty('TIPFSOffset', 'Position');
info = zeros(3, POS_NUM, TP);
% 
% HARDWARD INITIAL VALUE %
mmc.setExposure(EXPOSURE);
mmc.setProperty('TILightPath', 'Label', '2-Left100');
mmc.setProperty('AndorLaserCombiner', 'DOUT', '0xfc');
mmc.setPosition('PiezoStage', 50); % park to home position
mmc.setProperty('TIDiaLamp', 'State', 0); % close lamp
mmc.setProperty('TIDiaLamp', 'Intensity', 17);
% set camera ROI fit to scan header
mmc.setROI(16, 628, 1900, 1300);
%set I/O function
% set to external tiggger
mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER SOURCE', 'EXTERNAL');
mmc.setProperty('HamamatsuHam_DCAM', 'OUTPUT TRIGGER KIND[0]', 'EXPOSURE');
mmc.setProperty('HamamatsuHam_DCAM', 'OUTPUT TRIGGER POLARITY[0]', 'POSITIVE');
%set to global reset
mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER GLOBAL EXPOSURE', 'GLOBAL RESET');
%set trigger be positive polarity
mmc.setProperty('HamamatsuHam_DCAM', 'TriggerPolarity', 'NEGATIVE');
mmc.setProperty('HamamatsuHam_DCAM', 'ScanMode', 1);
% open and set laser, 0-10 
mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '10');
mmc.setProperty('CSUX-Dichroic Mirror', 'State', '0');
mmc.setProperty('CSUX-Shutter', 'State', 'Open');
mmc.setProperty('Wheel-A', 'Label', 'Filter-6'); %red emission filter
mmc.setProperty('AndorLaserCombiner', 'LaserPort', 'A');
% set arduino trigger
trigger = serialport('COM31', 57600);
write(trigger, 0, 'string');

% AUTO GENERATE FOCUSED MAP 
[map, map_imgs] = buildmap(POS_NUM, mmc);
mmc.setProperty('TIDiaLamp', 'State', 1); % open lamp
%  
tic
%XYZT TIMELAPSE
for t=1:TP
    for pos=1:POS_NUM
        % move to next target point
        disp(['Current: ', 't', num2str(t),' p', num2str(pos)]);
        x= map(1, pos); y= map(2, pos); z = map(3, pos);
        % catch stage offline error
        try 
            mmc.setXYPosition(x, y);
            mmc.setPosition(z);
        catch 
            mmc.sleep(100);
            mmc.setXYPosition(x, y);
            mmc.setPosition(z);
        end
        x_now = mmc.getXPosition();
        timeout = 2;
        % avoid stage fail to move 
        while(timeout>0 && (x_now - x)> 10 )
            try 
                mmc.setXYPosition(x, y);
            catch
                mmc.sleep(100);
                mmc.setXYPosition(x, y);
            end
            mmc.sleep(100); 
            x_now = mmc.getXPosition();
            timeout = timeout - 1; % try 2 times
        end
        
        % Open PFS at each hour
        if mod(t, 10)== 0
            mmc.setProperty('TIPFSStatus', 'State', 'On');
            % wait PFS is on 'LOCKED'
            pfs_on = false; lock = false; timeout = 10;
            while ~( pfs_on && lock) && timeout
                mmc.sleep(7); % wait 100ms
                mmc.setProperty('TIPFSStatus', 'State', 'On');
                pfs_on = strcmp(mmc.getProperty('TIPFSStatus', 'State'), 'On');
                lock = strcmp(mmc.getProperty('TIPFSStatus', 'Status'),  'Locked in focus');
                timeout = timeout-1;
            end
            mmc.setProperty('TIPFSStatus', 'State', 'Off');
            map(3, pos) = mmc.getPosition();
        end
        mmc.waitForSystem();
        info(1, pos, t) = x_now;
        info(2, pos, t) = mmc.getYPosition();
        info(3, pos, t)= mmc.getPosition();
        % begin continue acquitistion
        mmc.startSequenceAcquisition(Z_NUM, 0, false);
        img = zeros(W, H, Z_NUM, 'uint16');
        slice = 1;
        %fprintf(trigger, '%s', '1');
        write(trigger, '1', 'string');
        while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
            if mmc.getRemainingImageCount() > 0
                %TODO: use arduino as wave generator to trigger camera
                img(:, :, slice)= uint16(reshape(mmc.popNextImage(), W, H));
                slice = slice+1;
                mmc.setRelativePosition('PiezoStage', Z_GAP);
            else
                mmc.sleep(min(.5 * EXPOSURE, 20));
            end
        end
        mmc.stopSequenceAcquisition();
        mmc.setPosition('PiezoStage', 50); % park to home position
        fname = sprintf('%spos%dt%d.tiff', dataDir, pos, t);
        %[pos 1 toc]
        saveastiff(img, fname);
        [t pos 2 toc/600]
    end
    % wait til 10 min
    save([dataDir '/all_info.mat'], 'pfs_offset', 'map', 'info');
    while( toc < t*600) 
        mmc.sleep(1000); % 1000ms
    end
end

