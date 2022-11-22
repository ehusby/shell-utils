@ECHO OFF
setlocal EnableDelayedExpansion

rem ---------------------
rem Configure these paths
set target_path="C:\Program Files\ArcGIS\Pro\bin\Python\Scripts\proenv.bat"
set shortcut_path="C:\ProgramData\Microsoft\Windows\Start Menu\Programs\ArcGIS Pro ArcPy Shell.lnk"
rem ---------------------

set shortcut_path_rel=..\icons\arcpro.ico
call :ResolvePath shortcut_path_abs %shortcut_path_rel%

if exist %shortcut_path% (
    @ECHO ON
    echo Deleting existing shortcut: %shortcut_path%
)
@ECHO OFF

call %~dp0..\lib\create_script_shortcut.vbs %target_path% %shortcut_path% %shortcut_path_abs%

if exist %shortcut_path% (
    @ECHO ON
    echo Shortcut was created: %shortcut_path%
) else (
    @ECHO ON
    echo Could not create shortcut at: %shortcut_path%
)
@ECHO OFF

pause

rem === Functions ===
rem Taken from SO answer: https://stackoverflow.com/a/46619655/8896374

rem Resolve path to absolute.
rem Param 1: Name of output variable.
rem Param 2: Path to resolve.
rem Return: Resolved absolute path.
:ResolvePath
    set %1=%~dpfn2
    exit /b