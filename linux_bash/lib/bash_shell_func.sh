#!/bin/bash

## Source base functions
source "$(dirname $(readlink -f "${BASH_SOURCE[0]}"))/bash_base_func.sh"


## String manipulation

function line2space() { tr '\n' ' ' < /dev/stdin; }
function space2line() { tr ' ' '\n' < /dev/stdin; }

function strrep() { sed -r "s|${1}|${2}|g" < /dev/stdin; }
function strcat() { sed -r "s|(.*)|\1${1}|" < /dev/stdin; }


## Path representation

function fullpath() {
    local dirent_arr
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
    local dirent_arr
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
    local dirent_arr
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

function absymlink_defunct() {
    local cmd_arr arg cmd
    cmd_arr=()
    while (( "$#" )); do
        arg="$1"
        if ! [[ $arg == -* ]]; then
            arg=$(readlink -f "$arg")
        fi
        cmd_arr+=( "$arg" )
        shift
    done
    cmd="ln -s ${cmd_arr[*]}"
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

function touch_all() {
    echo "Will recursively search through argument directories and touch all files within"
    if (( $# == 0 )); then
        echo "Usage: touch_all path1 path2 ... pathN"
        return
    fi
    while (( $# > 0 )); do
        echo "Touching files in: ${1}"
        find "$1" -type f -exec touch {} \;
        shift
    done
    echo "Done!"
}

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

function git_drop_all_changes() {
    git checkout -- .
}

function git_reset_keep_changes() {
    git reset HEAD^
}

function git_stash_apply_no_merge() {
    git read-tree stash^{tree}
    git checkout-index -af
}

function git_make_exec() {
    chmod -x $*
    git -c core.fileMode=false update-index --chmod=+x $*
    chmod +x $*
}

function git_cmd_in() {

    ## Arguments
    local start_dir; start_dir="$(pwd)"
    local git_cmd_name='cmd'
    local git_cmd_arr=()
    local repo_dir_arr=()
    local ssh_passphrase=''

    ## Custom globals
    local git_cmd_choices_arr=( 'clone' 'branch' 'stash' 'apply' 'stash apply' 'pull' 'plush' )
    local git_cmd_need_ssh_arr=( 'clone' 'pull' 'push' )
    local start_dir repo_dir_arr repo_dir repo_name

    if [ -n "$1" ]; then
        git_cmd_name="$1"; shift
    fi
    ## Usage
    read -r -d '' script_usage << EOM
Usage: git_${git_cmd_name}_in [-p ssh_passphrase] REPO_DIR...
EOM
    if (( $# == 0 )); then
        echo_e "$script_usage"
        return
    fi

    ## Parse arguments
    local arg arg_opt arg_opt_nargs arg_val_can_start_with_dash
    while (( "$#" )); do
        arg="$1"

        if ! [[ $arg == -* ]]; then
            if (( $(indexOf "$arg" ${git_cmd_choices_arr[@]+"${git_cmd_choices_arr[@]}"}) != -1 )); then
                git_cmd_arr+=( "$arg" )
            else
                repo_dir_arr+=( "$(fullpath "$arg")" )
            fi

        else
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            arg_opt_nargs=''
            arg_val_can_start_with_dash=false

            if [ "$arg_opt" == 'p' ] || [ "$arg_opt" == 'pw' ]; then
                arg_opt_nargs=1
                ssh_passphrase="$2"

            elif [ "$arg_opt" == 'h' ] || [ "$arg_opt" == 'help' ]; then
                arg_opt_nargs=0
                echo "$script_usage"
                return

            else
                echo_e "Unexpected argument: ${arg}"
                return
            fi

            if [ -z "$arg_opt_nargs" ]; then
                echo_e "Developer error! "'$arg_opt_nargs'" was not set for argument: ${arg}"
                return
            fi

            local i
            for i in $(seq 1 $arg_opt_nargs); do
                shift
                arg_val="$1"
                if [ "$arg_val_can_start_with_dash" == "false" ] && [[ $arg_val == -* ]]; then
                    echo_e "Unexpected argument value: ${arg} ${arg_val}"
                    return
                fi
            done
        fi

        shift
    done

    for repo_dir in "${repo_dir_arr[@]}"; do
        echo -e "\nChanging to repo dir: ${repo_dir}"
        cd "$repo_dir" || return
        repo_name=$(basename "$repo_dir")

        for git_cmd in "${git_cmd_arr[@]}"; do
            echo "'${repo_name}' results of 'git ${git_cmd}' command:"
            if [ -n "$ssh_passphrase" ] && (( $(indexOf "$git_cmd" ${git_cmd_need_ssh_arr[@]+"${git_cmd_need_ssh_arr[@]}"}) != -1 )); then
                expect -c "spawn git ${git_cmd}; expect \"passphrase\"; send \"${ssh_passphrase}\r\"; interact"
            else
                git -c pager.branch=false ${git_cmd}
            fi
        done
    done

    echo -e "\nChanging back to starting dir: ${start_dir}"
    cd "$start_dir" || return
    echo "Done!"
}

function git_branch_in() {
    git_cmd_in branch branch $*
}
function git_pull_in() {
    local func_args_in=("$@")
    local func_args_out=()

    local do_stashing=false

    local arg arg_opt
    for arg in "${func_args_in[@]}"; do
        if [[ $arg == -* ]]; then
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')

            if [ "$arg_opt" == 'stash' ]; then
                do_stashing=true
                arg=''
            fi
        fi

        if [ -n "$arg" ]; then
            func_args_out+=( "$arg" )
        fi
    done

    if [ "$do_stashing" == "true" ]; then
        git_cmd_arr=( 'stash' 'pull' "'stash apply'" )
    else
        git_cmd_arr=( 'pull' )
    fi

    eval git_cmd_in pull ${git_cmd_arr[*]} ${func_args_out[*]}
}

function git_clone_replace() {
    local repo_url repo_url_bname repo_name
    local cmd status

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

    echo -e "\nDone!"
}


## Other

function layz() {
    local cmd_arr_in cmd_arr_out
    local arg_idx rep_idx
    local arg_out arg_rep
    local cmd_out debug arg_opt
    debug=false
    if [[ $1 == -* ]]; then
        arg_opt=$(echo "$1" | sed -r 's|\-+(.*)|\1|')
        if [ "$arg_opt" == 'dryrun' ] || [ "$arg_opt" == 'debug' ]; then
            debug=true
            shift
        fi
    fi
    cmd_arr_in=("$@")
    cmd_arr_out=()
    for arg_idx in "${!cmd_arr_in[@]}"; do
        arg_out="${cmd_arr_in[$arg_idx]}"
        for rep_idx in "${!cmd_arr_in[@]}"; do
            if (( rep_idx < arg_idx )); then
                arg_rep="${cmd_arr_out[$rep_idx]}"
            else
                arg_rep="${cmd_arr_in[$rep_idx]}"
            fi
            arg_out=$(echo "$arg_out" | sed -r "s|%${rep_idx}([^0-9]\|$)|${arg_rep}\1|g")
        done
        cmd_arr_out+=( "$arg_out" )
    done
    cmd_out="${cmd_arr_out[*]}"
    if [ "$debug" == "true" ]; then
        echo "$cmd_out"
    else
        $cmd_out
    fi
}

