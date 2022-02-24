#!/bin/bash

## Source base functions
source "$(dirname "${BASH_SOURCE[0]}")/bash_base_func.sh"


## Bash prompts

prompt_venv_prefix() { printf '%s' "$PS1" | grep -Eo '^[[:space:]]*\([^\(\)]*\)[[:space:]]+'; }

# no colors
#prompt_dname() { export PS1="$(prompt_venv_prefix)\W \$ "; }
#prompt_dfull() { export PS1="$(prompt_venv_prefix)\w \$ "; }
#prompt_short() { export PS1="$(prompt_venv_prefix)[\u@\h:\W]\$ "; }
#prompt_med()   { export PS1="$(prompt_venv_prefix)[\u@\h:\w]\$ "; }
#prompt_long()  { export PS1="$(prompt_venv_prefix)[\u@\H:\w]\$ "; }
#prompt_reset() { export PS1="[\u@\h:\w]\$ "; }

# colors
prompt_dname() { export PS1="$(prompt_venv_prefix)\[\033[01;34m\]\W\[\033[00m\] \$ "; }
prompt_dfull() { export PS1="$(prompt_venv_prefix)\[\033[01;34m\]\w\[\033[00m\] \$ "; }
prompt_short() { export PS1="$(prompt_venv_prefix)[\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]]\$ "; }
prompt_med()   { export PS1="$(prompt_venv_prefix)[\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]]\$ "; }
prompt_long()  { export PS1="$(prompt_venv_prefix)[\[\033[01;32m\]\u@\H\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]]\$ "; }
prompt_reset() { export PS1="[\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]]\$ "; }

ccmd() {
    read -r -e -p "$ " cmd
    history -s "$cmd"
    eval "$cmd"
}


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

line2csstring() {
    local result=$(xargs printf "'%s',")
    result=$(string_rstrip "$result" ',')
    echo "$result"
}

string_replace() { sed -r "s|${1}|${2}|g"; }
string_prepend() { sed -r "s|(.*)|${1}\1|"; }
string_append() { sed -r "s|(.*)|\1${1}|"; }


## Command-line argument manipulation

echoeval() {
    local echo_args
    if [[ -p /dev/stdin ]]; then
        IFS= read -r echo_args
    else
        echo_args="$*"
    fi
    eval "echo ${echo_args}"
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

layz() {
    local cmd_arr_in cmd_arr_out
    local arg_idx rep_idx
    local arg_out arg_rep
    local cmd_out debug arg_opt
    debug=false
    if [[ $1 == -* ]]; then
        arg_opt=$(echo "$1" | sed -r 's|\-+(.*)|\1|')
        if [ "$arg_opt" = 'db' ] || [ "$arg_opt" = 'debug' ] || [ "$arg_opt" = 'dr' ] || [ "$arg_opt" = 'dryrun' ]; then
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


## File operations

link_or_copy() {
    if ! ln -f "$@"; then
        cp "$@"
    fi
}

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

mv_and_absymlink() {
    local src_arr=()
    local dst=''
    local mv_args_arr=()
    local dst_dir_exists
    local dryrun=false
    if (( $# == 2 )); then
        src_arr+=( "$1" )
        dst="$2"
        if [ -d "$dst" ]; then
            dst_dir_exists=true
        else
            dst_dir_exists=false
        fi
    else
        dst_dir_exists=true
        local arg arg_opt
        while (( $# )); do
            arg="$1"
            if [ "$(string_startswith "$arg" '-')" = true ]; then
                arg_opt=$(string_lstrip "$arg" '-')
                if [ "$(itemOneOf "$arg_opt" 'dr' 'dryrun' 'db' 'debug')" = true ]; then
                    dryrun=true
                    shift; continue
                elif [ "$arg" == '-t' ]; then
                    dst="$2"; shift
                else
                    mv_args_arr+=( "$arg" )
                fi
            elif (( $# == 1 )) && [ -z "$dst" ]; then
                dst="$arg"
            else
                src_arr+=( "$arg" )
            fi
            shift
        done
    fi
    local mv_opt_args="${mv_args_arr[*]+${mv_args_arr[*]}}"
    local dryrun_arg
    if [ "$dryrun" = true ]; then
        dryrun_arg='-dryrun'
    else
        dryrun_arg=''
    fi
    local src dst_path
    for src in "${src_arr[@]}"; do
        mv_cmd="mv ${mv_opt_args} \"${src}\" \"${dst}\""
        if [ "$dryrun" = true ]; then
            echo "$mv_cmd"
        else
            eval "$mv_cmd"
        fi
        if [ "$dst_dir_exists" = false ]; then
            dst_path="$dst"
        else
            dst_path="${dst%/}/$(basename "$src")"
        fi
        absymlink ${dryrun_arg} "$dst_path" "${src%/}"
    done
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


## Read inputs

SHELL_UTILS_READ_CSV_IP=false
read_csv() {
    local get_fields="$1"
    local csv_delim=','
    if (( $# >= 2 )); then
        csv_delim="$2"
    fi

    local read_status IFS
    local csv_line csv_line_arr
    csv_line=''

    if [ "$SHELL_UTILS_READ_CSV_IP" = false ]; then
        SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR=()
        SHELL_UTILS_READ_CSV_GET_FIELDS_IDX_ARR=()
        local header_line get_fields_arr header_fields_arr
        IFS= read -r header_line
        read_status=$?
        if (( read_status != 0 )); then return "$read_status"; fi
        IFS="$csv_delim" read -ra get_fields_arr <<< "$get_fields"
        IFS="$csv_delim" read -ra header_fields_arr <<< "$header_line"
        local get_field_idx field_name field_idx
        local get_field_in_header=false
        local first_missing_get_field=''
        for get_field_idx in "${!get_fields_arr[@]}"; do
            field_name="${get_fields_arr[${get_field_idx}]}"
            eval "unset ${field_name}"
            field_idx=$(indexOf "$field_name" "${header_fields_arr[@]}")
            if (( field_idx == -1 )) && [ -z "$first_missing_get_field" ]; then
                first_missing_get_field="$field_name"
            fi
            if (( field_idx == -1 )) && [ "$get_field_in_header" = false ]; then
                field_idx="$get_field_idx"
            elif (( field_idx == -1 )) || [ -n "$first_missing_get_field" ]; then
                echo "ERROR: Cannot find field name '${first_missing_get_field}' in CSV header" >&2
                unset SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR
                unset SHELL_UTILS_READ_CSV_GET_FIELDS_IDX_ARR
                return 1
            else
                get_field_in_header=true
            fi
            SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR+=( "$field_name" )
            SHELL_UTILS_READ_CSV_GET_FIELDS_IDX_ARR+=( "$field_idx" )
        done
        if [ -n "$first_missing_get_field" ]; then
            # No 'get fields' match strings in first row of CSV,
            # so assume the CSV has no header and match order of
            # 'get fields' to the order of CSV columns.
            csv_line="$header_line"
            csv_line_arr=("${header_fields_arr[@]}")
        fi
        SHELL_UTILS_READ_CSV_IP=true
    fi

    if [ -z "$csv_line" ]; then
        IFS= read -r csv_line
        read_status=$?
        if (( read_status != 0 )); then
            if [ -n "$csv_line" ]; then
                # This is likely the case where we're reading
                # the last line of input and it doesn't have
                # a trailing newline so 'read' has a nonzero
                # exit status. We still want to parse this line.
                read_status=0
            else
                SHELL_UTILS_READ_CSV_IP=false
                unset SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR
                unset SHELL_UTILS_READ_CSV_GET_FIELDS_IDX_ARR
                local field_name
                for field_name in "${SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR[@]}"; do
                    eval "unset ${field_name}"
                done
                return "$read_status"
            fi
        fi
        IFS="$csv_delim" read -ra csv_line_arr <<< "$csv_line"
    fi

    local i field_name field_idx field_val
    for i in "${!SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR[@]}"; do
        field_name="${SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR[$i]}"
        field_idx="${SHELL_UTILS_READ_CSV_GET_FIELDS_IDX_ARR[$i]}"
        field_val="${csv_line_arr[$field_idx]}"
        eval "${field_name}=\"${field_val}\""
    done

    return "$read_status"
}


## Distill information

wc_nlines() {
    process_items 'wc -l' false true "$@" | awk '{print $1}'
}

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
        if [[ $arg == -* ]] || [ "$arg" == '!' ]; then
            parsing_opt_args=true
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            if [ "$arg_opt" = 'db' ] || [ "$arg_opt" = 'debug' ] || [ "$arg_opt" = 'dr' ] || [ "$arg_opt" = 'dryrun' ]; then
                debug=true
                shift; continue
            elif [ "$arg_opt" = 'mindepth' ]; then
                depth_arg_provided=true
            elif [ "$arg_opt" = 'maxdepth' ]; then
                depth_arg_provided=true
            elif [ "$arg_opt" = 'H' ] || [ "$arg_opt" = 'L' ] || [ "$arg_opt" = 'P' ]; then
                opt_args_1+=( "$arg" )
                shift; parsing_opt_args=false; continue
            elif [ "$arg_opt" = 'D' ] || [ "$arg_opt" = 'Olevel' ]; then
                shift; argval="$1"
                opt_args_1+=( "$arg" "$argval" )
                shift; parsing_opt_args=false; continue
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
    suffix_exist_cond='all'
    check_suffix_arr=()

    local arg
    while (( "$#" )); do
        arg="$1"
        if ! [[ $arg == -* ]]; then
            check_suffix_arr+=( "$arg" )
        else
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            if [ "$arg_opt" = 'any' ]; then
                suffix_exist_cond='any'
            elif [ "$arg_opt" = 'all' ]; then
                suffix_exist_cond='all'
            else
                break
            fi
        fi
        shift
    done

    if [ "$suffix_exist_cond" = 'all' ]; then
        require_all_suffix_exist=true
    elif [ "$suffix_exist_cond" = 'any' ]; then
        require_all_suffix_exist=false
    fi

    suffix_list=$(printf '"%s" ' "${check_suffix_arr[@]}")
    if [ -n "$base_suffix" ]; then
        suffix_sub_expr='${base_dirent/'"${base_suffix}"'/${suffix}}'
    else
        suffix_sub_expr='${base_dirent}${suffix}'
    fi

    find_alias find_missing_suffix "$search_dir" "$@" -name "*${base_suffix}" -exec bash -c 'base_dirent={}; require_all_suffix_exist='"$require_all_suffix_exist"'; all_exist=true; some_exist=false; for suffix in '"$suffix_list"'; do check_dirent="'"$suffix_sub_expr"'"; if [ -e "$check_dirent" ]; then some_exist=true; else all_exist=false; fi; if [ "$require_all_suffix_exist" = true ]; then if [ "$all_exist" = false ]; then echo "$base_dirent"; exit; fi; elif [ "$some_exist" = true ]; then exit; fi; done; if [ "$some_exist" = false ]; then echo "$base_dirent"; fi;' \;
}


## Git

git_remote() {
    git config --get remote.origin.url
}

git_webpage() {
    local get_url_cmd="git config --get remote.origin.url"
    local url=$(eval "$get_url_cmd")
    if [ -z "$url" ]; then
        echo "Repo lookup command returned nothing: '${get_url_cmd}'"
        return
    fi
    url="${url##*@}"
    url="${url//://}"
    if ! echo "$url" | grep -q '^http'; then
        url="https://${url}"
    fi
    open -a "Google Chrome" "$url"
}

git_drop_all_changes() {
    git checkout -- .
}

git_reset_keep_changes() {
    git reset HEAD^
}

git_reset_drop_changes() {
    git reset --hard HEAD
}

git_stash_apply_no_merge() {
    git read-tree stash^{tree}
    git checkout-index -af
}

git_apply_force() {
    git apply --reject --whitespace=fix "$@"
}

git_remove_local_branches() {
  git branch | grep -v '\*' | xargs git branch -D
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
    local git_cmd_choices=( 'clone' 'branch' 'stash' 'apply' 'stash apply' 'pull' 'push' )
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

        if [ "$(string_startswith "$arg" '-')" = false ]; then
            if [ "$(itemOneOf "$arg" "${git_cmd_choices[@]}")" = true ]; then
                git_cmd_arr+=( "$arg" )
            else
                repo_dir_arr+=( "$(fullpath "$arg")" )
            fi

        else
            arg_opt="$(string_lstrip "$arg" '-')"
            arg_opt_nargs=''
            if [ "$(string_contains "$arg_opt" '=')" = true ]; then
                arg_val="${arg_opt#*=}"
                arg_opt="${arg_opt%%=*}"
                arg_opt_nargs_do_shift=false
            else
                arg_val="$2"
                arg_opt_nargs_do_shift=true
            fi
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
            if [ "$arg_opt_nargs_do_shift" = true ] && (( arg_opt_nargs >= 1 )); then
                for arg_num in $(seq 1 $arg_opt_nargs); do
                    shift
                    arg_val="$1"
                    if [ -z "$arg_val" ]; then
                        echo_e "Missing expected value (#${arg_num}) for argument: ${arg}"
                        exit_script_with_status 1
                    elif [ "$arg_val_can_start_with_dash" = false ] && [ "$(string_startswith "$arg_val" '-')" = true ]; then
                        echo_e "Unexpected argument value: ${arg} ${arg_val}"
                        exit_script_with_status 1
                    fi
                done
            fi
        fi

        shift
    done

    for repo_dir in "${repo_dir_arr[@]}"; do
        echo -e "\nChanging to repo dir: ${repo_dir}"
        cd "$repo_dir" || return
        repo_name=$(basename "$repo_dir")

        for git_cmd in "${git_cmd_arr[@]}"; do
            echo "'${repo_name}' results of 'git ${git_cmd}' command:"
            if [ -n "$ssh_passphrase" ] && [ "$(itemOneOf "$git_cmd" "${git_cmd_need_ssh_arr[@]}")" = true ]; then
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
        if [ "$(string_startswith "$arg" '-')" = true ]; then
            arg_opt="$(string_lstrip "$arg" '-')"

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


## Other

ssh_alias() {
    set -x; ssh "$@" -t "bash --rcfile ~/.bashrc_from_ssh"; set +x
}

#alias rsync_example='rsync_alias auto user@hostname -rtLPv'
rsync_alias() {
    local direction_choices=( 'to-host' 'from-host' 'auto' )
    local direction="$1"; shift
    local remote_host="$1"; shift
    local opt_arg_arr=()
    local dryrun=false

    local arg arg_opt
    while (( $# > 2 )); do
        arg="$1"; shift
        if [[ $arg == -* ]]; then
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            if [ "$arg_opt" == 'dryrun' ]; then
                dryrun=true
                continue
            elif [ "$arg_opt" == 'to-host' ] || [ "$arg_opt" == 'from-host' ]; then
                direction="$arg_opt"
                continue
            fi
        fi
        if [[ $arg == *"*"* ]] || [[ $arg == *" "* ]]; then
            arg="'${arg}'"
        fi
        opt_arg_arr+=( "$arg" )
    done
    local src_path="$1"
    local dst_path="$2"

    if [ "$(itemOneOf "$direction" "${direction_choices[@]}")" = false ]; then
        echo_e "ERROR: rsync_alias DIRECTION must be one of the following: ${direction_choices[*]}"
        return 1
    elif [ -z "$remote_host" ] || [ -z "$src_path" ] || [ -z "$dst_path" ] || [[ $src_path == -* ]] || [[ $dst_path == -* ]]; then
        echo_e "ERROR: rsync_alias required postional arguments: DIRECTION HOST SRC DEST"
        return 1
    fi

    if [ "$direction" = 'to-host' ]; then
        dst_path="${remote_host}:${dst_path}"
    elif [ "$direction" = 'from-host' ]; then
        src_path="${remote_host}:${src_path}"
    elif [ "$direction" = 'auto' ]; then
        if [ -e "$src_path" ] && [ -e "$dst_path" ]; then
            echo_e "ERROR: rsync_alias cannot automatically determine DIRECTION when both SRC and DEST paths exist locally"
            return 1
        elif [ -e "$src_path" ]; then
            dst_path="${remote_host}:${dst_path}"
        elif [ -e "$dst_path" ]; then
            src_path="${remote_host}:${src_path}"
        else
            echo_e "ERROR: rsync_alias neither SRC nor DEST paths exist locally (DIRECTION='auto')"
            return 1
        fi
    fi

    cmd="rsync ${opt_arg_arr[*]} \"${src_path}\" \"${dst_path}\""
    echo "$cmd"
    if [ "$dryrun" = false ]; then
        eval "$cmd"
    fi
}

rsync_alias_defopt() {
    local remote_host="$1"; shift
    rsync_alias auto "$remote_host" -rtlv --partial-dir='.rsync-partial' --progress --exclude '.DS_Store' "$@"
}
