%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Key action to capture image, move stage, control PFS
% HF 20200522
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

import mmcorej.*
mmc= CMMCore;
config = 'config\MMConfig_Ti.cfg'
addpath(genpath('C:\Program Files\Micro-Manager-2.0gamma'));
mmc.loadSystemConfiguration(config);
mmc.waitForSystem()
mmc.getExposure()
mmc.setExposure(5)
 mmc.waitForImageSynchro()
 mmc.getProperty('TIPFSStatus', 'State')
 mmc.setProperty('TIPFSOffset', 'State', 'Off')
mmc.getProperty('TIPFSOffset', 'Position')
mmc.setProperty('TIPFSOffset', 'Position', 96)
mmc.setProperty('TIPFSOffset', 'State', 'On')
mmc.snapImage()
imgtmp = mmc.getImage();
w = mmc.getImageWidth();
h = mmc.getImageHeight();
img = reshape(imgtmp, w, h);
%imgfile = Tiff('test',  'w');
%imgfile.write(img)
%metadata.write();