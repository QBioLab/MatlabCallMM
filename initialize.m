function [mmc, trigger] = initialize(config)
%% Initlize microscope
% import micro-manage studio and mmcore here
studio =org.micromanager.internal.MMStudio(false);
mmc = studio.core();
mmc.waitForSystem();

% Connect to D-LED arduino trigger
trigger = serial('COM6', 'BaudRate', 115200);
fopen(trigger);
