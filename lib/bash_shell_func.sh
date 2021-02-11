#!/bin/bash

set -uo pipefail


## String manipulation

function line2space() { tr '\n' ' ' < /dev/stdin; }
function space2line() { tr ' ' '\n' < /dev/stdin; }


## Path representation

function fullpath() {
    if (( $# > 0 )); then
        dirent_arr=("$@")
    else
        dirent_arr=(*)
    fi
    for dirent in "${dirent_arr[@]}"; do
        readlink -f "$dirent"
    done
}
function basename_all() {
    if (( $# > 0 )); then
        dirent_arr=("$@")
    else
        dirent_arr=(*)
    fi
    for dirent in "${dirent_arr[@]}"; do
        basename "$dirent"
    done
}
function dirname_all() {
    if (( $# > 0 )); then
        dirent_arr=("$@")
    else
        dirent_arr=(*)
    fi
    for dirent in "${dirent_arr[@]}"; do
        dirname "$dirent"
    done
}


## File operations

function absymlink() {
    cmd_arr=()
    while (( "$#" )); do
        arg="$1"
        if ! [[ $arg == -* ]]; then
            arg=$(readlink -f "$arg")
        fi
        cmd_arr+=( "$arg" )
        shift
    done
    cmd=$(echo "ln -s ${cmd_arr[*]}")
    eval "$cmd"
}


## File interrogation

function count_by_date() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+' | awk '{date_count_dict[$0]++} END {for (date in date_count_dict) printf "%s : %5s\n", date, date_count_dict[date]}' | sort < /dev/stdin
}
function count_by_month() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+' | awk '{date_count_dict[$1]++} END {for (date in date_count_dict) printf "%s : %5s\n", date, date_count_dict[date]}' | sort < /dev/stdin
}
function count_by_date_with_ex() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+.*$' | awk '{date=sprintf("%s %2s", $1, $2); date_count_dict[date]++; date_ex_dict[date]=$0} END {for (date in date_count_dict) printf "%s : %5s : %s\n", date, date_count_dict[date], date_ex_dict[date]}' | sort < /dev/stdin
}
function count_by_month_with_ex() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+.*$' | awk '{date=$1; date_count_dict[date]++; date_ex_dict[date]=$0} END {for (date in date_count_dict) printf "%s : %5s : %s\n", date, date_count_dict[date], date_ex_dict[date]}' | sort < /dev/stdin
}


## File modification

function fix_perms() {
    echo "Will give full RWX perms to USER & GROUP, and remove RWX perms from OTHER"
    if (( $# == 0 )); then
        echo "Usage: fix_perms path1 path2 ... pathN"
        return
    fi
    while (( $# > 0 )); do
        echo "Fixing perms in: ${1}"
        chmod -R u=rwX,g=rwX,o-rwx "$1"
        shift
    done
    echo "Done!"
}


## Git

function git_pull_in() {
    if (( $# == 0 )); then
        echo "Usage: git_pull_in <repo-root-dir> ..."
        return
    fi
    start_dir=$(pwd)
    repo_dir_arr=($(fullpath $*))
    for repo_dir in "${repo_dir_arr[@]}"; do
        echo -e "\nChanging to repo dir: ${repo_dir}"
        cd "$repo_dir" || return
        echo "Pulling changes"
        git pull
        shift
    done
    echo -e "\nChanging back to starting dir: ${start_dir}"
    cd "$start_dir" || return
    echo "Done!"
}

function git_clone_replace() {
    if (( $# == 0 )); then
        echo "Usage: git_clone_replace <github-repo-url>"
        return
    fi
    repo_url="$1"
    repo_url_bname=$(basename "$repo_url")
    repo_name="${repo_url_bname/.git/}"
    if [ ! -e "${repo_name}" ]; then
        echo "ERROR: Current repo folder does not exist: ${repo_name}"
        return
    fi
    if [ -e "${repo_name}_old" ]; then
        echo "ERROR: Old repo folder still exists: ${repo_name}_old"
        return
    fi
    if [ -e "${repo_name}_new" ]; then
        echo "ERROR: New repo folder already exists: ${repo_name}_new"
        return
    fi
    cmd="git clone ${repo_url} ${repo_name}_new"
    echo -e "\nCOMMAND: ${cmd}"; eval "$cmd"
    cmd="mv ${repo_name} ${repo_name}_old; mv ${repo_name}_new ${repo_name};"
    echo -e "\nCOMMAND: ${cmd}\n(sleeping 3 seconds...)"; sleep 5s; eval "$cmd"
    status=$?
    if (( status == 0 )); then
        cmd="rm -rf ${repo_name}_old"
        echo -e "\nCOMMAND: ${cmd}\n(sleeping 5 seconds...)"; sleep 5s; eval "$cmd"
    fi
}

