@ECHO OFF
set script_name=start_conda
set SHELL_UTILS_START_PYSCRIPT_KEEP_OPEN=true
call %~dp0..\starter_scripts\%script_name%.bat "%*"
