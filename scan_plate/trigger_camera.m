function [] = trigger_camera(trigger_serial)
%TRIGGER_CAMERA Summary of this function goes here
%   Detailed explanation goes here
try
    fprintf(trigger_serial, '&CAMEXP#');
    %fscanf(trigger_serial); %clear the contents of the serial port buffe
catch
    fclose(trigger_serial);
    fopen(trigger_serial);
    fprintf(trigger_serial, '&CAMEXP#');
	%fscanf(trigger_serial); %clear the contents of the serial port buffe
end

end

