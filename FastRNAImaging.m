% Fast 3D imaging for C. elegans Neurons 
% HF 20210113

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    mmc = initialize('config\spinningdisk_andor.cfg');
end

% EXPERIMENT PARAMETERS %
dataDir='../test';
W = 512; 
H = 512; % camera ROI
EXPOSURE = 150; % camera exposure time in ms
TP = 3; % total time points
POS_NUM = 100; % total position number
Z_NUM = 20; % total z slice number
Z_GAP = 2; % z gap in um

% HARDWARD INITIAL VALUE %
mmc.setExposure(EXPOSURE);
mmc.setProperty('TILightPath', 'Label', '2-Left100');
mmc.setProperty('AndorLaserCombiner', 'DOUT', '0xfc');
mmc.setPosition('PiezoStage', 5); % park to home position
% open and set laser, 0-10 
mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '10');
mmc.setProperty('CSUX-Dichroic Mirror', 'State', '0');
mmc.setProperty('CSUX-Shutter', 'State', 'Open');
mmc.setProperty('Wheel-A', 'Label', 'Filter-6'); %red emission filter
mmc.setProperty('AndorLaserCombiner', 'LaserPort', 'A');

% AUTO GENERATE FOCUSED MAP 
[map, map_imgs] = buildmap(POS_NUM, mmc);

% XYZT TIMELAPSE
for t=1:TP
    for pos=1:POS_NUM
        % move to next target point
        disp(['Current: ', 't', num2str(t),' p', num2str(pos)]);
        x= map(1, pos); y= map(2, pos); z = map(3, pos);
        mmc.setXYPosition(x, y);
        mmc.setPosition(z);
        mmc.waitForSystem();
        % begin continue acquitistion
        mmc.startSequenceAcquisition(Z_NUM, 0, false);
        img = zeros(W, H, Z_NUM, 'uint16');
        slice = 1;
        while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
            if mmc.getRemainingImageCount() > 0
                %TODO: use arduino as wave generator to trigger camera
                img(:, :, slice)= uint16(reshape(mmc.popNextImage(), W, H));
                slice = slice+1;
                mmc.setRelativePosition('PiezoStage', Z_GAP);
                mmc.sleep(7); % wait 3ms for piezostage stable
                %TODO: find eough time for waitting
            else
                mmc.sleep(min(.5 * EXPOSURE, 20))
            end
        end
        mmc.stopSequenceAcquisition();
        mmc.setPosition('PiezoStage', 5); % park to home position
        fname = sprintf('%spos%dt%d.tiff', dataDir, pos, t);
        saveastiff(img, fname);
    end
end
