%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fast 3D imaging for C. elegans Neurons 
% HF 20210109
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  if exist('mmc', 'var')
        warning("Don't initialize MMCore again!");
  else
    mmc = initialize('config\spinningdisk.cfg');
  end

% EXPERIMENT PARAMETERS %
dataDir=''
W = 1900; 
H = 1300; % camera ROI
EXPOSURE = 100; % camera exposure time in ms
TP = 200; % total time points
POS_NUM = 40; % total position number
Z_NUM = 20; % total z slice number
Z_GAP = 2; % z gap in um

% HARDWARD INITIAL VALUE %
mmc.setExposure(EXPOSURE);
mmc.setPropetry('TILightPath', 'Label', '2-Left100');
% open and set laser


for t=1:TP
    for pos=1:POS_NUM
        % move to next target point
        x= 1; y= 2; z = 3;
        mmc.setXYPosition(x, y);
        mmc.setPosition(z);
        mmc.waitForSystem();
        % begin continue acquitistion
        mmc.startSequenceAcquisition(Z_NUM, 0, true);
        img = zeros(W, H, Z_NUM);
        slice = 0;
        while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
            if mmc.getRemainingImageCount() > 0
                img(:, :, slice)= unit16(reshape(mmc.popNextImage(), W, H));
                slice = slice+1;
                mmc.setRelativePosition(PiezoStage, Z_GAP);
            else
                mmc.sleep(min(.5 * exposureMs, 20))
            end
        end
        mmc.stopSequenceAcquisition();
        mmc.setPosition(PiezoStage, 0); % park to home position
        fname = sprintf('%s/pos%dt%d.tiff', dataDir, pos, t)
        imgfile = Tiff(fname, 'w');
        imgfile.write(img)
        %metadata.write(); did it require?
    end
end
