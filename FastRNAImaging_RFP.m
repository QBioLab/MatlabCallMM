% Fast 3D imaging for mRNA  
% HF 20210305

% EXPERIMENT PARAMETERS %
dataDir='H:/20210331';
W = 1900; H = 1300; % camera pixel size
EXPOSURE = 280; % camera exposure time in ms
TP = 120; % total time points
POS_NUM = 58; % total position number
Z_NUM = 20; % total z slice number
Z_GAP = -0.5; % z gap in um
diary(dataDir+"/matlablog.log")


% HARDWARD INITIALIZATION
% load all device under micromanager
if ~exist('mmc', 'var')
    mmc = initialize('config\spinningdisk_hamamatsu.cfg');    
end
mmc.setExposure(EXPOSURE);
%set external trigger
mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER SOURCE', 'EXTERNAL');
%set to global reset
mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER GLOBAL EXPOSURE', 'GLOBAL RESET');

% set arduino as camera external trigger
if ~exist('trigger', 'var')
    trigger = serialport('COM31', 57600);
    write(trigger, '0', 'string');
end

% AUTO GENERATE FOCUSED MAP 

% park to home
mmc.setXYPosition(map(1, 1), map(2,1));
mmc.setPosition(map(3,1));
mmc.setProperty('Wheel-A', 'Label','Filter-6');
mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '10'); 
mmc.waitForSystem();


%XYZT TIMELAPSE
for t=1:1
    for pos=1:29
        % move to next target point
        disp(['Current: ', 't', num2str(t),' p', num2str(pos)]);
        x = map(1, pos); y = map(2, pos); z = map(3, pos);
        try
            x_now = mmc.getXPosition();
        catch ME
            warning("Stage error");
            x_now = 0; % set x_now be 0 to start calibration
        end
        mmc.waitForSystem(); % maybe not necceesary
        % check stage's posotion
        timeout = 2;
        while(timeout>0 && abs(x_now - x)>10 )
            % count time of calibration
            disp("correcting stage");
            try 
                mmc.setXYPosition(x, y);
            catch ME
                %if (strcmp(ME.identifier, ''))
                
                warning("Stage error");
            end
            mmc.sleep(30); 
            try
                x_now = mmc.getXPosition();
            catch ME
                warning("Stage error");
            end
            mmc.sleep(30)
            timeout = timeout - 1; % try 2 times
        end

        % Open PFS each half of hour
        %if mod(t, 2) == 1 
        if true
            % MUST CONFIRM PiezoStage at home position
            timeout = 2;
            while(timeout > 0)
                timeout = timeout - 1;
                try 
                    mmc.setPosition('PiezoStage', 100); % park to home position
                    timeout = 0;
                catch 
                    disp("Stage is lost");
                    mmc.sleep(100);
                end
            end

            %if pos == 1

            if true
                % wait util PFS is on 'LOCKED'
                pfs_on = false; lock = false; timeout = 3;
                while ~(pfs_on && lock) && timeout
                    mmc.sleep(100); % wait 7ms
                    if ~pfs_on
                        try 
                            mmc.setProperty('TIPFSStatus', 'State', 'On');
                            mmc.sleep(100); % wait 100ms
                        end
                    end
                    try
                        pfs_on = strcmp(mmc.getProperty('TIPFSStatus', 'State'), 'On');
                    end
                    try
                        lock = strcmp(mmc.getProperty('TIPFSStatus', 'Status'),  'Locked in focus');
                    end
                    timeout = timeout-1;
                end
			    mmc.sleep(100); % sleep 100ms
                % close PFS
                while pfs_on
                    try
                        mmc.setProperty('TIPFSStatus', 'State', 'Off');
                    end
                    mmc.sleep(100);
                    try
                        pfs_on = strcmp(mmc.getProperty('TIPFSStatus', 'State'), 'On');
                    end
                end
                timeout = 2;
                while(timeout >0 )
                    try
                        z_last = map(3, pos);
                        map(3, pos) = mmc.getPosition();
                        %z_drift(t) = map(3, pos) - z_last;
                        % update all other position's z
                        %if abs(z_drift(t)) < 15 % only update when drift less than 15um
                         %   map(3, 2:end) = map(3, 2:end) + z_drift(t);
                         %   timeout = 0;
                        %end
                    end
                    timeout = timeout - 1;
                end
            end
        end
       

        % begin sequenced acquitistion
        mmc.startSequenceAcquisition(Z_NUM, 0, false);
        img = zeros(W, H, Z_NUM, 'uint16');
        slice = 1;
        % Arudino trigger send pluse sequence to drive camera
        write(trigger, '1', 'string');
        while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
            if mmc.getRemainingImageCount() > 0
                % pop image from buffer
                img_raw = typecast(mmc.popNextImage(), 'uint16');
                img(:, :, slice)= uint16(reshape(img_raw, W, H));
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
        timeout = 2;
        while(timeout > 0)
            timeout = timeout - 1;
            try 
                mmc.setXYPosition(x, y);
                timeout = 0;
            catch 
                disp("Stage is lost");
                mmc.sleep(100);
            end
        end
        timeout = 2;
        while(timeout > 0)
            timeout = timeout - 1;
            try 
                mmc.setPosition(z);
                timeout = 0;
            catch 
                disp("Stage is lost");
                mmc.sleep(100);
            end
        end
        timeout = 2;
        while(timeout > 0)
            timeout = timeout - 1;
            try 
                mmc.setPosition('PiezoStage', 100); % park to home position
                timeout = 0;
            catch 
                disp("Stage is lost");
                mmc.sleep(100);
            end
        end

        fname = sprintf('%s/pos%03dt%03d-R.tiff', dataDir, pos, t);
        saveastiff(img, fname);
        %TODO: may move stage here
        disp([t pos toc/600]);
    end
end
% Unload all device mounted by micromanager
prompt = 'Do you want to unload all device? Y/N [N]: ';
str = input(prompt,'s');
if (str =='Y') | (str == 'y')
    mmc.reset(); 
end
