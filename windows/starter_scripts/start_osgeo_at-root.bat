@ECHO OFF
setlocal EnableDelayedExpansion

rem ---------------------
rem Configure these paths
if exist "C:\OSGeo4W64\" (
    set target_path="C:\OSGeo4W64\OSGeo4W.bat"
) else if exist "C:\OSGeo4W32\" (
    set target_path="C:\OSGeo4W32\OSGeo4W.bat"
) else (
    set target_path="C:\OSGeo4W\OSGeo4W.bat"
)
rem ---------------------

if "%~1" == "" (
    set run_mode=shell
) else (
    set run_mode=pyscript
)

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title OSGeo4W Shell [root]
    if "%run_mode%" == "shell" (
        call %target_path%
    ) else if "%run_mode%" == "pyscript" (
        call %target_path% python %*
    )
)
