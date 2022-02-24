@ECHO OFF

rem ---------------------
rem Configure these paths
if exist "C:\OSGeo4W64\" (
    set target_path="C:\OSGeo4W64\bin\o4w_env.bat"
    set "try_py3_env=true"
) else if exist "C:\OSGeo4W32\" (
    set target_path="C:\OSGeo4W32\bin\o4w_env.bat"
    set "try_py3_env=true"
) else (
    set target_path="C:\OSGeo4W\bin\o4w_env.bat"
    set "try_py3_env=false"
)
rem ---------------------

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else if "%try_py3_env%" == "true" (
    title OSGeo4W Shell - Python3 [py3_env]
    rem call "%target_path%" & cmd /k "py3_env&echo.&echo 'py3_env' has been loaded. 'python' and 'python3' commands should now use the Python3 environment.&echo run o-help for a list of available commands"
    call %target_path% & cmd /k "@ECHO OFF&set PATH=%%PATH%%;%PATH%;&py3_env&@ECHO ON&echo 'py3_env' has been loaded. 'python' and 'python3' commands should now use the Python3 environment.&echo run o-help for a list of available commands"
) else (
    title OSGeo4W Shell - Python3
    call %target_path% & cmd /k "@ECHO OFF&set PATH=%%PATH%%;%PATH%;&@ECHO ON"
)
