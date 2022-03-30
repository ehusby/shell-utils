@ECHO OFF
set script_name=start_clip
set SHELL_UTILS_START_PYSCRIPT_KEEP_OPEN=true
call %~dp0..\starter_scripts\%script_name%.bat "%*"
