#!/bin/bash

## Bash settings
set -uo pipefail

## Script globals
script_name=$(basename "${BASH_SOURCE[0]}")
script_dir=$({ cd "$(dirname "${BASH_SOURCE[0]}")" || { echo "Failed to access script file directory" >&2; exit; } } && pwd)
script_dir_abs=$({ cd "$(dirname "${BASH_SOURCE[0]}")" || { echo "Failed to access script file directory" >&2; exit; } } && pwd -P)
script_file="${script_dir}/${script_name}"
if [ -L "${BASH_SOURCE[0]}" ]; then
    script_file_abs=$(readlink "${BASH_SOURCE[0]}")
else
    script_file_abs="${script_dir_abs}/${script_name}"
fi
export CURRENT_PARENT_BASH_SCRIPT_FILE="$script_file"
script_args=("$@")

shell_utils_config_dir="${script_dir_abs}/config/"
symlink_errors=false

echo
while IFS='' read -r config_file_new; do
    config_fname=$(basename "$config_file_new")
    config_file_old="${HOME}/${config_fname}"
    config_file_bak="${HOME}/${config_fname}_system_default"

    if [ -e "$config_file_old" ]; then
        if [ -L "$config_file_old" ]; then
            config_file_old_target=$(readlink "$config_file_old")
            echo "Removing existing config file symlink from home dir (${config_file_old} -> ${config_file_old_target})"
            rm "$config_file_old"
        elif [ -e "$config_file_bak" ] && [ ! -L "$config_file_bak" ]; then
            symlink_errors=true
            echo -e "\nERROR: Will not replace existing non-link backup config file:\n  ${config_file_bak}"
            echo -e "** Manually remove or backup this file and then rerun script **\n"
        else
            echo -e "\n** Backing up existing non-link config file: ${config_fname} **"
            mv -v "$config_file_old" "$config_file_bak"
            echo
        fi
    fi

    if [ ! -e "$config_file_old" ]; then
        echo "Symlinking shell-utils config file to home directory: ${config_fname}"
        ln -s "$config_file_new" "${HOME}/"
    fi
done <<< "$(find "$shell_utils_config_dir" -mindepth 1 -maxdepth 1)"

if [ -L "${HOME}/.bashrc" ]; then
    echo "Duplicating .bashrc_integrated symlink as .bashrc in home directory"
    cp -Pf "${HOME}/.bashrc_integrated" "${HOME}/.bashrc"
fi

echo -e "\nDone!"
if [ "$symlink_errors" = true ]; then
    echo -e "\n!! Errors symlinking one or more config files !!"
fi
echo -e "\nCheck the results of 'ls -la ~/' or 'find ~/ -maxdepth 1 -name \".*\" -ls' to verify symlinks"
