@ECHO OFF

rem ---------------------
rem Configure these paths
set target_path="C:\Users\%USERNAME%\miniconda3\Scripts\activate.bat"
set starting_conda_env=C:\Users\%USERNAME%\miniconda3\envs\clip
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
    title Anaconda Prompt [CLIP]
    if "%run_mode%" == "shell" (
        cmd /k %target_path% %starting_conda_env%
    ) else if "%run_mode%" == "pyscript" (
        call %target_path% %starting_conda_env% & cmd /c "python %*"
    )
)
