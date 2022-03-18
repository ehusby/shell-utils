@ECHO OFF

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

if not exist %target_path% (
    title ERROR
    cmd /k "echo Target does not exist: %target_path%&echo.&echo Configure paths in this script: %0"
) else (
    title OSGeo4W Shell - Python2
    call %target_path% & cmd /k "@ECHO OFF&set PATH=%%PATH%%;%PATH%;&@ECHO ON&echo run o-help for a list of available commands"
)
