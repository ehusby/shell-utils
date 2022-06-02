@ECHO OFF
setlocal EnableDelayedExpansion

rem ---------------------
rem Configure these paths
if exist "C:\OSGeo4W64\" (
    set target_path="C:\OSGeo4W64\bin\o4w_env.bat"
) else if exist "C:\OSGeo4W32\" (
    set target_path="C:\OSGeo4W32\bin\o4w_env.bat"
) else (
    set target_path="C:\OSGeo4W\bin\o4w_env.bat"
)
rem ---------------------

if "%~1" == "" (
    set run_mode=shell
) else (
    set run_mode=pyscript
    set pyscript=%~1
    echo !pyscript! | findstr /r "^.*\\CLIP\\[^\\]*.*\.py" > nul
    if "!errorlevel!" == "0" (
        set SHELL_UTILS_START_PYSCRIPT_KEEP_OPEN=false
    )
)

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title OSGeo4W Shell [o4w_env]
    if "%run_mode%" == "shell" (
        call %target_path% & cmd /k "@ECHO OFF&set PATH=%%PATH%%;%PATH%;&@ECHO ON&echo run o-help for a list of available commands"
    ) else if "%run_mode%" == "pyscript" (
        if "%SHELL_UTILS_START_PYSCRIPT_KEEP_OPEN%" == "true" (
            call %target_path% & cmd /k "@ECHO OFF&set PATH=%%PATH%%;%PATH%;&@ECHO ON&python %*"
        ) else (
            call %target_path% & cmd /c "@ECHO OFF&set PATH=%%PATH%%;%PATH%;&@ECHO ON&python %*"
        )
    )
)
