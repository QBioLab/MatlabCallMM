function mmc = initialize(config)
        import mmcorej.*
        mmc= CMMCore;
        %config = 'config\MMConfig_Ti.cfg';
        mmc.loadSystemConfiguration(config);
        mmc.waitForSystem();
        mmc.setTimeoutMs(50000);
        mmc.enableDebugLog(true);
        mmc.setPrimaryLogFile('test.log');

end
