@ECHO OFF
setlocal EnableDelayedExpansion

rem ---------------------
rem Configure these paths
set target_path="C:\Program Files\ArcGIS\Pro\bin\Python\Scripts\proenv.bat"
rem ---------------------

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title ArcGIS Pro ArcPy Shell
    cmd /k %target_path%
)
