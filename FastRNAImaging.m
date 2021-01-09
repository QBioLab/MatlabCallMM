% Fast 3D imaging for C. elegans Neurons 
% HF 20210109

  if exist('mmc', 'var')
        warning("Don't initialize MMCore again!");
  else
    mmc = initialize('config\spinningdisk.cfg');
  end

% EXPERIMENT PARAMETERS %
dataDir=''
W = 512; 
H = 512; % camera ROI
EXPOSURE = 100; % camera exposure time in ms
TP = 200; % total time points
POS_NUM = 40; % total position number
Z_NUM = 20; % total z slice number
Z_GAP = 2; % z gap in um

% HARDWARD INITIAL VALUE %
mmc.setExposure(EXPOSURE);
mmc.setProperty('TILightPath', 'Label', '2-Left100');
mmc.setProperty('AndorLaserCombiner', 'DOUT', '0xfc');
% open and set laser, 0-10 
mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '5');
mmc.setProperty('CSUX-Dichroic Mirror', 'State', '0');
mmc.setProperty('CSUX-Shutter', 'State', 'Open');
mmc.setProperty('Wheel-A', 'Label', 'Filter-0'); %emission filter
mmc.setProperty('AndorLaserCombiner', 'LaserPort', 'A');

for t=1:TP
    for pos=1:POS_NUM
        % move to next target point
        x= 1; y= 2; z = 3;
        mmc.setXYPosition(x, y);
        mmc.setPosition(z);
        mmc.waitForSystem();
        % begin continue acquitistion
        mmc.startSequenceAcquisition(Z_NUM, 0, true);
        img = zeros(W, H, Z_NUM, 'uint16');
        slice = 1;
        while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
            if mmc.getRemainingImageCount() > 0
                img(:, :, slice)= uint16(reshape(mmc.popNextImage(), W, H));
                slice = slice+1;
                mmc.setRelativePosition('PiezoStage', Z_GAP);
                %TODO: find waitting time
            else
                mmc.sleep(min(.5 * EXPOSURE, 20))
            end
        end
        mmc.stopSequenceAcquisition();
        mmc.setPosition('PiezoStage', 0); % park to home position
        fname = sprintf('%spos%dt%d.tiff', dataDir, pos, t);
        saveastiff(img, fname);
    end
end
