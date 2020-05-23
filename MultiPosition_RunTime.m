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


all_pos = [1 2 3400 95; 10 20 3500 95];  % [x y z pfs_offset]

for t =1:3
    for i = 1: size(all_pos(:,1))
        mmc.setXYPosition(all_pos(i,1), all_pos(i,2));
        mmc.setProperty('TIPFSStatus', 'State', 'Off')
        mmc.setPosition(all_pos(i, 3));
        mmc.setProperty('TIPFSOffset', 'Position', all_pos(i, 4));
        mmc.setProperty('TIPFSStatus', 'State', 'On');
        %mmc.waitForDevice();
        mmc.snapImage();
        %mmc.waitForImageSynchro()
        imgtmp = mmc.getImage();
        fname = sprintf('xy%dt%d.mat',i ,t);
        save(fname, 'imgtmp');
    end
end