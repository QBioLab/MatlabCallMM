%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% HF 20200523
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  if exist('mmc', 'var')
        warning("Don't initialize MMCore again!");
  else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti.cfg');
  end

mmc.getExposure()
mmc.setExposure(5)
mmc.waitForImageSynchro()

%pos = [1 2 3 3400 95; 10 20 30 3500 95]; % [x y z pfs_offset]

pos_map= zeros( 4);

for i = pos
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
end