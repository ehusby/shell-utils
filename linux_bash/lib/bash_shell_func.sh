#!/bin/bash

## Source base functions
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/bash_script_func.sh"


## String manipulation

line2space() {
    local str result
    if [[ -p /dev/stdin ]]; then
        str=$(cat)
    else
        str="$1"
    fi
    result=$(string_strip "$str" | tr '\n' ' ')
    echo "$result"
}
space2line() { tr ' ' '\n'; }

strrep() { sed -r "s|${1}|${2}|g"; }
strcat() { sed -r "s|(.*)|\1${1}|"; }


## Path representation

fullpath() {
    local dirent dirent_arr
    if [[ -p /dev/stdin ]]; then
        dirent_arr=()
        while IFS= read -r dirent; do
            dirent_arr+=( "$dirent" )
        done
    else
        if (( $# > 0 )); then
            dirent_arr=("$@")
        else
            dirent_arr=(*)
        fi
    fi
    for dirent in "${dirent_arr[@]}"; do
        readlink -f "$dirent"
    done
}
basename_all() {
    local dirent dirent_arr
    if [[ -p /dev/stdin ]]; then
        dirent_arr=()
        while IFS= read -r dirent; do
            dirent_arr+=( "$dirent" )
        done
    else
        if (( $# > 0 )); then
            dirent_arr=("$@")
        else
            dirent_arr=(*)
        fi
    fi
    for dirent in "${dirent_arr[@]}"; do
        basename "$dirent"
    done
}
dirname_all() {
    local dirent dirent_arr
    if [[ -p /dev/stdin ]]; then
        dirent_arr=()
        while IFS= read -r dirent; do
            dirent_arr+=( "$dirent" )
        done
    else
        if (( $# > 0 )); then
            dirent_arr=("$@")
        else
            dirent_arr=(*)
        fi
    fi
    for dirent in "${dirent_arr[@]}"; do
        dirname "$dirent"
    done
}


## File operations

absymlink_defunct() {
    local arg_arr arg
    arg_arr=()
    while (( "$#" )); do
        arg="$1"
        if ! [[ $arg == -* ]]; then
            arg=$(readlink -f "$arg")
        fi
        arg_arr+=( "$arg" )
        shift
    done
    ln -s "${arg_arr[@]}"
}

touch_all() {
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


## Gather information

count_by_date() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+' | awk '{date_count_dict[$0]++} END {for (date in date_count_dict) printf "%s : %5s\n", date, date_count_dict[date]}' | sort
}
count_by_month() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+' | awk '{date_count_dict[$1]++} END {for (date in date_count_dict) printf "%s : %5s\n", date, date_count_dict[date]}' | sort
}
count_by_date_with_ex() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+.*$' | awk '{date=sprintf("%s %2s", $1, $2); date_count_dict[date]++; date_ex_dict[date]=$0} END {for (date in date_count_dict) printf "%s : %5s : %s\n", date, date_count_dict[date], date_ex_dict[date]}' | sort
}
count_by_month_with_ex() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+.*$' | awk '{date=$1; date_count_dict[date]++; date_ex_dict[date]=$0} END {for (date in date_count_dict) printf "%s : %5s : %s\n", date, date_count_dict[date], date_ex_dict[date]}' | sort
}

sum_col() {
    local col_num=1
    local col_delim=' '
    if (( $# >= 1 )); then
        col_num="$1"
    fi
    if (( $# >= 2 )); then
        col_delim="$2"
    fi
    awk -F"$col_delim" "{print \$${col_num}}" | paste -s -d"+" | bc
}

get_stats() {
    # Adapted from https://stackoverflow.com/a/9790056/8896374
    local perl_cmd
    perl_cmd=''\
'use List::Util qw(max min sum);'\
'@num_list=(); while(<>){ $sqsum+=$_*$_; push(@num_list,$_); };'\
'$nitems=@num_list; $sum=sum(@num_list); $avg=$sum/$nitems; $max=max(@num_list)+0; $min=min(@num_list)+0;'\
'$std=sqrt($sqsum/$nitems-($sum/$nitems)*($sum/$nitems));'\
'$mid=int $nitems/2; @srtd=sort @num_list; if($nitems%2){ $med=$srtd[$mid]+0; }else{ $med=($srtd[$mid-1]+$srtd[$mid])/2; };'\
'print "cnt: ${nitems}\nsum: ${sum}\nmin: ${min}\nmax: ${max}\nmed: ${med}\navg: ${avg}\nstd: ${std}\n";'
    perl -e "$perl_cmd"
}


# Find operations

#alias findl='find -mindepth 1 -maxdepth 1'
#alias findls='find -mindepth 1 -maxdepth 1 -ls | sed -r "s|^[0-9]+\s+[0-9]+\s+||"'
#alias findlsh='find -mindepth 1 -maxdepth 1 -type f -exec ls -lh {} \; | sed -r "s|^[0-9]+\s+[0-9]+\s+||"'
find_alias() {
    local find_func_name="$1"; shift

    local opt_args_1 pos_args opt_args_2 debug depth_arg_provided stock_depth_args find_cmd_suffix
    opt_args_1=()
    pos_args=()
    opt_args_2=()
    debug=false
    depth_arg_provided=false
    stock_depth_args=''
    find_cmd_suffix=''

    local parsing_opt_args arg arg_opt argval
    parsing_opt_args=false
    while (( "$#" )); do
        arg="$1"
        if [[ $arg == -* ]]; then
            parsing_opt_args=true
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            if [ "$arg_opt" = 'debug' ]; then
                debug=true
                shift; continue
            elif [ "$arg_opt" = 'mindepth' ]; then
                depth_arg_provided=true
            elif [ "$arg_opt" = 'maxdepth' ]; then
                depth_arg_provided=true
            elif [ "$arg_opt" = 'H' ] || [ "$arg_opt" = 'L' ] || [ "$arg_opt" = 'P' ]; then
                opt_args_1+=( "$arg" )
                shift; continue
            elif [ "$arg_opt" = 'D' ] || [ "$arg_opt" = 'Olevel' ]; then
                shift; argval="$1"
                opt_args_1+=( "$arg" "$argval" )
                shift; continue
            fi
        elif [[ $arg == [\(\)\;] ]]; then
            parsing_opt_args=true
            arg="\\${arg}"
        fi
        if [ "$parsing_opt_args" = true ]; then
            if [[ $arg == *"*"* ]] || [[ $arg == *" "* ]]; then
                arg="'${arg}'"
            fi
            opt_args_2+=( "$arg" )
        else
            pos_args+=( "$arg" )
        fi
        shift
    done

    local stock_depth_funcs=( 'findl' 'findls' 'findlsh' )
    if [ "$(itemOneOf "$find_func_name" "${stock_depth_funcs[@]}")" = true ] && [ "$depth_arg_provided" = false ]; then
        stock_depth_args='-mindepth 1 -maxdepth 1'
    fi

    if [ "$find_func_name" = 'findl' ]; then
        find_cmd_suffix=''
    elif [ "$find_func_name" = 'findls' ]; then
        find_cmd_suffix="-ls | sed -r 's|^[0-9]+\s+[0-9]+\s+||'"
    elif [ "$find_func_name" = 'findlsh' ]; then
        find_cmd_suffix=" -type f -exec ls -lh {} \; | sed -r 's|^[0-9]+\s+[0-9]+\s+||'"
    fi

    cmd="find ${opt_args_1[*]} ${pos_args[*]} ${stock_depth_args} ${opt_args_2[*]} ${find_cmd_suffix}"
    if [ "$debug" = true ]; then
        echo "$cmd"
    else
        eval "$cmd"
    fi
}
findl() {
    find_alias findl "$@"
}
findls() {
    find_alias findls "$@"
}
findlsh() {
    find_alias findlsh "$@"
}
findst() {
    find_alias findls "$1" -mindepth 0 -maxdepth 0
}
find_missing_suffix() {
    local search_dir base_suffix check_suffix_arr
    search_dir="$1"; shift
    base_suffix="$1"; shift
    check_suffix_arr=()

    local arg
    while (( "$#" )); do
        arg="$1"
        if ! [[ $arg == -* ]]; then
            check_suffix_arr+=( "$arg" )
        else
            break
        fi
        shift
    done

    find_alias find_missing_suffix "$search_dir" "$@" -name "*${base_suffix}" -exec bash -c 'base_dirent={}; for suffix in '"${check_suffix_arr[*]}"'; do check_dirent="${base_dirent/'"${base_suffix}"'/${suffix}}"; if [ ! -e "$check_dirent" ]; then echo "$base_dirent"; break; fi; done;' \;
}


## Command-line argument manipulation

layz() {
    local cmd_arr_in cmd_arr_out
    local arg_idx rep_idx
    local arg_out arg_rep
    local cmd_out debug arg_opt
    debug=false
    if [[ $1 == -* ]]; then
        arg_opt=$(echo "$1" | sed -r 's|\-+(.*)|\1|')
        if [ "$arg_opt" = 'dryrun' ] || [ "$arg_opt" = 'debug' ]; then
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
    if [ "$debug" = true ]; then
        echo "$cmd_out"
    else
        $cmd_out
    fi
}

tokentx() {
    local tx="$1"
    local token_arr=()
    local token_tx_arr=()
    local token_delim='\n'
    local token
    while IFS= read -r token; do
        token_arr+=( "$token" )
    done
    if (( ${#token_arr[@]} == 1 )); then
        token_delim=' '
        IFS="$token_delim" read -r -a token_arr <<< "${token_arr[0]}"
    fi
    local token_tx
    for token in "${token_arr[@]}"; do
        token_tx=${tx//'%'/${token}}
        token_tx_arr+=( "$token_tx" )
    done
    printf "%s${token_delim}" "${token_tx_arr[@]}"
}

echoeval() {
    local echo_args
    if [[ -p /dev/stdin ]]; then
        IFS= read -r echo_args
    else
        echo_args="$*"
    fi
    cmd="echo ${echo_args}"
    eval "$cmd"
}


## Git

git_drop_all_changes() {
    git checkout -- .
}

git_reset_keep_changes() {
    git reset HEAD^
}

git_stash_apply_no_merge() {
    git read-tree stash^{tree}
    git checkout-index -af
}

git_make_exec() {
    chmod -x "$@"
    git -c core.fileMode=false update-index --chmod=+x "$@"
    chmod +x "$@"
}

git_cmd_in() {

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

            if [ "$arg_opt" = 'p' ] || [ "$arg_opt" = 'pw' ]; then
                arg_opt_nargs=1
                ssh_passphrase="$2"

            elif [ "$arg_opt" = 'h' ] || [ "$arg_opt" = 'help' ]; then
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
                if [ "$arg_val_can_start_with_dash" = false ] && [[ $arg_val == -* ]]; then
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

git_branch_in() {
    git_cmd_in branch branch "$@"
}
git_pull_in() {
    local func_args_in=("$@")
    local func_args_out=()

    local do_stashing=false

    local arg arg_opt
    for arg in "${func_args_in[@]}"; do
        if [[ $arg == -* ]]; then
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')

            if [ "$arg_opt" = 'stash' ]; then
                do_stashing=true
                arg=''
            fi
        fi

        if [ -n "$arg" ]; then
            func_args_out+=( "$arg" )
        fi
    done

    if [ "$do_stashing" = true ]; then
        git_cmd_arr=( 'stash' 'pull' "'stash apply'" )
    else
        git_cmd_arr=( 'pull' )
    fi

    eval git_cmd_in pull ${git_cmd_arr[*]} ${func_args_out[*]}
}

git_clone_replace() {
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
