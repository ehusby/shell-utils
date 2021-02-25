@ECHO OFF
for /f "tokens=* USEBACKQ" %%F in (`where %1`) do (set script_abspath=%%F&goto setup_loop)

:setup_loop
set script_args=
shift
:loop1
if "%1"=="" goto after_loop
set script_args=%script_args% %1
shift
goto loop1

:after_loop
set run_cmd=python %script_abspath%%script_args%
echo %run_cmd%&echo.
%run_cmd%