reg.exe delete "HKEY_CLASSES_ROOT\.py" /f
reg.exe delete "HKEY_CLASSES_ROOT\Python.File\shell\open\command" /f
reg.exe delete "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.py\OpenWithProgids" /f
reg.exe delete "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.py\UserChoice" /f
reg.exe import "%~dp0\add_py-file_shell_association.reg"

@ECHO OFF
echo.
set /p=Press [ENTER] to exit
