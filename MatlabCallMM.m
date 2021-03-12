%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Key action to capture image, move stage, control PFS
% HF 20210312
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  if exist('mmc', 'var')
        warning("Don't initialize MMCore again!");
  else
    mmc = initialize('C:\Users\qblab\Documents\MMConfig_Ti.cfg');
  end

% Set Default Camera exposure in ms
mmc.setExposure(5);
% Get and Set XY position in um
mmc.setXYPosition(mmc.getXPosition, mmc.getYPosition);
% Set Z focuser position in um
mmc.setPosition(3800);
% Get Ti PFS state and Position
mmc.getProperty('TIPFSStatus', 'State');
mmc.getProperty('TIPFSOffset', 'Position');
% Turn On Ti PFS
mmc.setProperty('TIPFSStatus', 'State', 'On');

% Exposure Single Image 
mmc.snapImage();
% Return a 1D array of signed integers in row-major order
imgtmp = mmc.getImage(); 
w = mmc.getImageWidth();
h = mmc.getImageHeight();
if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end
% Interprete pixels as unsigned integers
img = typecast(img, pixelType); 
% Interprete as a 2D array
img = reshape(imgtmp, w, h);
% Make column-major order for MATLAB
img = transpose(img);