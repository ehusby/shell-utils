@ECHO OFF
setlocal EnableDelayedExpansion

rem ---------------------
rem Configure these paths
set target_path="C:\Windows\System32\bash.exe"
rem ---------------------

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title WSL Bash
    cmd /k %target_path%
)
