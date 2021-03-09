%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Key action to capture image, move stage, control PFS
% HF 20200522
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  if exist('mmc', 'var')
        warning("Don't initialize MMCore again!");
  else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti.cfg');
  end

mmc.getExposure()
mmc.setExposure(5)
mmc.waitForImageSynchro()
% set XY position
mmc.setXYPosition(mmc.getXPosition, mmc.getYPosition)
% set Z position
mmc.setPosition(3800)
%
mmc.getProperty('TIPFSStatus', 'State')
 %mmc.setProperty('TIPFSStatus', 'State', 'Off')
mmc.getProperty('TIPFSOffset', 'Position')
%mmc.setProperty('TIPFSOffset', 'Position', 96)
mmc.setProperty('TIPFSStatus', 'State', 'On')
mmc.snapImage()
imgtmp = mmc.getImage();
w = mmc.getImageWidth();
h = mmc.getImageHeight();
img = reshape(imgtmp, w, h);
%imgfile = Tiff('test',  'w');
%imgfile.write(img)
%metadata.write();
