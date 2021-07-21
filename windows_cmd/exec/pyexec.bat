@ECHO OFF
SETLOCAL EnableDelayedExpansion

set no_script=
set script_path=
if "%1"=="" (
    set no_script=true
    goto after_loop
) else (
    set no_script=false
    for /f "tokens=* USEBACKQ" %%F in (`where %1`) do (set script_path=%%F&goto setup_loop)
    if "!script_path!"=="" (
        goto after_loop
    )
)

:setup_loop
set script_args=
shift
:loop1
if "%1"=="" goto after_loop
set script_args=%script_args% %1
shift
goto loop1

:after_loop
if "%no_script%"=="true" (
    python
) else if not "%script_path%"=="" (
    set run_cmd=python %script_path%%script_args%
    echo !run_cmd!&echo.
    !run_cmd!
)
