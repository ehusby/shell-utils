@ECHO OFF
set script_name=start_osgeo
set icon_name=osgeo
call %~dp0..\lib\create_starter_shortcut.vbs %script_name% %icon_name%
start %~dp0..\shortcuts\%script_name%.lnk