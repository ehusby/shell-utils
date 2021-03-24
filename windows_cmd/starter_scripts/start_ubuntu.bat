@ECHO OFF

rem ---------------------
rem Configure these paths
set target_path=C:\Users\%USERNAME%\AppData\Local\Microsoft\WindowsApps\ubuntu.exe
rem ---------------------

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: "%target_path%"&echo.&echo Configure paths in this script: %0"
) else (
    title Ubuntu
    cmd /k %target_path%
)
