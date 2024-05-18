# Matlab Call Micro-Manager

## Setting Matlab and Micro-Manager
We almost follow [Micro-Manager wiki](https://micro-manager.org/wiki/Matlab_Configuration).

We tested on Matlab(2017b, 2020) and Micro-Manager 2.0(20240513), but should work
on other version.

1. Install Micro-Manager and Andor Driver(just for andor camera) in same folder
2. Add all MM jar files into Matlab classpath.txt by running:
```matlab
cd C:\Program Files\Micro-Manager-2.0
StartMMStudio('-setup')
```
3. Run `edit librarypath.txt` in Matlab command prompt. Append the location of
the dll files
`C:/Program Files/Micro-Manager-2.0` in opening file.
4. Add the location of the dll files to the system path. This is not required
for all device drivers but is required to access the Andor driver. For example,
append `C:\Program Files\Micro-Manager-2.0` to system environment `PATH` or
`Path`
5. Restart Matlab and computer(I don't know whether it is required to refresh
System environment)
6. Test with simple code:
```matlab
>> import mmcorej.*;
>> mmc = CMMCore;
>> mmc.load('C:\user\qblab\documents\MMConfig_Ti.cfg')
```

We once troubled to load Andor driver:
```matlab

```
Typically, in this case, Micro-Manager fail to find other Andor dll files inside
current Matlab working directory. If you just change current working directory
to Micro-Manager installation directory, Andor driver could be loaded normally.
For permanent setting, you should check step 4.

IMPORTANT NOTE:
If camera set to 16 bit, `mmc.getImage()` will returen a 1D array of signed
integers in row-major order in Matlab, we must interpreted it as unsigned integers.
```matlab
>> mmc.snapImage();
>> img = mmc.getImage();  % returned as a 1D array of signed integers in row-major order
>> width = mmc.getImageWidth();
>> height = mmc.getImageHeight();
>> if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end
>> img = typecast(img, pixelType);      % pixels must be interpreted as unsigned integers
>> img = reshape(img, [width, height]); % image should be interpreted as a 2D array
>> img = transpose(img);                % make column-major order for MATLAB
>> imshow(img);
```

