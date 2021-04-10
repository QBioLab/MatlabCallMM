% Fast 3D imaging for mRNA  
% HF 20210305

% EXPERIMENT PARAMETERS %
dataDir='H:/20210408';
W = 1900; H = 1300; % camera pixel size
EXPOSURE = 250; % camera exposure time in ms
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
mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER SOURCE', 'INTERNAL');
%set to global reset
mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER GLOBAL EXPOSURE', 'GLOBAL RESET');
%mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER GLOBAL EXPOSURE', 'DELAYED');
mmc.setProperty('Wheel-A', 'Label','Filter-4');
%mmc.setProperty('CSUX-Dichroic', 'State', 0);



% load map from file

% park to home
mmc.setXYPosition(map(1, 1), map(2,1));
mmc.setPosition(map(3,1));

mmc.waitForSystem();

tic
%XYZT TIMELAPSE
for t=121:121
    for pos=1:POS_NUM
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
            info(4, pos, t) = info(4, pos, t) + 1;
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
                    end
                    timeout = timeout - 1;
                end
            end
        end
        
        info(1, pos, t) = x_now;
        try
            info(2, pos, t) = mmc.getYPosition();
        end
        try
            info(3, pos, t) = mmc.getPosition();
        end

        % begin sequenced acquitistion
        imgB = zeros(W, H, Z_NUM, 'uint16');
        imgG = zeros(W, H, Z_NUM, 'uint16');
        for slice=1:Z_NUM
                mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint405', '5'); 
                mmc.sleep(20);
                mmc.snapImage();
                img_raw = typecast(mmc.getImage(), 'uint16');
                imgB(:, :, slice)= uint16(reshape(img_raw, W, H)); 
                mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint405', '0'); 
                mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint488', '5'); 
                mmc.sleep(20);
                mmc.snapImage();
                img_raw = typecast(mmc.getImage(), 'uint16');
                imgG(:, :, slice)= uint16(reshape(img_raw, W, H)); 
                mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint488', '0');
                mmc.setRelativePosition('PiezoStage', Z_GAP);
                mmc.sleep(20);
        end

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

        fnameB = sprintf('%s/pos%03dt%03d-B.tiff', dataDir, pos, t);    
        fnameG = sprintf('%s/pos%03dt%03d-G.tiff', dataDir, pos, t);

        saveastiff(imgB, fnameB);
        saveastiff(imgG, fnameG);
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
