# .bashrc

## Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

## Set umask to enable rwx for group members
#umask 002  # allow OTHER read and execute perms, but not write
umask 007  # disallow OTHER read|write|execute perms

### Settings for interactive shells only
if [ -n "$PS1" ]; then

    # Overwrite possibly goofy system default for command prompt
    # that messes with screen window names
    export PS1='[\u@\h:\w]\$ '
    export PROMPT_COMMAND=''

    # Append trailing slash when tab-completing directory paths
    bind 'set mark-symlinked-directories on'

    # Disable default CTRL+S mapping as XON/XOFF flow control
    # ... you usually don't need it?
    # Then you can use both CTRL+R and CTRL+S to search
    # backwards and forwards through your history!!
    # AND you don't accidentally freeze your screen with CTRL+S
    stty -ixon

fi


### System-specific settings

### FILL OUT OR COMMENT OUT THE FOLLOWING LINES ###
export MY_EMAIL=<your-email-address>  # Necessary for shell-utils 'email_me' script
SHELL_UTILS_PATH=<path-to>/shell-utils/exec  # Necessary for sourcing general purpose shell functions
export PATH=$PATH:$SHELL_UTILS_PATH  # Easily call shell-utils scripts
#export PATH=$PATH:<path-to>/pyscript-utils  # Easily call pyscript-utils scripts

## Aliases

## Functions


### General purpose functions and aliases

if [ -n "$(env | grep '^SHELL_UTILS_PATH=')" ] && [ -n "$SHELL_UTILS_PATH" ]; then
    source "${SHELL_UTILS_PATH}/lib/bash_shell_func.sh"
fi

