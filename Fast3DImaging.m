%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fast 3D imaging for C. elegans Neurons 
% HF 20210108
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  if exist('mmc', 'var')
        warning("Don't initialize MMCore again!");
  else
    mmc = initialize('config\spinningdisk.cfg');
  end

mmc.setExposure(10)
mmc.waitForImageSynchro()
% set Z position
mmc.setPosition(3800)
%

mmc.snapImage()
imgtmp = mmc.getImage();
w = mmc.getImageWidth();
h = mmc.getImageHeight();
img = reshape(imgtmp, w, h);
%imgfile = Tiff('test',  'w');
%imgfile.write(img)
%metadata.write();
