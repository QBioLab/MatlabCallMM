tic;
mmc.setXYPosition(all_pos(1,1)+3100, all_pos(1,2)+1100);
%mmc.setXYPosition(all_pos(337,1), all_pos(337,2));
% mmc.setPosition('ZDrive', 4401);
mmc.waitForSystem();
disp('test')
toc