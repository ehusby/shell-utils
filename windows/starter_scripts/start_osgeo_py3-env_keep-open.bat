@ECHO OFF
set script_name=start_osgeo_py3-env_keep-path
set SHELL_UTILS_START_PYSCRIPT_KEEP_OPEN=true
call %~dp0\%script_name%.bat "%*"
