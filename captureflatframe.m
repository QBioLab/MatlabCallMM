function flatframes = captureflatframe(mmc, trigger)
    W = 1900; % mmc.getImageWidth
    H = 1300;
    Z_NUM = 20; % fit to trigger
    repeat = 10;
    % begin sequenced acquitistion
	laser_power = mmc.getProperty('AndorLaserCombiner', 'PowerSetpoint561');
    cam_exposure = mmc.getExposure();
    mmc.setExposure(1000);
	%close laser
    mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '10');
    mmc.startSequenceAcquisition(Z_NUM*repeat, 0, false);
    slice = 1;
    flatframes = zeros(W, H, Z_NUM*repeat, 'uint16');
    write(trigger, '1', 'string');
    while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
        if slice~=(Z_NUM*repeat) && mod(slice, Z_NUM) == 0
            write(trigger, '1', 'string');
        end
        if mmc.getRemainingImageCount() > 0
            % pop image from buffer
            flatframes(:, :, slice)= uint16(reshape(mmc.popNextImage(), W, H));
            slice = slice+1;
        else
            mmc.sleep(min(.5 * 250, 20));
        end
    end
    mmc.stopSequenceAcquisition();
	mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', laser_power);
    mmc.setExposure(cam_exposure);
end