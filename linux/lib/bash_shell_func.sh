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


## Colorize output streams
color() { "$@" 2> >(sed $'s,.*,\e[31m&\e[m,'>&2); }


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

line2csstring_alt() {
    tr '\n' ',' | sed -r -e "s|\s||g" -e "s|^,*|'|" -e "s|,*$|'|" -e "s|,+|,|g" -e "s|,|','|g"
}

# Replace all instances of a string with another string.
#
# Takes a piped in string (any number of lines) and outputs the
# the same string with all instances of a specified string replaced
# with another provided string.
# This is a simple wrapper of the `sed` command.
#
# $1 - First string, to be searched for and replaced.
# $2 - Second string, to replace the first string with.
#
# Examples
#
#   echo "dog cat dog cat" | string_replace 'cat' 'pig'
#   => "dog pig dog pig"
#
# Prints to stdout the string with replacements made.
#
# Returns the exit code of the wrapped `sed` command.
string_replace() { sed "s|${1}|${2}|g"; }

# Prepend a string to the beginning of each input line.
#
# Takes a piped in string (any number of lines) and outputs the
# the same string with the provided string affixed to the beginning
# of each input line.
# This is a simple wrapper of the `sed` command.
#
# $1 - The string to be prepended to each input line.
#
# Examples
#
#   echo "world" | string_prepend "hello "
#   => "hello world"
#
# Prints to stdout the string with prepends added.
#
# Returns the exit code of the wrapped `sed` command.
string_prepend() { sed "s|^|${1}|"; }

# Append a string to the end of each input line.
#
# Takes a piped in string (any number of lines) and outputs the
# the same string with the provided string affixed to the end
# of each input line.
# This is a simple wrapper of the `sed` command.
#
# $1 - The string to be appended to each input line.
#
# Examples
#
#   echo "hello" | string_append " world"
#   => "hello world"
#
# Prints to stdout the string with appends added.
#
# Returns the exit code of the wrapped `sed` command.
string_append() { sed "s|$|${1}|"; }


## Command-line argument manipulation

# Run `eval echo` on the provided arguments.
#
# Takes in a string of arguments, provided either as function arguments
# or piped in on a single line, and runs  them through
# `eval "echo <arguments>"` so that globs can be expanded.
#
# $@ - Arguments provided to `echo` command.
#
# Examples
#
#   ls *.txt
#   ./test1.txt  ./test2.txt  ./test3.txt
#
#   echoeval "*.txt"
#   => test1.txt test2.txt test3.txt
#
#   echo "*.txt" | echoeval
#   => test1.txt test2.txt test3.txt
#
# Prints to stdout the result of the `echo` command`.
#
# Returns the exit code of the `echo` command.
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

timestmap2datestr() {
    sed -r 's|([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})|\1-\2-\3 \4:\5:\6|'
}


## File operations

# Link file(s) if possible, otherwise copy.
#
# First executes `ln -f <arguments>` with all provided arguments appended
# If the return code of that command is non-zero, executes `cp <arguments>`
# using the same set of provided arguments.
#
# $@ - Arguments provided to `ln -f` or `cp` to perform link or copy.
#
# Examples
#
#   link_or_copy "src_file.txt" "dst_file.txt"
#
# Returns the non-zero exit code of `cp` command if both `ln -f` and `cp`
# are unsuccessful (non-zero exit code), or 0 otherwise.
link_or_copy() {
    if ! ln -f "$@"; then
        cp "$@"
    fi
}

absymlink_defunct() {
    local arg_arr arg
    arg_arr=()
    while (( $# > 0 )); do
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
        find "$1" -type f -exec touch {} +
        shift
    done
    echo "Done!"
}

trashem() {
    # Utilizes trash-cli: https://github.com/andreafrancia/trash-cli
    if (( $# == 0 )); then
        echo "Usage: trashem PATH... ['find' OPTION]..."
        return
    fi
    path_arr=()
    while (( $# > 0 )); do
        if [[ $1 == -* ]]; then
            break
        fi
        path_arr+=( "$(abspath "${1%/}")" )
        shift
    done
    if (( ${#path_arr[@]} == 0 )); then
        echo "Usage: PATH... ['find' OPTION]..."
        return
    fi
    for path in "${path_arr[@]}"; do
        echo "Trashing: ${path}"
        stat "$path" > "${path}.removed.stat"
        find "$path" "$@" | sort > "${path}.removed.contents"
        trash-put "$path"
    done
}


## Read inputs

headtail() {
    perl -e 'my $size = '$1'; my @buf = (); while (<>) { print if $. <= $size; push(@buf, $_); if ( @buf > $size ) { shift(@buf); } } print "------\n"; print @buf;'
}

get_csv_cols() {
    :
}

SHELL_UTILS_READ_CSV_IP=false
# Read CSV file field values line by line.
#
# This method is a substitute for the standard `read` command used to
# more easily parse one or more field values from a CSV file. In each
# call to `read_csv`, variables are set in the current shell to reflect
# the values of the indicated field names at the last line read by an
# internal call to the `read` command on the CSV file. The names of
# these variables are the same as the field names, and are meant to be
# used directly.
# The (non-local) variables containing the CSV field values are
# created and modified through `eval`. Once the final line in the CSV
# file has been read, the variables are unset through
# `eval "unset <field_name>"`.
#
# $1 - Comma-separated list of field names whose values will be read.
#
# Examples
#
#   line_num=0
#   while read_csv field1,field2; do
#       ((line_num++))
#       echo "line ${line_num}: field1=${field1}, field2=${field2}"
#   done < "./example.csv"
#   => "line 1: field1=some_value1, field2=other_value1"
#   => "line 2: field1=some_value2, field2=other_value2"
#   => ...
#
# Returns the exit code of the `read` command used to parse the last
# line read from the CSV file.
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

du_k() { du --block-size=1K "$@" | awk '{print $1}'; }
du_m() { du --block-size=1M "$@" | awk '{print $1}'; }
du_g() { du --block-size=1G "$@" | awk '{print $1}'; }
du_t() { du --block-size=1T "$@" | awk '{print $1}'; }

uniq_preserve_order() {
    awk '!visited[$0]++'
}

smart_sort() {
    # Example: ls WV01_20140716_102001003208CC00_102001003223F500_2m_lsf_v040310/*_meta.txt | smart_sort '_seg([0-9]+)_' '_seg%04d_'
    local substr_pattern_capture_sort_group="$1"
    local substr_format_expand_sort_group="$2"
    local substr_pattern=$(echo "$substr_pattern_capture_sort_group" | tr -d '()')
    sed -r -e "s|^(.*)(${substr_pattern})(.*)$|\1\2\3,\2|" -e "s|${substr_pattern_capture_sort_group}|\$(printf '${substr_format_expand_sort_group}' \1)|" \
        | while IFS= read -r line; do eval echo "$line"; done \
        | sort | sed -r "s|^(.*)(${substr_pattern})(.*),(${substr_pattern})$|\1\4\3|"
}

wc_nlines() {
    process_items 'wc -l' false true "$@" | awk '{print $1}'
}

count_items() {
    awk '{item_count_dict[$0]++} END {for (item in item_count_dict) printf "%5s <-- %s\n", item_count_dict[item], item}' | sort -k3
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

strip_cols() {
    local col_delim_in=' '
    local col_delim_out=' '
    if (( $# >= 1 )); then
        col_delim_in="$1"
    fi
    if (( $# >= 2 )); then
        col_delim_out="$2"
    fi
    awk -F "$col_delim_in" '
BEGIN {}
{
    for (i=1; i<=NF; i++) {
        if (i!=1) {
            printf("'"${col_delim_out}"'");
        }
        printf("%s", $i);
    }
    printf("\n");
} END {}'
}

get_cols() {
    local col_idx_arr=()
    local col_delim_in=''
    local col_delim_out=''
    local col_delim_in_provided=false
    local col_delim_out_provided=false
    while (( $# != 0 )); do
        if [ "$(string_is_posint "$1")" = true ]; then
            col_idx_arr+=( "$1" )
        elif [ "$col_delim_in_provided" = false ]; then
            col_delim_in="$1"
            col_delim_in_provided=true
        elif [ "$col_delim_out_provided" = false ]; then
            col_delim_out="$1"
            col_delim_out_provided=true
        fi
        shift
    done
    if [ "$col_delim_in_provided" = false ]; then
        col_delim_in=' '
    fi
    if [ "$col_delim_out_provided" = false ]; then
        if [ "$col_delim_in_provided" = true ]; then
            col_delim_out="$col_delim_in"]
        else
            col_delim_out=','
        fi
    fi
    awk -F "$col_delim_in" '
BEGIN {}
{
    n=split("'"${col_idx_arr[*]}"'", col_idx_arr, " ");
    if (n==0) {
        for (i=1; i<=NF; i++) {
            if (i!=1) {
                printf("'"${col_delim_out}"'");
            }
            printf("%s", $i);
        }
        printf("\n");
    } else {
        for (i=1; i<=n; i++) {
            if (i!=1) {
                printf("'"${col_delim_out}"'");
            }
            col_idx=col_idx_arr[i];
            printf("%s", $col_idx);
        }
        printf("\n");
    }
} END {}'
}

sum_cols() {
    local col_delim=' '
    if (( $# >= 1 )); then
        col_delim="$1"
    fi
    awk -F "$col_delim" '
BEGIN {}
{
    for (i=1; i<=NF; i++) {
        sums[i]+=$i;
        maxi=i;
    }
} END {
    for(i=1; i<=maxi; i++) {
        if (i!=1) {
            printf("'"${col_delim}"'");
        }
        printf("%s", sums[i]);
    }
    printf("\n");
}'
}

sum_all() {
    local col_delim=' '
    if (( $# >= 1 )); then
        col_delim="$1"
    fi
    awk -F "$col_delim" '
BEGIN {}
{
    for (i=1; i<=NF; i++) {
        sum+=$i;
    }
} END {
    printf("%s\n", sum);
}'
}

get_stats() {
    # Adapted from https://stackoverflow.com/a/9790056/8896374
    local perl_cmd
    perl_cmd=''\
'use List::Util qw(max min sum);'\
'@num_list=(); while(<>){ $sqsum+=$_*$_; push(@num_list,$_); };'\
'$nitems=@num_list;'\
'if ($nitems == 0) { $sum=0; $min=0; $max=0; $med=0; $avg=0; $std=0; } else {'\
'$min=min(@num_list)+0; $max=max(@num_list)+0; $sum=sum(@num_list); $avg=$sum/$nitems;'\
'$std=sqrt($sqsum/$nitems-($sum/$nitems)*($sum/$nitems));'\
'$mid=int $nitems/2; @srtd=sort @num_list; if($nitems%2){ $med=$srtd[$mid]+0; }else{ $med=($srtd[$mid-1]+$srtd[$mid])/2; }; };'\
'print "cnt: ${nitems}\nsum: ${sum}\nmin: ${min}\nmax: ${max}\nmed: ${med}\navg: ${avg}\nstd: ${std}\n";'\
'if ($nitems == 0) { exit(1); } else { exit(0); };'
    perl -e "$perl_cmd"
}


# Find operations

#alias findl='find -mindepth 1 -maxdepth 1'
#alias findls='find -mindepth 1 -maxdepth 1 -ls | sed -r "s|^[0-9]+\s+[0-9]+\s+||"'
#alias findlsh='find -mindepth 1 -maxdepth 1 -type f -exec ls -lh {} + | sed -r "s|^[0-9]+\s+[0-9]+\s+||"'
find_alias() {
    local find_func_name="$1"; shift

    local opt_args_1 path_args opt_args_2 debug depth_arg_provided stock_depth_args find_cmd_suffix
    opt_args_1=()
    path_args=()
    opt_args_2=()
    debug=false
    depth_arg_provided=false
    stock_depth_args=''
    find_cmd_suffix=''

    local findup_direct=false
    local findup_minheight=''
    local findup_maxheight=''

    local parsing_opt_args arg arg_opt argval
    parsing_opt_args=false
    while (( $# > 0 )); do
        arg_raw="$1"
        argval_raw="$2"
        arg=$(printf '%q' "$arg_raw")
        argval=$(printf '%q' "$argval_raw")
        if [[ $arg == -* ]]; then
            parsing_opt_args=true
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            if [ "$arg_opt" = 'db' ] || [ "$arg_opt" = 'debug' ] || [ "$arg_opt" = 'dr' ] || [ "$arg_opt" = 'dryrun' ]; then
                debug=true
                shift; continue
            elif [ "$find_func_name" = 'findup' ] && [ "$arg_opt" = 'direct' ]; then
                findup_direct=true
                shift; continue
            elif [ "$find_func_name" = 'findup' ] && [ "$arg_opt" = 'minheight' ]; then
                findup_minheight="$argval"
                shift; shift; continue
            elif [ "$find_func_name" = 'findup' ] && [ "$arg_opt" = 'maxheight' ]; then
                findup_maxheight="$argval"
                shift; shift; continue
            elif [ "$arg_opt" = 'mindepth' ] || [ "$arg_opt" = 'maxdepth' ]; then
                depth_arg_provided=true
                if [ "$find_func_name" = 'findup' ]; then
                    echo_e "findup: mindepth/maxdepth options are not supported, use minheight/maxheight instead"
                    return
                fi
            elif [ "$arg_opt" = 'H' ] || [ "$arg_opt" = 'L' ] || [ "$arg_opt" = 'P' ]; then
                opt_args_1+=( "$arg" )
                shift; parsing_opt_args=false; continue
            elif [ "$arg_opt" = 'D' ] || [ "$arg_opt" = 'Olevel' ]; then
                opt_args_1+=( "$arg" "$argval" ); shift
                shift; parsing_opt_args=false; continue
            fi
        elif [[ $arg_raw == [\!\(\)\;] ]]; then
            parsing_opt_args=true
        fi
        if [ "$parsing_opt_args" = true ]; then
            opt_args_2+=( "$arg" )
        else
            path_args+=( "$arg_raw" )
        fi
        shift
    done

    if [ "$find_func_name" = 'findup' ]; then
        local path_src path_tmp depth_args
        if (( ${#path_args[@]} == 0 )); then
            path_args+=( '.' )
        fi
        for path_src in "${path_args[@]}"; do
            path_tmp=$(fullpath "$path_src")
            depth=0
            while true; do
                if [ -n "$findup_maxheight" ] && (( depth > findup_maxheight )); then
                    break
                fi
                if [ "$findup_direct" = true ] || (( depth == 0 )) || [ "$path_tmp" = '/' ]; then
                    depth_args="-mindepth 0 -maxdepth 0"
                else
                    depth_args="-mindepth 1 -maxdepth 1"
                fi
                if [ -z "$findup_minheight" ] || (( depth >= findup_minheight )); then
                    cmd="find ${opt_args_1[*]} \"${path_tmp}\" ${depth_args} ${opt_args_2[*]} ${find_cmd_suffix}"
                    if [ "$debug" = true ]; then
                        echo "$cmd"
                    else
                        eval "$cmd"
                    fi
                fi
                if [ "$path_tmp" = '/' ]; then
                    break
                fi
                path_tmp=$(dirname "$path_tmp")
                if [ "$findup_direct" = false ] && (( depth == 0 )); then
                    path_tmp=$(dirname "$path_tmp")
                fi
                ((depth++))
            done
        done

    else
        local stock_depth_funcs=( 'findl' 'findls' 'findlsh' )
        if [ "$(itemOneOf "$find_func_name" "${stock_depth_funcs[@]}")" = true ] && [ "$depth_arg_provided" = false ]; then
            stock_depth_args="-mindepth 1 -maxdepth 1"
        fi

        if [ "$find_func_name" = 'findl' ]; then
            find_cmd_suffix=''
        elif [ "$find_func_name" = 'findls' ]; then
            find_cmd_suffix="-ls | sed -r 's|^[0-9]+\s+[0-9]+\s+||'"
        elif [ "$find_func_name" = 'findlsh' ]; then
            find_cmd_suffix=" -type f -exec ls -lh {} + | sed -r 's|^[0-9]+\s+[0-9]+\s+||'"
        fi

        cmd="find ${opt_args_1[*]} ${path_args[*]} ${stock_depth_args} ${opt_args_2[*]} ${find_cmd_suffix}"
        if [ "$debug" = true ]; then
            echo "$cmd"
        else
            eval "$cmd"
        fi
    fi
}
findup() {
    find_alias findup "$@"
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
    find_alias findls "$@" -mindepth 0 -maxdepth 0
}
find_missing_suffix() {
    local search_dir base_suffix check_suffix_arr suffix_exist_cond debug
    search_dir="$1"; shift
    base_suffix="$1"; shift
    check_suffix_arr=()
    suffix_exist_cond='all'
    inverse=false
    debug=false

    local arg
    while (( $# > 0 )); do
        arg="$1"
        if ! [[ $arg == -* ]]; then
            check_suffix_arr+=( "$arg" )
        else
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            if [ "$arg_opt" = 'db' ] || [ "$arg_opt" = 'debug' ] || [ "$arg_opt" = 'dr' ] || [ "$arg_opt" = 'dryrun' ]; then
                debug=true
            elif [ "$arg_opt" = 'any' ]; then
                suffix_exist_cond='any'
            elif [ "$arg_opt" = 'all' ]; then
                suffix_exist_cond='all'
            elif [ "$arg_opt" = 'inverse' ]; then
                inverse=true
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

    if [ "$debug" = true ]; then
        find_alias find_missing_suffix "$search_dir" "$@" -name "*${base_suffix}" -print0 -debug

    elif [ "$require_all_suffix_exist" = true ]; then
        while IFS= read -r -d '' base_dirent; do
            base_dirent_nosuff="${base_dirent%"${base_suffix}"}"
            all_exist=true
            for suffix in "${check_suffix_arr[@]}"; do
                check_dirent="${base_dirent_nosuff}${suffix}"
                if [ ! -e "$check_dirent" ]; then
                    all_exist=false
                    break
                fi
            done
            if { [ "$all_exist" = false ] && [ "$inverse" = false ]; }\
            || { [ "$all_exist" = true  ] && [ "$inverse" = true  ]; }; then
                echo "$base_dirent"
            fi
        done < <(find_alias find_missing_suffix "$search_dir" "$@" -name "*${base_suffix}" -print0)

    elif [ "$require_all_suffix_exist" = false ]; then
        while IFS= read -r -d '' base_dirent; do
            base_dirent_nosuff="${base_dirent%"${base_suffix}"}"
            some_exist=false
            for suffix in "${check_suffix_arr[@]}"; do
                check_dirent="${base_dirent_nosuff}${suffix}"
                if [ -e "$check_dirent" ]; then
                    some_exist=true
                    break
                fi
            done
            if { [ "$some_exist" = false ] && [ "$inverse" = false ]; }\
            || { [ "$some_exist" = true  ] && [ "$inverse" = true  ]; }; then
                echo "$base_dirent"
            fi
        done < <(find_alias find_missing_suffix "$search_dir" "$@" -name "*${base_suffix}" -print0)
    fi
}

ls_suffix() {
    ls -1 ${1}* | sed "s|^${1}||"
}


## Package management

apt_cleanup() {
    sudo apt-get update && sudo apt-get autoclean && sudo apt-get clean && sudo apt-get autoremove
}

conda_history() {
    conda env export --from-history
}

pip_history() {
    python -m pip list --verbose
}


## Git

git_remote() {
    git config --get remote.origin.url
}

git_webpage() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
        return
    fi
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
    git branch | grep -v '\*' | xargs -r git branch -D
}

git_make_exec() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
        return
    fi
    chmod -x "$@"
    git -c core.fileMode=false update-index --chmod=+x "$@"
    chmod +x "$@"
}

git_remove_exec() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
        return
    fi
    chmod +x "$@"
    git -c core.fileMode=false update-index --chmod=-x "$@"
    chmod -x "$@"
}

git_zip() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
        return
    fi
    repo=$(basename "$(git rev-parse --show-toplevel)")
    commit=$(git rev-parse --short HEAD)
    branch=$(git rev-parse --abbrev-ref HEAD)
    zipfile="../${repo}_${branch}-${commit}.zip"
    echo "Creating zipfile archive of repo HEAD with 'git archive': ${zipfile}"
    git archive --format zip --output "$zipfile" HEAD
}

git_cmd_in() {

    ## Arguments
    local start_dir; start_dir="$(pwd)"
    local git_cmd_name='cmd'
    local git_cmd_arr=()
    local repo_dir_arr=()
    local ssh_passphrase=''

    ## Custom globals
    local git_cmd_choices=( 'clone' 'branch' 'status' 'fetch' 'stash' 'apply' 'stash apply' 'pull' 'push' 'git_zip' )
    local git_cmd_need_ssh_arr=( 'clone' 'fetch' 'pull' 'push' )
    local git_cmd_custom_arr=( 'git_zip' )
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
    while (( $# > 0 )); do
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
                arg_val=$(printf '%s' "${arg_opt#*=}" | sed -r -e "s|^['\"]+||" -e "s|['\"]+$||")
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

        if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
            :
        else
            for git_cmd in "${git_cmd_arr[@]}"; do
                if [ "$(itemOneOf "$git_cmd" "${git_cmd_custom_arr[@]}")" = true ]; then
                    echo "'${repo_name}' results of '${git_cmd}' command:"
                    eval "$git_cmd"
                else
                    echo "'${repo_name}' results of 'git ${git_cmd}' command:"
                    if [ -n "$ssh_passphrase" ] && [ "$(itemOneOf "$git_cmd" "${git_cmd_need_ssh_arr[@]}")" = true ]; then
                        expect -c "spawn git ${git_cmd}; expect \"passphrase\"; send \"${ssh_passphrase}\r\"; interact"
                    else
                        git -c pager.branch=false ${git_cmd}
                    fi
                fi
            done
        fi
    done

    echo -e "\nChanging back to starting dir: ${start_dir}"
    cd "$start_dir" || return
    echo "Done!"
}

git_branch_in() {
    git_cmd_in branch branch "$@"
}
git_status_in() {
    git_cmd_in status status "$@"
}
git_fetch_in() {
    git_cmd_in fetch fetch "$@"
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
git_zip_in() {
    git_cmd_in zip git_zip "$@"
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

qstat_info() {
    local user=''
    local job_state=''
    local logs=false
    local home=false
    local dryrun=false

    local arg arg_opt arg_val
    while (( $# > 0 )); do
        arg="$1"
        if [[ $arg == -* ]]; then
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            arg_val="$2"
            if [ "$arg_opt" = 'dryrun' ] || [ "$arg_opt" = 'debug' ]; then
                dryrun=true
            elif [ "$arg_opt" = 'user' ] || [ "$arg_opt" = 'u' ] ; then
                user="$arg_val"; shift
            elif [ "$arg_opt" = 'state' ]; then
                job_state="$arg_val"; shift
            elif [ "$arg_opt" = 'logs' ]; then
                logs=true
            elif [ "$arg_opt" = 'home' ]; then
                home=true
            elif [ -z "$job_state" ] && [[ $arg =~ ^-[a-zA-Z]$ ]]; then
                job_state="${arg//-/}"
            else
                echo "Unrecognized argument: ${arg}"
                return 1
            fi
        else
            echo "Unrecognized argument: ${arg}"
            return 1
        fi
        shift
    done

    if [ -n "$user" ]; then
        arg_user="-u ${user}"
    else
        arg_user=''
    fi
    if [ -n "$job_state" ]; then
        job_state=$(printf '%s' "$job_state" | tr '[:lower:]' '[:upper:]')
        cmd_filter_state="| grep '<job_state>${job_state}</job_state>'"
    else
        cmd_filter_state="| grep -v '<job_state>C</job_state>'"
    fi

    cmd_base="qstat -fx ${arg_user} | sed 's|</Job>|</Job>\n|g' | grep '<Job>' ${cmd_filter_state}"

    if [ "$logs" = true ]; then
        cmd="${cmd_base} | grep -v '<Job_Name>STDIN</Job_Name>' | sed -r 's|.*<Output_Path>([^<]+)</Output_Path>.*|\1|' | sed -r 's|^.+:([^:]+)$|\1|'"
        if [ "$home" = true ]; then
            cmd="${cmd} | rev | cut -d'/' -f1 | rev | sed 's|^|${HOME}/|'"
        fi
    else
        cmd="${cmd_base} | sed -r 's|.*<Job_Id>([^<]+)</Job_Id>.*<Job_Name>([^<]+)</Job_Name>.*<Job_Owner>([^<]+)</Job_Owner>.*|\1,\2,\3|'"
    fi

    if [ "$dryrun" = true ]; then
        echo "$cmd"
    else
        eval "$cmd"
    fi
}
qstat_r_jobs() {
    qstat -fx -u "$USER" | sed 's|</Job>|</Job>\n|g' | grep '<job_state>R</job_state>' | sed -r 's|.*<Job_Id>([^<]+)</Job_Id>.*<Job_Name>([^<]+)</Job_Name>.*|\1,\2|'
}
qstat_r_joblogs() {
    qstat -fx -u "$USER" | sed 's|</Job>|</Job>\n|g' | grep '<job_state>R</job_state>' | grep -v '<Job_Name>STDIN</Job_Name>' | sed -r 's|.*<Output_Path>([^<]+)</Output_Path>.*|\1|' | sed -r 's|^.+:([^:]+)$|\1|'
}
qstat_r_joblogs_home() {
    qstat -fx -u "$USER" | sed 's|</Job>|</Job>\n|g' | grep '<job_state>R</job_state>' | grep -v '<Job_Name>STDIN</Job_Name>' | sed -r 's|.*<Output_Path>([^<]+)</Output_Path>.*|\1|' | sed -r 's|^.+:([^:]+)$|\1|' | basename_all | sed "s|^|${HOME}/|"
}

ssh_alias() {
    set -x; ssh "$@" -t "bash --rcfile ~/.bashrc_from_ssh"; set +x
}

ssh_expect_passphrase() {
    local passphrase="$1"; shift
    local ssh_args=$(echo "$@" | sed -r -e "s|'|\\\\\"|g" -e "s|;|\\\\;|g")
    expect -c "spawn ssh ${ssh_args}; expect \"passphrase\"; send \"${passphrase}\r\"; interact"
}

#alias rsync_example='rsync_alias auto user@hostname -rtLPv'
rsync_alias() {
    local direction_choices=( 'to-remote' 'from-remote' 'auto' )
    local direction="$1"; shift
    local remote_host="$1"; shift
    local opt_arg_arr=()
    local dryrun=false

    local arg arg_opt
    while (( $# > 2 )); do
        arg="$1"; shift
        if [[ $arg == -* ]]; then
            arg_opt=$(echo "$arg" | sed -r 's|\-+(.*)|\1|')
            if [ "$arg_opt" == 'dr' ] || [ "$arg_opt" == 'dryrun' ]; then
                dryrun=true
                continue
            elif [ "$arg_opt" == 'db' ] || [ "$arg_opt" == 'debug' ]; then
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

    if [ "$direction" = 'to-remote' ]; then
        dst_path="${remote_host}:${dst_path}"
    elif [ "$direction" = 'from-remote' ]; then
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

start_gcp() {
    local gcp_dir="$GLOBUS_CONNECT_PERSONAL_INSTALL_DIR"
    if [ -z "$gcp_dir" ]; then
        echo_e "Add 'export GLOBUS_CONNECT_PERSONAL_INSTALL_DIR=\"path-to-gcp-dir\" to your ~/.bashrc file"
        return 1
    fi
    local gcp_process=$(pgrep -af -u "$USER" '[g]lobusonline')
    if [ -z "$gcp_process" ]; then
        local gcp_cmd="${gcp_dir}/globusconnectpersonal -start"
        echo -e "Starting Globus Connect Personal with the following command:\n${gcp_cmd}"
#        setsid nohup "$gcp_cmd" </dev/null >/dev/null 2>&1 &
        eval "$gcp_cmd" </dev/null >/dev/null 2>&1 &
        local wait_sec=3
        echo "Sleeping ${wait_sec} seconds before checking GCP process health..."
        sleep ${wait_sec}s
        gcp_process=$(pgrep -af -u "$USER" '[g]lobusonline')
        if [ -z "$gcp_process" ]; then
            echo "GCP process may have failed to start"
        else
            echo "GCP process appears to be running successfully"
        fi
    fi
}
