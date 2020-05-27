function mmc = initialize(config)
        import mmcorej.*
        mmc= CMMCore;
        %config = 'config\MMConfig_Ti.cfg';
        %config = 'C:\users\qblab\Documents\MMConfig_Ti.cfg';
        mmc.loadSystemConfiguration(config);
        mmc.waitForSystem();
        mmc.setTimeoutMs(50000);
        %mmc.enableDebugLog(true);
        %mmc.setPrimaryLogFile('test.log');
        mmc.setProperty('Andor sCMOS Camera', 'Sensitivity/DynamicRange', '16-bit (low noise & high well capacity)'); 
        % Set to 16bit
        mmc.getProperty('Andor sCMOS Camera', 'AuxiliaryOutSource (TTL I/O)');
end
