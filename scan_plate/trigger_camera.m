function [] = trigger_camera(trigger_serial)
%TRIGGER_CAMERA Summary of this function goes here
%   Detailed explanation goes here
try
    fprintf(trigger_serial, '&CAMEXP#');
catch
    fclose(trigger_serial);
    fopen(trigger_serial);
    fprintf(trigger_serial, '&CAMEXP#');
end

end

