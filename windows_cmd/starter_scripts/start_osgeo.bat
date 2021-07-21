@ECHO OFF

rem ---------------------
rem Configure these paths
set target_path="C:\OSGeo4W64\OSGeo4W.bat"
rem ---------------------

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title OSGeo4W Shell
    cmd /k %target_path%
)
