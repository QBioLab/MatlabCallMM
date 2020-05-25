# Setting up Matlab and Micromanager

```matlab
cd C:\Program Files\Micro-Manager-2.0gamma
StartMMStudio('-setup')
edit librarypath.txt
C:/Program Files/Micro-Manager-2.0gamma
Add the location of the dll files to the system path. This is not required for all device drivers but is required to access the Andor driver on a Windows 7 system. 

```

Ref: https://micro-manager.org/wiki/Matlab_Configuration
