# Matlab Call Micro-Manager for Spinning Disk Confocal Microscope

## Setting Matlab and Micro-Manager
We almost follow [Micro-Manager wiki](https://micro-manager.org/wiki/Matlab_Configuration).

We tested on Matlab2017b and Micro-Manager 2.0-gamma(2020525). but should work
on other version.

1. Install Micro-Manager and Andor Driver(just for andor camera) in same folder
2. Add all MM jar files into Matlab classpath.txt by running:
```matlab
cd C:\Program Files\Micro-Manager-2.0gamma
StartMMStudio('-setup')
```
3. Run `edit librarypath.txt` in Matlab command prompt. Append the location of
the dll files
`C:/Program Files/Micro-Manager-2.0gamma` in opening file.
4. Add the location of the dll files to the system path. This is not required
for all device drivers but is required to access the Andor driver. For example,
append `C:\Program Files\Micro-Manager-2.0gamma` to system environment `PATH` or
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

##  Experiment work flow

## TODO
1. turn off autoshutter
2. Do PFS each time for different position

## Reference
1. https://valelab4.ucsf.edu/~MM/doc-2.0.0-gamma/mmcorej/mmcorej/CMMCore.html
