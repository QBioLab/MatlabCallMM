function mmc = initialize(config)
        import mmcorej.*
        mmc= CMMCore;
        %config = 'config\MMConfig_Ti.cfg';
        %config = 'C:\users\qblab\Documents\MMConfig_Ti.cfg';
        try
            mmc.loadSystemConfiguration(config);
        catch
            disp("Fail to load microscope");
            mmc.reset();
        end
        mmc.waitForSystem();
        mmc.setTimeoutMs(50000);
        
        mmc.setExposure(250);
        mmc.setProperty('TILightPath', 'Label', '2-Left100');
        mmc.setProperty('AndorLaserCombiner', 'DOUT', '0xfc');
        mmc.setPosition('PiezoStage', 100); % park to home position
        mmc.setProperty('TIDiaLamp', 'State', 0); % close lamp
        % set camera ROI fit to scan header
        mmc.setROI(16, 592, 1900, 1300);
        %set I/O function
        % set to external tiggger
        mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER SOURCE', 'EXTERNAL'); 
        mmc.setProperty('HamamatsuHam_DCAM', 'OUTPUT TRIGGER KIND[0]', 'EXPOSURE');
        mmc.setProperty('HamamatsuHam_DCAM', 'OUTPUT TRIGGER POLARITY[0]', 'POSITIVE');
        %set to global reset
        mmc.setProperty('HamamatsuHam_DCAM', 'TRIGGER GLOBAL EXPOSURE', 'GLOBAL RESET');
        %set trigger be positive polarity
        mmc.setProperty('HamamatsuHam_DCAM', 'TriggerPolarity', 'NEGATIVE');
 
        mmc.setProperty('HamamatsuHam_DCAM', 'ScanMode', 1);
        % open and set laser, 0-10 
        mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '10');
        mmc.setProperty('CSUX-Dichroic Mirror', 'State', '0');
        mmc.setProperty('CSUX-Shutter', 'State', 'Open');
        mmc.setProperty('Wheel-A', 'Label', 'Filter-6'); %red emission filter
        mmc.setProperty('AndorLaserCombiner', 'LaserPort', 'A');
end
