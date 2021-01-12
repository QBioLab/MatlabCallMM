function map = buildmap(NP)
% find xyz position hf 20210112
% NOTE: start point should close to dish center; only acess n*n
% Method 1: full-auto
% Method 2: half-auto
% auto move to next points by dxdy, then confirm by user
%
%

map = zeros(3, NP); % absolute stage position in micron
dx = 2100*6.5/60; % gap between x-axis in micron
dy = 1500*6.5/60; % gap between y-axis in micron
dz = 0.2; % gap between z-axis in micron
% square spiral
spiral = zeros(2, NP); %(x, y)
width = sqrt(NP);
p_i  = 1; % point index
sp = spiral(:, p_i); % start point
% define move action
left = [-1; 0]; right = [1; 0];
down= [0; -1]; up = [0; 1];
for i = 1:width % total loop
    % 0st movement=1, down, \|/
    p_i = p_i + 1;
    spiral(:, p_i) = spiral(:, p_i-1) + down;
    % 1nd movement=2i-1, right, ->
    for p = 1:2*i-1 
        p_i = p_i + 1;
        spiral(:, p_i) = spiral(:, p_i-1) + right;
    end 
    % 2rd movement=2i, up, /|\
    for p = 1:2*i
        p_i = p_i + 1;
        spiral(:, p_i) = spiral(:, p_i-1) + up;
    end
    % 3rd movement=2i, left, <-
    for p = 1:2*i
        p_i = p_i + 1;
        spiral(:, p_i) = spiral(:, p_i-1) + left;
    end
    % 4rd movement=2i, down, \|/
    for p = 1:2*i
        p_i = p_i + 1;
        spiral(:, p_i) = spiral(:, p_i-1) + down;
    end
end

% MOVE STAGE AND FIND FOCUS
disp("Please move stage close to dish centre, at focus");
disp("Get orign from current stage position");
orign_xy = mmc.getXYPosition();
orign_z = mmc.getPosition();
map = spiral * [dx; dy; dz] + [orign_xy(1); orign_xy(2); orign_z];
% park piezeo stage close to 0
mmc.setPosition('PiezoStage', 7);
mmc.setProperty('TIPFSStatus', 'State', 'Off');
W = 512; H = 512; % camera pixel 
map_imgs = zeros(W, H, NP, 'uint16'); % Save camera image
for p = 1:NP
    disp('Moving and focus to point ', p);
    x, y = map(1:2, p);
    mmc.setXYPosition(x, y);
    mmc.setProperty('TIPFSStatus', 'State', 'On');
    mmc.sleep(100); % wait 100ms
    mmc.waitForSystem();
    mmc.snapImage()
    map_imgs(:, :, p) = uint16(reshape(mmc.getImage(), W, H));
    mmc.setProperty('TIPFSStatus', 'State', 'Off');
end

end
