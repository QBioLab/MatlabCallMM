function [map, map_imgs] = buildmap(NP, mmc)
% find xyz position
% NOTE: start point should close to dish center; only acess n*n
% Method 1: full-auto
% Method 2: half-auto
% auto move to next points by dxdy, then confirm by user
% Usage: 
% Version Commit 
% 0.1     1st, hf, 20210113

% absolute stage position in micron
dx = 2100*6.5/60; % gap between x-axis in micron
dy = 1500*6.5/60; % gap between y-axis in micron
dz = 0.5; % gap between z-axis in micron
% square spiral
spiral = zeros(3, NP); %(x, y, z)
%map = zeros(3, NP); %(x, y, z)
width = ceil(sqrt(NP));
p_i  = 1; % point index
% define move action
left = [-1; 0]; right = [1; 0];
down= [0; -1]; up = [0; 1];
for i = 1:width % total loop
    % 0st movement=1, down, \|/
    p_i = p_i + 1;
    spiral(1:2, p_i) = spiral(1:2, p_i-1) + down;
    % 1nd movement=2i-1, right, ->
    for p = 1:2*i-1 
        p_i = p_i + 1;
        spiral(1:2, p_i) = spiral(1:2, p_i-1) + right;
    end 
    % 2rd movement=2i, up, /|\
    for p = 1:2*i
        p_i = p_i + 1;
        spiral(1:2, p_i) = spiral(1:2, p_i-1) + up;
    end
    % 3rd movement=2i, left, <-
    for p = 1:2*i
        p_i = p_i + 1;
        spiral(1:2, p_i) = spiral(1:2, p_i-1) + left;
    end
    % 4rd movement=2i, down, \|/
    for p = 1:2*i
        p_i = p_i + 1;
        spiral(1:2, p_i) = spiral(1:2, p_i-1) + down;
    end
end
spiral = spiral(:, 1:NP);
% MOVE STAGE AND FIND FOCUS
disp("Please move stage close to dish centre, tone PFS focus");
disp("Get orign from current stage position");
pfs = mmc.getProperty('TIPFSOffset', 'Position');
disp("Current PFS Offset: ");
disp( pfs);
orign_x = mmc.getXPosition();
orign_y = mmc.getYPosition();
orign_z = mmc.getPosition();
map = spiral .* repmat([dx; dy; dz],1,NP) + [orign_x; orign_y; orign_z];
% park piezeo stage close to 0
%mmc.setPosition('PiezoStage', 50);
mmc.setProperty('TIPFSStatus', 'State', 'Off');
W = 1900; H = 1300; % camera pixel 
map_imgs = zeros(W, H, NP, 'uint16'); % Save camera image
% search focus for each point
for p = 1:NP
    disp(['Moving and focusing to point ', num2str(p)]);
    x = map(1, p); y = map(2, p);
    %TODO: add auto focus fail handler
    mmc.setXYPosition(x, y);
    mmc.sleep(200);
    mmc.waitForSystem();
    mmc.setProperty('TIPFSStatus', 'State', 'On');
    % wait PFS is on 'LOCKED'
    pfs_on = false; lock = false;
    while ~( pfs_on && lock)
        mmc.sleep(7); % wait 100ms
        mmc.setProperty('TIPFSStatus', 'State', 'On');
        pfs_on = strcmp(mmc.getProperty('TIPFSStatus', 'State'), 'On');
        lock = strcmp(mmc.getProperty('TIPFSStatus', 'Status'),  'Locked in focus');
    end
    % update TI-FOCUS's z poition in map 
    map(3, p) = mmc.getPosition();
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
    %mmc.snapImage()
    %map_imgs(:, :, p) = uint16(reshape(mmc.getImage(), W, H));
end
end
