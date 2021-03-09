%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% burst acquisition
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if exist('mmc', 'var')
    warning("Don't initialize MMCore again!");
else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti_Color_Hamamatsu.cfg');
end

nrFrames = 500;
%exposureMs = mmc.getExposure();
exposureMs = 30;
mmc.setExposure(exposureMs);

% Start collecting images.
% Arguments are the number of images to collect, the amount of time to wait
% between images, and whether or not to halt the acquisition if the
% sequence buffer overflows.
mmc.startSequenceAcquisition(nrFrames, 0, true);

curFrame = 0;
tic()
while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice())) 
   if mmc.getRemainingImageCount() > 0 
      tagged = mmc.popNextImage();
      %store.putImage(image);
      curFrame = curFrame+1;
   else 
      mmc.sleep(min(.5 * exposureMs, 20))
   end
end
mmc.stopSequenceAcquisition();
toc()