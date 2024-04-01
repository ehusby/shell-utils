@ECHO OFF
setlocal EnableDelayedExpansion

rem ---------------------
rem Configure these paths
set target_path="C:\Users\%USERNAME%\Miniconda3\Scripts\activate.bat"
set starting_conda_env=C:\Users\%USERNAME%\Miniconda3
if exist "C:\Users\%USERNAME%\AppData\Local\miniforge3" (
    set target_path="C:\Users\%USERNAME%\AppData\Local\miniforge3\Scripts\activate.bat"
    set starting_conda_env=C:\Users\%USERNAME%\AppData\Local\miniforge3
) else if exist "C:\Users\%USERNAME%\Miniconda3\" (
    set target_path="C:\Users\%USERNAME%\Miniconda3\Scripts\activate.bat"
    set starting_conda_env=C:\Users\%USERNAME%\Miniconda3
) else if exist "C:\Users\%USERNAME%\miniconda3\" (
    set target_path="C:\Users\%USERNAME%\miniconda3\Scripts\activate.bat"
    set starting_conda_env=C:\Users\%USERNAME%\miniconda3
) else if exist "C:\ProgramData\Miniconda3\" (
    set target_path="C:\ProgramData\Miniconda3\Scripts\activate.bat"
    set starting_conda_env=C:\ProgramData\Miniconda3
) else if exist "C:\ProgramData\miniconda3\" (
    set target_path="C:\ProgramData\miniconda3\Scripts\activate.bat"
    set starting_conda_env=C:\ProgramData\miniconda3
) else if exist "C:\Users\%USERNAME%\AppData\Local\Miniconda3\" (
    set target_path="C:\Users\%USERNAME%\AppData\Local\Miniconda3\Scripts\activate.bat"
    set starting_conda_env=C:\Users\%USERNAME%\AppData\Local\Miniconda3
) else if exist "C:\Users\%USERNAME%\AppData\Local\miniconda3\" (
    set target_path="C:\Users\%USERNAME%\AppData\Local\miniconda3\Scripts\activate.bat"
    set starting_conda_env=C:\Users\%USERNAME%\AppData\Local\miniconda3
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
    title Anaconda Prompt
    if "%run_mode%" == "shell" (
        cmd /k %target_path% %starting_conda_env%
    ) else if "%run_mode%" == "pyscript" (
        if "%SHELL_UTILS_START_PYSCRIPT_KEEP_OPEN%" == "true" (
            call %target_path% %starting_conda_env% & cmd /k "python %*"
        ) else (
            call %target_path% %starting_conda_env% & cmd /c "python %*"
        )
    )
)
