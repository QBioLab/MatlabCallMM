function [mmc, trigger] = initialize(trigger_port)
%% Initlize micro-manager
% import micro-manage studio and mmcore here
studio =org.micromanager.internal.MMStudio(false);
mmc = studio.core();
mmc.enableDebugLog(false); % to remove mutiple l4j error
mmc.waitForSystem();

% Connect to D-LED arduino trigger
trigger = serial(trigger_port, 'BaudRate', 115200);
fopen(trigger);
