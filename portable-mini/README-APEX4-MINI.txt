ApexSenseBridge - APEX 4 Mini Portable
=======================================

This package is the minimal APEX 4 build. It contains only the native bridge,
the integrated virtual DualSense backend, launch helpers, and required notices.

Requirements
------------

1. Windows 10/11 x64.
2. Flydigi Space Station installed and running.
3. APEX 4 connected in XInput mode.
4. A working usbip-win2 driver already installed. This Mini package does not
   install or modify kernel drivers.

Usage
-----

Run Start-APEX4-Mini.cmd, then start the game. The bridge reads the physical
XInput controller, creates a virtual DualSense, receives native DualSense
adaptive-trigger output from the game, and forwards it to Flydigi Space
Station at 127.0.0.1:7878.

Press Ctrl+C in the bridge window to stop. Stop-APEX4-Mini.cmd can also request
a clean shutdown. Both paths restore LT and RT to Normal.

This package intentionally excludes Playnite integration, the tray and control
panel applications, HidHide, offline driver installers, and the VIIPER sidecar.
Grip-rumble/audio-haptics routing is not available in APEX 4 Space Station mode.
