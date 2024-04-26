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


curFrame = 0;
tic()
while (curFrame < nrFrames)
      mmc.snapImage();
      img = mmc.getImage();
      curFrame = curFrame+1;
end
mmc.stopSequenceAcquisition();
toc()