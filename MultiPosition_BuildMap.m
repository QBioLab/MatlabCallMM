%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% HF 20200523
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    %mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti.cfg');
    mmc = initialize('C:\Users\qblab\andor4.2-stage.cfg');
end

mmc.getExposure()
EXPOSURE = 0.1;
mmc.setExposure(EXPOSURE);

mmc.setTimeoutMs(50000)
mmc.enableDebugLog(true)
mmc.setPrimaryLogFile('test.log')

seed_num = 3;
% pos_seeds= zeros(3, seed_num);
% % Give initial position by hand
% input('Type Enter to begin selection', 's');
% %mmc.setProperty('TIPFSStatus', 'State', 'Off')
% for i = 1:seed_num
%     input('Please move stage to select seed, then type Enter to mark', 's');
%     %mmc.setProperty('TIPFSStatus', 'State', 'On')
%     pos_seeds(1, i) = mmc.getXPosition;
%     pos_seeds(2, i) = mmc.getYPosition;
%     pos_seeds(3, i) = mmc.getPosition;
%     %pos_seeds(i, 4) = mmc.getProperty('TIPFSOffset', 'Position');
% end

pixel_num = 2048;
pixel_size = 6.5; %um
obj_mag = 2;
w = 2048;
h = 2048;
STEP = - pixel_num * pixel_size / obj_mag;
ALPHA = 3*STEP;%- 16300/2;
for i = 1:seed_num
    img = zeros(2048, 2048, 13, 'uint16');
    count = 1;
    mmc.setPosition(pos_seeds(3, i));
    mmc.waitForSystem()
    %mmc.waitForDevice('TIXYDrive')
    x0 = pos_seeds(1, i);
    y0 = pos_seeds(2, i) - ALPHA;
    mmc.setXYPosition( x0-3*STEP, y0) ;
    mmc.assignImageSynchro('XYStage')
    %mmc.sleep(3000);
    for x = -3:3
        mmc.setXYPosition('XYStage', x0+x*STEP, y0) ;
        %mmc.waitForDevice('TIXYDrive');
        %mmc.waitForSystem();
         %mmc.deviceBusy('TIXYDrive')
        %input('debug','s');
        %mmc.sleep(100); % wait for 10ms
        %mmc.waitForImageSynchro();
        %mmc.sleep(1000);
        
        mmc.snapImage();
        mmc.sleep(5+1+EXPOSURE);
        %mmc.sleep(100)
        img(:,:, count) = transpose(reshape(mmc.getImage(), w, h));
        count = count + 1;
    end
    mmc.setXYPosition('XYStage', x0, pos_seeds(2,i));
    mmc.sleep(1000)
    for y = [3, 2, 1, -1, -2, -3]
        mmc.setXYPosition('XYStage', x0, y0+y*STEP);
        %mmc.waitForDevice('TIXYDrive');
        %mmc.waitForSystem()
        %mmc.deviceBusy('TIXYDrive')        
        %input('debug','s');
        %mmc.sleep(100); % wait for 10ms
        %mmc.waitForImageSynchro();
        %mmc.sleep(1000)
        mmc.snapImage();
        mmc.sleep(5+1+EXPOSURE);
        img(:,:, count) = transpose(reshape(mmc.getImage(), w, h));
        count = count + 1;
    end
    fname = sprintf('seed%d.tiff', i);
    options.overwrite=true;
    saveastiff(img, fname, options);     
end
