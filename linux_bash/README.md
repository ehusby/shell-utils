## <a name="shell_config"></a>Setting up your Bash shell
Since the home directory (`$HOME`, aka `~/`) can get often get cluttered by processes outside of your control, I recommend keeping most of your activity within a "scratch" folder that we'll place in your home directory. The repos you clone can be neatly kept within a "repos" folder within your scratch space.

Run the following commands to set up your scratch space and clone the `shell-utils` repo into your new repos folder.
```
mkdir -p ~/scratch/repos
cd ~/scratch/repos
git clone git@github.com:ehusby/shell-utils.git
```

### <a name="shell_config_files"></a>`.bashrc`, `.screenrc`,  and other shell config files
- The [`.bashrc`](./config/.bashrc_standalone) file contains shell commands that are run every time you open a new Bash shell. It is executed when you open a new Terminal/Bash window, when you SSH into a remote machine you interface with using Bash, and every time you open up a new tab in the `screen` program.
- The [`.screenrc`](./config/.screenrc) file contains a nice set of configuration settings for the standard Linux `screen` program. I won't cover much on `screen` here, but I highly recommend using it when you plan to do real long-running work in the terminal.
- The [`.inputrc`](./config/.inputrc) file contains important keybindings that make sure keys like HOME and END function as expected on older Linux systems.

Before proceeding, I **strongly** suggest you familiarize yourself with the contents of [`.bashrc_standalone`](./config/.bashrc_standalone) in particular. The main purpose of this setup is to allow you to leverage the custom settings and Bash functions made available in this script.

Next we're going to go down one of two routes...

### Option 1: Safer and clearer for work on a single system
Copy the config files into your home directory. Check if either of the `~/.screenrc` or `~/.inputrc` files already exist before running the following commands. If they do, you should consider [**Option 3**](#shell_config_opt3) for those two files.
```
cp ~/scratch/repos/shell-utils/linux_bash/config/.* ~/
mv ~/.bashrc ~/.bashrc_system_default
mv ~/.bashrc_standalone ~/.bashrc
```
**The last two `mv` commands allow the system default `~/.bashrc` file to continue to exist and to continue to be used by the shell.** Both the [`.bashrc_standalone`](./config/.bashrc_standalone) and [`.bashrc_integrated`](./config/.bashrc_integrated) scripts in this repo will check if a file named `~/.bashrc_system_default` exists on your system, and then will `source` that script as the _first_ thing it does. Note that any operations performed by these scripts after sourcing `~/.bashrc_system_default` may override system default settings, so **I strongly advise looking over both your existing (system default) `~/.bashrc` file and [`.bashrc_standalone`](./config/.bashrc_standalone) before you commit to these actions!**

### Option 2: More easily updatable for work on multiple systems
Copying the config files into your home directory, as done in Option 1, will dissociate those files from your local `shell-utils` GitHub repo. This means that if you want to commit and track changes to these files, or update them by pulling changes from GitHub, you will need to manually perform steps like those in Option 1 every time, shuffling these files around on every system you work on. And if you've made changes to those files in your home directory on those systems, you would also need to manage those changes manually.

Instead of copying the config files, we can _symlink_ these files into your home directory. The "symbolic link" files you create in your home directory will function similar to Windows Shortcuts, which "point" to the real files that continue to exist in your local `shell-utils` repo. Any changes you make to these symlink files will also be reflected in the files within the repo, and vice versa when you use `git` to update the files in the repo.
```
shell_utils_abspath=$(readlink -f ~/scratch/repos/shell-utils)
find "${shell_utils_abspath}/linux_bash/config/" -mindepth 1 -maxdepth 1 -exec ln -s {} ~/ \;
mv ~/.bashrc ~/.bashrc_system_default
mv ~/.bashrc_integrated ~/.bashrc
```
If you're only working on a single system and prefer seeing all of the custom functions made available in your `.bashrc` at a glance, while keeping the `.bashrc` updatable, you can instead symlink the `.bashrc_standalone` file. To do that instead, just change the last command to:
```
mv ~/.bashrc_standalone ~/.bashrc
```

### <a name="shell_config_opt3"></a>Option 3: Copy and paste only what you want
Did I mention there's a third option? You can always just copy & paste what you want from [`.bashrc_standalone`](./config/.bashrc_standalone) straight into your existing `~/.bashrc` file (same with the [`.screenrc`](./config/.screenrc) and [`.inputrc`](./config/.inputrc) files). It can be that easy. This approach, similar to Option 1, is OK if you're working on a single system, and you only have a single set of configuration files to manage. You may even be able to handle this copy & paste routine on multiple systems for some time... until you go to add an awesome new function to your `.bashrc` and later realize you forgot to update the other 10 `.bashrc` files you have on every system you use, files which are all slightly different.

At a bare minimum, you can add the following lines to your existing `~/.bashrc` file to utilize the custom Bash functions made available in this repo:
```
export PATH="${PATH}:<path-to>/shell-utils/linux_bash/exec"  # Easily call shell-utils executable scripts
source "<path-to>/shell-utils/linux_bash/lib/bash_shell_func.sh"  # Source general purpose shell functions
```
These lines should be modified as instructed in the next section.

### Final `.bashrc` setup
Regardless of the option you chose, you ought to make some final adjustments to your new `.bashrc` file.
There is a section of the file that is dedicated to system-specific settings, which looks like this:
```
################################
### System-specific settings ###
################################

## Exports (PATH changes and global vars)
# >>> FILL OUT OR COMMENT OUT THE FOLLOWING LINES <<< #
SHELL_UTILS_PATH="<path-to>/shell-utils"  # Necessary for sourcing general purpose shell functions
export MY_EMAIL="<your-email-address>"  # Necessary for shell-utils 'email_me' script
export PATH="${PATH}:${SHELL_UTILS_PATH}/linux_bash/exec"  # Easily call shell-utils executable scripts
#export PATH="${PATH}:<path-to>/pyscript-utils"  # Easily call pyscript-utils executable scripts
```
- Replace `<path-to>/shell-utils` with the absolute path to the `shell-utils` folder on your local machine. If you've set up your repos folder as instructed in this guide, you can replace this line with the following:
```
SHELL_UTILS_PATH="${HOME}/scratch/repos/shell-utils"
```
- If your Linux system has a working email server that supports sending email using the standard Linux `mail` command, replace `<your-email-address>` with the email address you would like to be notified at when using the `shell-utils` [`email_me`](./exec/email_me) command wrapper. If your system doesn't support the `mail` command, or you'd rather not fill this in, then you should "comment out" this line by adding a "#" character at the beginning of the line.

### Reload your new `.bashrc` file
Changes to the `.bashrc` will take effect when you [start a new Bash shell](#shell_config_files), but are not automatically applied to any shells that are already running. To apply changes from your new `.bashrc` file in your current shell, run the following command:
```
source ~/.bashrc
```

## Leveraging the [`exec`](./exec)utable `shell-utils` scripts

As hinted in [Option 3](#shell_config_opt3) of [Setting up your Bash shell](#shell_config), the line in the `.bashrc` that adds the [`exec`](./exec) folder to your Bash `PATH` environment variable is a handy one. This allows you to _call the programs in that folder by name_ from the terminal at any time, from any directory. Example:
```
$ email_me -h
Usage: email_me [-{email output option:o|e|q}] run_command (can be quoted to perform multiline commands such as for/while loop)
 Email output option detrmines which text streams are recorded in the email body:
  -o : stdout only (stdout and stderr are printed to terminal during run command as usual)
  -e : stderr only (stderr is captured and printed to terminal at end of run command)
  -q : no output   (stdout and stderr are printed to terminal during run command as usual)
  (if no option is given, both stdout and stderr are included in email body text)
```
However, this will only work if the files in that folder have the _executable bit_ set in their permission settings. I try to make GitHub keep these files executable when you clone this repo, but some systems may wipe the executable bit from the file settings upon download or update.
<br>
To make the files in this folder executable again, run the following command:
```
chmod +x <path-to>/shell-utils/linux_bash/exec/*
```
Troubleshooting steps:
- Make sure the path to the [`exec`](./exec) folder is being properly appended to the `PATH` environment variable. You can check the value of this variable by running `echo $PATH`.
- Use the standard Linux `which` command to verify that a specific program is callable by name. Running `which email_me` should print out the absolute path to the `email_me` file in your local copy of this repo.
