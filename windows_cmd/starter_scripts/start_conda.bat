@ECHO OFF

rem ---------------------
rem Configure these paths
set target_path="C:\Users\%USERNAME%\miniconda3\Scripts\activate.bat"
set starting_conda_env=C:\Users\%USERNAME%\miniconda3
rem ---------------------

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title Anaconda Prompt
    cmd /k %target_path% %starting_conda_env%
)
