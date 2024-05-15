In order to accurately stitch together images from multiple XY positions, μMagellan must be
calibrated to determine the affine transformation matrix that relates image pixel coordinates to
those of the XY stage. This calibration must be performed separately for each pixel size setting
defined within μManager. The “Calibrate” button on the bottom right corner of the μMagellan
GUI provides manual and automatic means of doing so. The automatic method prompts user’s
to take three images, moving the XY stage to a different location for each one, then calculates
the cross-correlation of these images relative to one another in order to calculate the entries of
the affine transform. The manual method allows user’s to input specific values for rotation,
shear, x scale, and y scale, and is particularly useful for making small adjustments if an
automatic calibration is slightly off. This can be easily accomplished by making adjustments,
pressing apply, running a 2x2 field of view acquisition to determine how fields of view are
aligned, and repeatin.


## Reference
1. https://www.bilibili.com/video/BV12u411G71A
2. https://www.bilibili.com/video/BV19z4y197cf
