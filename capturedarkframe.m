function darkframes = capturedarkframe(mmc, trigger)
    W = 1900; % mmc.getImageWidth
    H = 1300;
    Z_NUM = 20; % fit to trigger
    repeat = 10;
    % begin sequenced acquitistion
	laser_power = mmc.getProperty('AndorLaserCombiner', 'PowerSetpoint561');
	%close laser
    mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', '0');
    mmc.startSequenceAcquisition(Z_NUM*repeat, 0, false);
    slice = 1;
    darkframes = zeros(W, H, Z_NUM*repeat, 'uint16');
    write(trigger, '1', 'string');
    while (mmc.getRemainingImageCount() > 0 || mmc.isSequenceRunning(mmc.getCameraDevice()))
        if slice~=(Z_NUM*repeat) && mod(slice, Z_NUM) == 0
            write(trigger, '1', 'string');
        end
        if mmc.getRemainingImageCount() > 0
            % pop image from buffer
            darkframes(:, :, slice)= uint16(reshape(mmc.popNextImage(), W, H));
            slice = slice+1;
        else
            mmc.sleep(min(.5 * 250, 20));
        end
    end
    mmc.stopSequenceAcquisition();
	mmc.setProperty('AndorLaserCombiner', 'PowerSetpoint561', laser_power);
end
