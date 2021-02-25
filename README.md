# shell-utils
Helpful tools for working in the Linux terminal (primarily Bash), and shortcuts for running scripts in Windows command line environments.

## Get Git
If you don't already have a GitHub account, [sign up for one](https://github.com/join) (it's free). You can thank me later.

When you want to update a code repository you've downloaded ("cloned" is the Git term) to your local machine, best practice is to utilize the `git` program through `git clone` and `git pull` commands. GitHub can leverage an SSH key that authorizes these interactions between the "remote" online repository and your local machine. This SSH key is unique to the local machine, and will need to be tied to your GitHub account.

Why go to the trouble of setting up SSH keys when you could instead download the repo over HTTPS or, easier yet, use the "Download ZIP" button?
- When you want to pull or commit changes to the code, a downloaded ZIP won't be too helpful as your local repository has no connection to your GitHub account.
- Some systems with access restrictions can't interact over HTTPS, and SSH is the only option to have the local repo connected to your GitHub account.

### Installing Git
Most Linux distributions come with Git already installed (you can check by running `git` in your terminal).
Most Windows setups will not come with Git installed.
You can download Git for your operating system [here](https://git-scm.com/downloads).

### Setup SSH keys
With Git now installed, we can generate an SSH key on your local machine and tie it to your GitHub account. If you're on Windows, open "Git Bash" to perform the following steps.
1. Generate an SSH key on your local machine by running `ssh-keygen`. I'd recommend setting a short and memorable passphrase that is similar to a bank PIN in complexity, but a bit stronger (please don't actually use your bank PIN).
2. Run `cat ~/.ssh/id_rsa.pub` to print your *public* SSH key in the terminal. This is the key we need to give to GitHub.
3. Go to the ["SSH and GPG keys"](https://github.com/settings/keys) section of your GitHub account settings, and click the "New SSH key" button. Now copy and paste the key that was printed in your terminal into the "Key" box. In the "Title" box, give a concise name for your local machine.

## Next steps
If you're on Linux, there are [additional steps you should take to configure your Bash shell](./linux_bash).
<br>
If you're on Windows, follow [this guide to enable the shortcuts and learn how to use them](./windows_cmd).
