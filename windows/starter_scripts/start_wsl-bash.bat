@ECHO OFF
setlocal EnableDelayedExpansion

rem ---------------------
rem Configure these paths
set target_path="C:\Windows\System32\bash.exe"
if exist "C:\Users\Erik\AppData\Local\Microsoft\WindowsApps\bash.exe" (
    set target_path="C:\Users\Erik\AppData\Local\Microsoft\WindowsApps\bash.exe"
)
rem ---------------------

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title WSL Bash
    cmd /k %target_path%
)
