# <a name="windows_config"></a>Configuring your Windows environment
First you'll want to decide on a good home for your code repositories on your local Windows machine. The default recommendation I'd make is `C:\Users\%USERNAME%\scratch\repos`. Keep in mind that **it's extremely important your code is regularly backed up so that local changes to any repository don't exist in only one location**. Personally, I organize all of my working code repositories in [mega.io](https://mega.io/), which currently offers 50GB of free cloud storage and a robust desktop application to sync your code across multiple personal devices. If you're accustomed to keeping your code on a network drive, consider using [WinSCP's "Keep Remote Directory up to Date" function](https://winscp.net/eng/docs/task_keep_up_to_date) to continually sync changes between your local drive and the network drive. Then if the network drive becomes inaccessible for whatever reason, you can still access all of your code on your local drive.

Once you've decided on a location for your code repositories, navigate to this folder in the Git Bash shell (you may be able to right-click "Git Bash Here" while you have the folder opened in File Explorer). In the Git Bash shell, run the following command to clone the `shell-utils` repo into this folder.
```
git clone git@github.com:ehusby/shell-utils.git
```

## Quickly open current File Explorer folder in a shell
When you need to run a script via command line, you may be accustomed to opening a custom shell such as the "Anaconda Prompt" through its icon in the Start Menu, and then you type the full path of the script you want to execute along with the full path of any input or output files/folders. But it's often the case that you already have a File Explorer window open to either the script or the input/output files/folders. So instead of opening your "Anaconda Prompt", "OSGeo4W Shell", or "Cygwin64 Terminal" from the Start Menu, you can leverage the shortcuts in this repo to open these shells directly to the location you have open in File Explorer. We can call these shortcuts through the File Explorer's Address bar.

While the Address bar is typically used to change to a different location on your computer, you can also use it to execute commands (powered by Windows Command Prompt). When we take a custom script and make it executable in this way, we say that the script becomes "callable" in that shell. In order to make the shortcut scripts in this repo *callable by name* from any location on your computer, we need to add [the folder that contains the shortcut scripts](./exec) to a Windows Environment Variable named `PATH`. When a folder is listed in the `PATH` environment variable, the scripts or program files it contains (excluding subfolders) become callable by name through most Windows shells.
> **Useful tip:** Even without using the scripts in this repo, you can always open a Command Prompt window directly to the current File Explorer location by typing `cmd` in the Address bar and pressing the `[ENTER]` key.

### <a name="path_config_1"></a>Add a folder to the PATH environment variable
Access the Windows Environment Variable settings through either "Settings" or "Command Prompt" from the Start Menu.
- (On newer Windows OS versions) Start typing "environment" in the Start Menu and select "Edit the system environment variables", then click the `Environment variables...` button at the bottom of the window.
- (On older Windows OS versions) Access the main "Settings" panel through the Start Menu, then navigate:<br>
`Settings` -> `System` -> `About` (on left side, bottom) -> `Advanced system settings` (under "Related Settings", at bottom or right side) -> `Advanced` tab -> `Environment Variables...` (at bottom)

- Or in Command Prompt, run this command:<br>
`rundll32 sysdm.cpl,EditEnvironmentVariables`

In the "User variables for ___" section (top half), highlight the "Path" variable and select "Edit...". Click "New" and add the path to the [`shell-utils\windows\exec`](./exec) folder in the location where you cloned this repo on your local machine. If you have this folder open in File Explorer, the easiest way to get the path is to click in the blank space of the Address bar and the path should appear. If you followed the earlier recommendation to make `C:\Users\%USERNAME%\scratch\repos` your space for code repositories, the new path addition would be `C:\Users\%USERNAME%\scratch\repos\shell-utils\windows\exec`.

(Whatever your path is, **verify that you can navigate directly to this folder by typing it into the Address bar in File Explorer**.)

Save this change by clicking "OK" in all of the settings windows. To check that it works, open a new Command Prompt window and run `where pyexec`. If it prints out the location to the script located at `shell-utils\windows\exec\pyexec.bat` in your local copy of this repo, then your addition to the `PATH` variable was successful! If instead it prints an error message such as `INFO: Could not find files for the given pattern(s)`, then double-check that the path you added is the correct path that takes you to the [`shell-utils\windows\exec`](./exec) folder when you navigate to it in the File Explorer Address bar.

### OSGeo4W
The OSGeo4W package manager can quickly get you set up with a GDAL environment for Python scripting on Windows. You can [download OSGeo4W here](https://trac.osgeo.org/osgeo4w/). If you're going to be using Python 3 (you should as *Python 2 is now deprecated*), it's recommended you choose the "Advanced Install" method and select at least the following packages for install:
```
python3-core
python3-gdal
python3-pip
python3-setuptools
gdal-filegdb
```
By default, OSGeo4W should be installed to `C:\OSGeo4W`. If it was installed to a different location, you *may* need to change the `target_path` setting accordingly in the `start_osgeo_*` [starter scripts](./starter_scripts) listed below. (Install paths for older 64-bit and 32-bit OSGeo4W installs at `C:\OSGeo4W64` and `C:\OSGeo4W32` are also accepted without any necessary modification.)

There are several "starter commands" (shortcut scripts) you can use to fire up an OSGeo4W Shell through the File Explorer Address bar:
- [osgeo](./exec/osgeo.bat)
  <br>Identical to `osgeo-o4w`, this provides the proper configuration for users who have recently installed OSGeo4W.
- [osgeo-o4w](./exec/osgeo-o4w.bat)
  <br>Runs [`shell-utils/windows/starter_scripts/start_osgeo_o4w-env_keep-path.bat`](./starter_scripts/start_osgeo_o4w-env_keep-path.bat), which opens an OSGeo4W Shell inside the current File Explorer folder without running any additional initialization commands. **The [system `PATH` environment variable](#path_config_1) is inherited in the new shell**. If you've [added frequently-used script locations to your `PATH`](#path_config_2), they should be accessible in shells started by this starter script.
- [osgeo-py3](./exec/osgeo-py3.bat)
  <br>Runs [`shell-utils/windows/starter_scripts/start_osgeo_py3-env_keep-path.bat`](./starter_scripts/start_osgeo_py3-env_keep-path.bat). This starter script is meant for users who have an older Python2-based OSGeo4W installation where running a `py3_env` command is needed to activate a Python3 environment. This starter script is the same as `osgeo-o4w`, except that the `py3_env` command is invoked during shell startup so that Python 3 should be callable with the `python` name (provided you installed the `python3-core` package through the OSGeo4W installer).
- [osgeo-o4w-nopath](./exec/osgeo-o4w-nopath.bat)
  <br>Runs [`shell-utils/windows/starter_scripts/start_osgeo_o4w-env.bat`](./starter_scripts/start_osgeo_o4w-env.bat). Identical to `osgeo-o4w`, except the system `PATH` environment variable is not inherited in the new shell.
- [osgeo-py3-nopath](./exec/osgeo-py3-nopath.bat)
  <br>Runs [`shell-utils/windows/starter_scripts/start_osgeo_py3-env.bat`](./starter_scripts/start_osgeo_py3-env.bat). Identical to `osgeo-py3`, except the system `PATH` environment variable is not inherited in the new shell.
- [osgeo-root](./exec/osgeo-root.bat)
  <br>Runs [`shell-utils/windows/starter_scripts/start_osgeo_at-root.bat`](./starter_scripts/start_osgeo_at-root.bat), which opens an OSGeo4W Shell at the root of the OSGeo4W installation. This defeats the main purpose of the starter scripts, since it will not open the OSGeo4W in the current File Explorer folder. But if changes to OSGeo4W installations in the future break the above starter scripts break, this starter script may still work to open as OSGeo4W shell.
  
#### <a name="osgeo_py3_shortcut"></a>Getting a normal Windows shortcut for these starter commands
The first time you run a starter command such as `osgeo`, a real Windows shortcut is automatically generated in the [`shell-utils/windows/shortcuts`](./shortcuts) folder in this repo. You can then copy this shortcut into the folder containing OSGeo4W's Start Menu shortcuts at `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\OSGeo4W` to make it discoverable in the Windows Start Menu. It could be useful to copy the starter script shortcut `start_osgeo_o4w-env_keep-path.lnk` into that Start Menu shortcuts folder and rename it to "OSGeo4W Shell (keep path)", so you have quick acccess to an OSGeo4W Shell in which the system `PATH` environment variable is inherited and any [frequently-used script locations you've added to your `PATH`](#path_config_2) are immediately callable.

If you have an older installation of OSGeo4W that requires running the `py3_env` command to activate a Python3 environment, after you've run the `osgeo-py3` starter command I recommend you copy the `start_osgeo_py3-env_keep-path.lnk` shortcut into your OSGeo4W Start Menu shortcuts folder and rename it to "OSGeo4W Shell - Python3" for quick access to an OSGeo4W shell that immediately loads the Python3 environment.

### Anaconda
Anaconda is a powerful package manager for Python through which you can quickly create custom Python environments for programs that each require a specific set of Python package dependencies. I prefer to use the [Miniconda installer](https://docs.conda.io/en/latest/miniconda.html) (Python 3 version) as the main [Anaconda installer](https://www.anaconda.com/products/individual) comes bloated with many pre-installed Python packages you'll never use.

If you choose to "Install for: Just Me", then the default installation location is `C:\Users\%USERNAME%\miniconda3`. If Miniconda was installed to a different location, you will need to change the `target_path` and `starting_conda_env` settings accordingly in [`shell-utils/windows/starter_scripts/start_conda.bat`](./starter_scripts/start_conda.bat).
> **Note:** The `starting_conda_env` setting determines which Conda environment is loaded when the starter script is run. The `base` environment is loaded by default. You may want to change this if you later create a different environment that acts as a better default environment on your system. 

[`conda`](./exec/conda.bat) is the shortcut command used to start up an Anaconda Prompt through the File Explorer Address bar.

### WSL Bash
[Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/about) is pretty nifty. Who doesn't want Bash on Windows?!
[Installation instructions are here](https://docs.microsoft.com/en-us/windows/wsl/install-win10#manual-installation-steps). **I choose "WSL 1" over "WSL 2"** because [I want to be able to access all files in Windows through Bash](https://docs.microsoft.com/en-us/windows/wsl/compare-versions). When choosing a Linux distribution to install, I'd get the latest version of Ubuntu. While you're at it, I'd also [install the "new" Windows Terminal](https://docs.microsoft.com/en-us/windows/terminal/get-started) that looks nice and makes for easy switching between Command Prompt, Powershell, and your new ("Ubuntu") Bash. With the right configuration, you can run `wt` in the address bar of any File Explorer window to open Windows Terminal and its subshells directly into that folder! See the note below for proper shell profile settings.
> **Note:** Windows Terminal settings for OSGeo4W, Anaconda, WSL Bash, and Git Bash are included in this repo. Refer to [wt_settings_non-starter.json](./wt_settings_non-starter.json) for profile settings that leverage shell executable and icon files in *typical installation locations*. Refer to [wt_settings_use-starter.json](./wt_settings_use-starter.json) for profile settings that leverage the starter scripts and icon files in the shell-utils repo (recommended, but you must make sure the paths to your local copy of the shell-utils repo are correct).

Once you have WSL Bash fully installed, you can **follow the [shell-utils setup guide for Linux](../linux/README.md) to configure your Bash shell!**

[`wsl-bash`](./exec/wsl-bash.bat) is the shortcut command used to start up a Bash shell through the File Explorer Address bar.
> **Note:** While this shortcut command should be able to open a Bash shell to any location on your C drive or other **local** drives you had connected to your PC at the time you installed WSL, **mapped network drives** and removable drives (i.e. thumb drives or other USB drives) must be mounted manually in Bash before the shortcut command will work in these locations! **Use the [`mount_drive` script from the Linux part of this repo](../linux/exec/mount_drive) to permanently mount network drives in WSL Bash.**

## <a name="path_config_2"></a>Easily call frequently-used scripts from anywhere
Say you have a code repository containing a set of Python scripts that you use all the time for data processing tasks, and all of the scripts are located directly inside the repo's root directory at `C:\Users\%USERNAME%\scratch\repos\data-processing-tools`. If these scripts have distinct filenames, it would be handy if we could run them from any shell by simply typing *the filename of the script*, without needing to type the whole `C:\Users\%USERNAME%\scratch\repos\data-processing-tools` directory prefix. We can make these scripts callable by name from any location on your computer by simply [adding that directory path to the system-wide `PATH` environment variable](#path_config_1).
> **Note:** Changes to Windows Environment Variable settings are only applied in *new shells* opened after the changes have been saved.

After adding a script folder to the PATH environment variable, you can test that this worked by opening a new Command Prompt window and running the command `where <filename-of-script>`. If one of the files in this folder is a Python script named `my_tool.py`, that command would be `where my_tool.py`.

Normally, to run a Python script in a shell you invoke a command like `python <long-path-to-script-file> [script arguments]`. But if you have multiple versions of Python installed on your computer, how does it know which one to use when you called `python`? This is determined by the configuration of the particular shell you're using (typically through the shell's own copy of the `PATH` variable). You can check the location of the currently-callable Python program in a Windows shell by running `where python`. (We will go over [how to change the system-wide default Python program](#set_system_default_python) in the next section.)

When you want to call a Python script that is on the `PATH` from a different folder, such as `my_tool.py` from the above example, **the following command won't work:**
```
python my_tool.py
```
This is because the `PATH` variable typically only helps the shell locate the *parent program* (the one listed first) run by a command. In the case of `python my_tool.py`, the parent program is `python`. Once control is passed to Python, it tries to run a script named `my_tool.py`. But since Python won't (normally) use the `PATH` variable when looking for `my_tool.py`, it fails to find the script and immediately exits with a `No such file or directory` error message.

In order to call a Python script that is on the `PATH`, you have two options. The first option is to try running the script directly with the command `my_tool.py`. When you run a Python script directly in this manner, the system default Python program will be used. If this fails, see the next section on [how to configure the system default Python program](#set_system_default_python).

The more careful and correct way to call a Python script that is on the `PATH` is to use the [`pyexec`](./exec/pyexec.bat) wrapper script from this repo. When you run `pyexec my_tool.py`, this wrapper script will search the `PATH` variable for the full path to your `my_tool.py` script and then automatically call `python <full-path-to>\my_tool.py`. It will also forward any arguments you provide in your command following `my_tool.py`. So when you want to call your script by name, run the following command in your shell:
```
pyexec my_tool.py [script arguments]
```
The reason why running `pyexec my_tool.py` is safer than simply running `my_tool.py` is that the Python environment that exists in your shell (OSGeo4W, Anaconda, Bash, etc.) can and will be different from the environment of the system default Python program. Often they will differ for important reasons, and the `my_tool.py` script may even be unable to run with the system default Python. By running with [`pyexec`](./exec/pyexec.bat), you can be confident that it's the Python version currently available in your shell (callable by the `python` command) that is used when you run `pyexec my_tool.py`.

## <a name="set_system_default_python"></a>Set the system-wide default Python program

When you try to execute a `.py` Python script directly by either double-clicking on it in File Explorer or running `.\my_script.py` in a shell (without the `python` prefix), Windows will try to use the system default Python program to run your script. This is most concisely configured through the Windows *Registry Editor* (aka "regedit") program, but you should be able to set this easily through File Explorer. If you experience issues, you may need to [configure the system default Python through the registry](#set_system_default_python_registry) instead.

We'll test this setup process using the [`check_python_location.py`](https://github.com/ehusby/CLIP/blob/master/check_python_location.py) Python script in [the `CLIP` repo](https://github.com/ehusby/CLIP). `CLIP` contains handy scripts you can double-click run to quickly modify the contents of your clipboard. After you have the repo accessible on your local machine, do the following:
1. Right-click on the `CLIP\check_python_location.py` file in File Explorer and select "Open with -> Choose another app".
2. Check the box at the bottom that says "Always use this app to open .py files".
3. Scroll down and select "More apps ↓", then scroll down to the bottom again and select "Look for another app on this PC".
4. Navigate to the location where you cloned this `shell-utils` repo on your local machine. Then navigate deeper into the [`shell-utils\windows\open_with_scripts`](./open_with_scripts) folder.
5. Select the particular `run_pyscript_*.bat` script that will run the Python install you wish to run when you double-click execute `*.py` Python scripts through File Explorer.
   - If you primarily use the OSGeo4W Python to run Python scripts, select [`run_pyscript_osgeo.bat`](./open_with_scripts/run_pyscript_osgeo.bat), or select [`run_pyscript_osgeo_py3-env.bat`](./open_with_scripts/run_pyscript_osgeo_py3-env.bat) if you have an older OSGeo4W install that requires running the `py3_env` command to activate the Python3 environment.
   - If you primarily use an Anaconda Python enviornment, and have installed Anaconda in one of the default locations, select [`run_pyscript_conda.bat`](./open_with_scripts/run_pyscript_conda.bat) and it will run `*.py` scripts with the Python install in your "base" Conda environment. If you want to have it a different Conda environment's Python install, follow the example of the [`run_pyscript_conda_pgc.bat`](./open_with_scripts/run_pyscript_conda_pgc.bat) script that calls a slightly modified [`shell-utils/starter_scripts/start_conda_pgc.bat`](./starter_scripts/start_conda_pgc.bat) script to load a custom Conda environment named "pgc" (see the "Configure these paths" section at the top of the [`start_conda_pgc.bat`](./starter_scripts/start_conda_pgc.bat) script).
6. Once you've made your selection, click "Open".
7. If you have any issues selecting a `run_pyscript_*.bat` script, you can try the next step to select a Python executable directly. Otherwise, skip the next step. From my experience, this method of setting up double-click `*.py` script execution usually fails in inconsistent ways for reasons I do not know.
8. Navigate to the location of the Python executable you want to be the system default, and select it. 
   - To make the OSGeo4W Python install the system default Python program, navigate to `C:\OSGeo4W\apps\Python39` and select the "python"(.exe) file in that folder.
   - If you're unsure where the Python executable is located, open the shell program through which you can call `python` (such as Anaconda Prompt), and run the command `where python` to determine its location.
> **Note on Windows bug:** When using the above "Open with" method to change the system-wide default Python program, you may need to temporarily rename/move the current default `*.py` "Open" application file for Windows to accept the new default. **Don't forget to undo your rename/move of that file once the new default has been set successfully!!** The first time you change the default, the application file you need to rename/move is most likely a `python.exe` file in the current default Python's install location (locate by running `where python` in the shell program through which you can call `python`). If you have already changed the default using the above steps, the file to rename/move would be the `shell-utils/windows/open_with_scripts/run_pyscript_*.bat` file you previously set through the above steps. 

The `check_python_location.py` script should now run with the Python executable you selected, and a terminal window should open verifying the location of that `python.exe` file. Close that terminal window and now try double-click running the `check_python_location.py` file. If the `.py` file association is set correctly, the terminal window should appear again showing the same Python executable location you selected. If instead you see a terminal window quickly appear and then disappear, a different program opens, or *the Python executable location is not what you set it to a moment ago*, then try [configuring this through the registry](#set_system_default_python_registry) instead.

Now try running one of the other `.py` Python scripts in the root folder of the `CLIP` repo, such as [`ITEMS__LINE__to__SPACE.py`](https://github.com/ehusby/CLIP/blob/master/ITEMS__LINE__to__SPACE.py). It should complain that you need to install the `pyperclip` Python package. For OSGeo4W users, you can install this package by opening the OSGeo4W shell and running the command `pip install pyperclip` to install it.

I like to have the CLIP folder quickly accessible in File Explorer through the "Quick access" panel. Right-click on the CLIP folder and select "Pin to Quick access" to do that. By default, the Quick access panel includes recently-used files and folders. If you don't care for that, you can right-click on "Quick access -> Options" and uncheck the "Show recently used files in Quick access" and "Show frequently used folders in Quick access" options.

### <a name="set_system_default_python_registry"></a>Setting the system default Python through the registry (last resort)

If you're having issues setting the system default Python program through File Explorer, try following these steps to configure this through the registry. Open the Windows Registry Editor by typing "regedit" in the Start Menu.

The registry key to you need to add/edit is called:
```
HKEY_CLASSES_ROOT\Python.File\shell\open\command
```
To make the OSGeo4W Python install the system default Python program, this registry key should be of Type=`REG_SZ` with Data=`"C:\OSGeo4W\apps\Python39\python.exe" "%1" %*`.

**If you'd rather not configure this yourself,** in Registry Editor you can `File` -> `Import...` one of the pre-made registry keys included in this repo from [`shell-utils/windows/registry`](./registry) named `open_py-files_with_*.reg`. **Or equivalently, you can double-click on one of these `.reg` files to install the registry key directly from File Explorer.**

After you've installed the new registry key, try double-click running the [`check_python_location.py`](https://github.com/ehusby/CLIP/blob/master/check_python_location.py) Python script in the in [the `CLIP` repo](https://github.com/ehusby/CLIP). If the `.py` file association is set correctly, a terminal window should open showing the location of the `python.exe` executable you set with the registry key. If instead you see a terminal window quickly appear and then disappear, a different program opens, or *the Python executable location is not what you set in the registry key*, then continue on to next steps:

- Sometimes you need to restart Windows Explorer for the change to take effect. Open up the Task Manager program (keyboard shortcut `CTRL+SHIFT+ESC`, helpful to remember if your computer ever freezes). In the "Processes" tab under "Apps", right-click on "Windows Explorer -> Restart". Note that all open File Explorer windows you have will be closed.

- If `check_python_location.py` is still not reporting the proper Python executable location, this is likely due to some extra registry keys from a program previously associated with the `.py` file extension (such as PyCharm). To remove the unwanted registry keys, **right-click on [the `reset_py-file_association.bat` file](./registry/reset_py-file_association.bat) in `shell-utils/windows/registry` in File Explorer and select "Run as administrator"**. The script may report "ERROR: The system was unable to find the specified registry key or value." for some of the registry delete commands, but that is normal.
  - Now that the `.py` file associations have been reset, **you will need to setup/import the registry key at `HKEY_CLASSES_ROOT\Python.File\shell\open\command` again**. You might want to use one of the pre-made `open_py-files_with_*.reg` registry keys in [`shell-utils/windows/registry`](./registry).
