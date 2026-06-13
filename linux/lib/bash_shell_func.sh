#!/bin/bash

## Source base functions
source "$(dirname "${BASH_SOURCE[0]}")/bash_base_func.sh"


## Debugging

# Trace files opened by an interactive Bash startup.
bash_strace() { echo exit | strace bash -li |& grep '^open'; }


## Bash prompts

# Print the current Python virtualenv prompt prefix from PS1.
prompt_venv_prefix() { printf '%s' "$PS1" | grep -Eo '^[[:space:]]*\([^\(\)]*\)[[:space:]]+'; }

# no colors
#prompt_dname() { export PS1="$(prompt_venv_prefix)\W \$ "; }
#prompt_dfull() { export PS1="$(prompt_venv_prefix)\w \$ "; }
#prompt_short() { export PS1="$(prompt_venv_prefix)[\u@\h:\W]\$ "; }
#prompt_med()   { export PS1="$(prompt_venv_prefix)[\u@\h:\w]\$ "; }
#prompt_long()  { export PS1="$(prompt_venv_prefix)[\u@\H:\w]\$ "; }
#prompt_reset() { export PS1="[\u@\h:\w]\$ "; }

# colors
# Set PS1 to show only the current directory name in blue.
prompt_dname() { export PS1="$(prompt_venv_prefix)\[\033[01;34m\]\W\[\033[00m\] \$ "; }
# Set PS1 to show the full current path in blue.
prompt_dfull() { export PS1="$(prompt_venv_prefix)\[\033[01;34m\]\w\[\033[00m\] \$ "; }
# Set PS1 to show user, short host, and current directory name.
prompt_short() { export PS1="$(prompt_venv_prefix)[\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]]\$ "; }
# Set PS1 to show user, short host, and full current path.
prompt_med()   { export PS1="$(prompt_venv_prefix)[\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]]\$ "; }
# Set PS1 to show user, fully-qualified host, and full current path.
prompt_long()  { export PS1="$(prompt_venv_prefix)[\[\033[01;32m\]\u@\H\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]]\$ "; }
# Reset PS1 to the default colored shell-utils prompt.
prompt_reset() { export PS1="[\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]]\$ "; }

# Read, save, and evaluate one interactive command line.
ccmd() {
    read -r -e -p "$ " cmd
    history -s "$cmd"
    eval "$cmd"
}


## Colorize output streams
# Run a command while coloring its stderr stream red.
#
# $@ - Command and arguments to execute.
color() { "$@" 2> >(sed $'s,.*,\e[31m&\e[m,'>&2); }


## String manipulation

# Convert newline-separated text to a single space-separated line.
#
# Takes input from stdin when piped, otherwise from the first argument.
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
# Convert spaces in stdin to newlines.
space2line() { tr ' ' '\n'; }

# Convert whitespace-separated stdin tokens to single-quoted CSV values.
line2csstring() {
    local result=$(xargs printf "'%s',")
    result=$(string_rstrip "$result" ',')
    echo "$result"
}

# Convert newline-separated stdin tokens to single-quoted CSV values.
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

# Apply a token replacement template to each token from stdin.
#
# Takes tokens from stdin. If stdin contains one line, tokens are split on
# spaces; otherwise each line is treated as one token.
#
# $1 - Template string where each `%` is replaced with the current token.
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

# Expand numbered placeholders in a command and execute it.
#
# `%0`, `%1`, and later placeholders are replaced with the corresponding
# command arguments. Use `-debug`, `-dryrun`, `-db`, or `-dr` to print the
# expanded command instead of executing it.
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

# Convert compact timestamps to `YYYY-MM-DD HH:MM:SS` strings.
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

# Activate a Conda environment named after the current directory.
conda_activate() {
    local env_name="$(basename "$(abspath .)")"
    conda activate "$env_name"
}

# Create a `.pixi` symlink to a shared Pixi environment directory.
#
# $1 - Environment name. Defaults to the basename of the current directory.
pixi_create() {
    local env_name
    if [ -n "$1" ]; then
        env_name="$1"
    else
        env_name="$(basename "$(abspath .)")"
    fi
    if [ -z "$env_name" ]; then
        echo "Error: local var 'env_name' is empty" >/dev/null
        return
    fi

    local env_path="${HOME}/mini_pixi_envs/${env_name}"
    local pixi_dir=".pixi"

    set -x
    mkdir -p "$env_path"
    ln -sTf "$env_path" "$pixi_dir"
    set +x
}

# Remove the shared Pixi environment and local `.pixi` symlink.
#
# $1 - Environment name. Defaults to the basename of the current directory.
pixi_remove() {
    local env_name
    if [ -n "$1" ]; then
        env_name="$1"
    else
        env_name="$(basename "$(abspath .)")"
    fi
    if [ -z "$env_name" ]; then
        echo "Error: local var 'env_name' is empty" >/dev/null
        return
    fi

    set -x
    local env_path="${HOME}/mini_pixi_envs/${env_name}"
    local pixi_dir=".pixi"

    rm -rf "$env_path"
    rm -f "$pixi_dir"
    set +x
}

# Create symlinks using absolute target paths.
#
# Non-option arguments are resolved with `readlink -f` before passing them to
# `ln -s`.
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

# Move files or directories and leave absolute symlinks in their place.
#
# Accepts normal `mv`-style source and destination arguments. Use `-dryrun`,
# `-debug`, `-dr`, or `-db` to print the move and symlink commands.
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

# Recursively touch all files under one or more directories.
#
# $@ - Directories whose contained files should be touched.
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

# Move paths to trash and save removal metadata next to each path.
#
# Uses `trash-put` from `trash-cli`. Arguments before the first option are
# treated as paths; remaining arguments are passed to `find`.
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

# Print the first and last N lines from stdin.
#
# $1 - Number of lines to print from the head and tail.
headtail() {
    perl -e 'my $size = '$1'; my @buf = (); while (<>) { print if $. <= $size; push(@buf, $_); if ( @buf > $size ) { shift(@buf); } } print "------\n"; print @buf;'
}

# Placeholder for CSV column extraction.
get_csv_cols() {
    :
}

# Read a line with `IFS` cleared.
wread() {
    IFS= read -r "$@"
}
# Read a NUL-delimited value with `IFS` cleared.
wread0() {
    IFS= read -r -d '' "$@"
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
        readarray -t csv_line_arr < <(echo "$csv_line" | awk -v FPAT="([^${csv_delim}]*)|(\"[^\"]*\")" '{
          for(i=1;i<=NF;i++){
            f=$i
            gsub(/^"|"$/,"",f)
            print f
          }
        }')
    fi

    local i field_name field_idx field_val
    for i in "${!SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR[@]}"; do
        field_name="${SHELL_UTILS_READ_CSV_GET_FIELDS_NAME_ARR[$i]}"
        field_idx="${SHELL_UTILS_READ_CSV_GET_FIELDS_IDX_ARR[$i]}"
        field_val="${csv_line_arr[$field_idx]}"
        if [[ $field_val =~ ^\".*\"$ ]]; then
            eval "${field_name}=${field_val}"
        else
            eval "${field_name}=\"${field_val}\""
        fi
    done

    return "$read_status"
}


## Distill information

# Print file modification times as Unix epoch seconds.
#
# $@ - Paths passed to `stat`.
stat_sec() {
    stat --format '%Y' "$@"
}

# Print disk usage in 1K blocks.
du_k() { du --block-size=1K "$@" | awk '{print $1}'; }
# Print disk usage in 1M blocks.
du_m() { du --block-size=1M "$@" | awk '{print $1}'; }
# Print disk usage in 1G blocks.
du_g() { du --block-size=1G "$@" | awk '{print $1}'; }
# Print disk usage in 1T blocks.
du_t() { du --block-size=1T "$@" | awk '{print $1}'; }

# Remove duplicate stdin lines while preserving first-seen order.
uniq_preserve_order() {
    awk '!visited[$0]++'
}

# Sort lines by a formatted numeric substring.
#
# $1 - Extended regex with a capture group for the sort key.
# $2 - `printf` format used to zero-pad or otherwise normalize the sort key.
#
# Examples
#
#   ls *_meta.txt | smart_sort '_seg([0-9]+)_' '_seg%04d_'
smart_sort() {
    # Example: ls WV01_20140716_102001003208CC00_102001003223F500_2m_lsf_v040310/*_meta.txt | smart_sort '_seg([0-9]+)_' '_seg%04d_'
    local substr_pattern_capture_sort_group="$1"
    local substr_format_expand_sort_group="$2"
    local substr_pattern=$(echo "$substr_pattern_capture_sort_group" | tr -d '()')
    sed -r -e "s|^(.*)(${substr_pattern})(.*)$|\1\2\3,\2|" -e "s|${substr_pattern_capture_sort_group}|\$(printf '${substr_format_expand_sort_group}' \1)|" \
        | while IFS= read -r line; do eval echo "$line"; done \
        | sort | sed -r "s|^(.*)(${substr_pattern})(.*),(${substr_pattern})$|\1\4\3|"
}

# Count lines in each input item.
#
# $@ - Items passed through `process_items`.
wc_nlines() {
    process_items 'wc -l' false true 0 "$@" | awk '{print $1}'
}

# Count repeated stdin items and print counts sorted by item.
count_items() {
    awk '{item_count_dict[$0]++} END {for (item in item_count_dict) printf "%5s <-- %s\n", item_count_dict[item], item}' | sort -k3
}

# Count month-day occurrences found in stdin.
count_by_date() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+' | awk '{date_count_dict[$0]++} END {for (date in date_count_dict) printf "%s : %5s\n", date, date_count_dict[date]}' | sort
}
# Count month occurrences found in stdin.
count_by_month() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+' | awk '{date_count_dict[$1]++} END {for (date in date_count_dict) printf "%s : %5s\n", date, date_count_dict[date]}' | sort
}
# Count month-day occurrences and include one matching example line.
count_by_date_with_ex() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+.*$' | awk '{date=sprintf("%s %2s", $1, $2); date_count_dict[date]++; date_ex_dict[date]=$0} END {for (date in date_count_dict) printf "%s : %5s : %s\n", date, date_count_dict[date], date_ex_dict[date]}' | sort
}
# Count month occurrences and include one matching example line.
count_by_month_with_ex() {
    grep -Eo '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+[0-9]+.*$' | awk '{date=$1; date_count_dict[date]++; date_ex_dict[date]=$0} END {for (date in date_count_dict) printf "%s : %5s : %s\n", date, date_count_dict[date], date_ex_dict[date]}' | sort
}

# Normalize column delimiters in stdin.
#
# $1 - Input column delimiter. Defaults to a space.
# $2 - Output column delimiter. Defaults to a space.
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

# Print selected columns from stdin.
#
# Numeric arguments select columns. The first non-numeric argument sets the
# input delimiter, and the second sets the output delimiter.
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

# Sum each column from delimited numeric stdin.
#
# $1 - Column delimiter. Defaults to a space.
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

# Sum all numeric fields from delimited stdin.
#
# $1 - Column delimiter. Defaults to a space.
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

# Print count, sum, min, max, median, average, standard deviation, range, and interval for stdin numbers.
get_stats() {
    # Adapted from https://stackoverflow.com/a/9790056/8896374
    local perl_cmd
    perl_cmd=''\
'use List::Util qw(max min sum);'\
'@num_list=(); while(<>){ $sqsum+=$_*$_; push(@num_list,$_); };'\
'$nitems=@num_list;'\
'if ($nitems == 0) { $sum=0; $min=0; $max=0; $med=0; $avg=0; $std=0; } else {'\
'$min=min(@num_list)+0; $max=max(@num_list)+0; $sum=sum(@num_list); $avg=$sum/$nitems;'\
'$rng=$max-$min; $int=$rng/($nitems-1);'\
'$sqsumtemp=$sqsum/$nitems-($sum/$nitems)*($sum/$nitems); if ($sqsumtemp <= 0) { $std=overflow; } else { $std=sqrt($sqsumtemp); };'\
'$mid=int $nitems/2; @srtd=sort @num_list; if($nitems%2){ $med=$srtd[$mid]+0; }else{ $med=($srtd[$mid-1]+$srtd[$mid])/2; }; };'\
'print "cnt: ${nitems}\nsum: ${sum}\nmin: ${min}\nmax: ${max}\nmed: ${med}\navg: ${avg}\nstd: ${std}\nrng: ${rng}\nint: ${int}\n";'\
'if ($nitems == 0) { exit(1); } else { exit(0); };'
    perl -e "$perl_cmd"
}

# Print differences between consecutive numeric stdin values.
get_intervals() {
    awk 'BEGIN {prev_val="";} {curr_val=$0; if (prev_val!="") print curr_val-prev_val; prev_val=curr_val;}'
}

# Compare matching file sizes between two directory trees.
#
# $1 - Base directory.
# $2 - Comparison directory.
# $@ - Additional `find` arguments after the first two paths.
filesize_diff_perc() {
    local base_dir="$1"; shift
    local comp_dir="$1"; shift
    local find_args=$(escape_regex_special_chars "$*")
    paste -d',' \
        <(eval find "$base_dir" -type f "$find_args" -print | sort | xargs du --block-size=1K "$@" | awk '{print $1}') \
        <(eval find "$comp_dir" -type f "$find_args" -print | sort | xargs du --block-size=1K "$@" | awk '{print $1}') \
        | awk -F',' '{print ($2-$1)/$1}' | get_stats
}


# Find operations

#alias findl='find -mindepth 1 -maxdepth 1'
#alias findls='find -mindepth 1 -maxdepth 1 -ls | sed -r "s|^[0-9]+\s+[0-9]+\s+||"'
#alias findlsh='find -mindepth 1 -maxdepth 1 -type f -exec ls -lh {} + | sed -r "s|^[0-9]+\s+[0-9]+\s+||"'
# Dispatch shared parsing and execution for shell-utils find wrappers.
#
# $1 - Wrapper name controlling default depth and output behavior.
# $@ - Arguments passed through to `find` after wrapper-specific parsing.
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
        local stock_depth_funcs=( 'findl' 'findls' 'findlsh' 'findd1' )
        if [ "$(itemOneOf "$find_func_name" "${stock_depth_funcs[@]}")" = true ] && [ "$depth_arg_provided" = false ]; then
            stock_depth_args="-mindepth 1 -maxdepth 1"
        fi

        if [ "$find_func_name" = 'findl' ]; then
            find_cmd_suffix=''
        elif [ "$find_func_name" = 'findls' ]; then
            find_cmd_suffix="-ls | sed -r 's|^[0-9]+\s+[0-9]+\s+||'"
        elif [ "$find_func_name" = 'findlsh' ]; then
            find_cmd_suffix=" -type f -exec ls -lh {} + | sed -r 's|^[0-9]+\s+[0-9]+\s+||'"
        elif [ "$find_func_name" = 'findd1' ]; then
            find_cmd_suffix=" -type d"
        fi

        cmd="find ${opt_args_1[*]} ${path_args[*]} ${stock_depth_args} ${opt_args_2[*]} ${find_cmd_suffix}"
        if [ "$debug" = true ]; then
            echo "$cmd"
        else
            eval "$cmd"
        fi
    fi
}
# Search upward from paths using `find` at each ancestor directory.
findup() {
    find_alias findup "$@"
}
# Run `find` at depth one by default.
findl() {
    find_alias findl "$@"
}
# Run `find -ls` at depth one by default with trimmed listing output.
findls() {
    find_alias findls "$@"
}
# Run a human-readable `ls -lh` for files found at depth one by default.
findlsh() {
    find_alias findlsh "$@"
}
# Run `findls` for the starting path itself.
findst() {
    find_alias findls "$@" -mindepth 0 -maxdepth 0
}
# Find directories at depth one by default.
findd1() {
    find_alias findd1 "$@"
}
# Find files whose sibling files with related suffixes are missing.
#
# $1 - Directory to search.
# $2 - Base suffix used to identify candidate files.
# $@ - Suffixes to check, followed by optional `find` arguments.
#
# Use `-any` to require any checked suffix, `-all` to require all checked
# suffixes, and `-inverse` to invert the match.
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

# List suffixes under paths beginning with a prefix.
#
# $1 - Path prefix to strip from matching entries.
ls_suffix() {
    ls -1 ${1}* | sed "s|^${1}||"
}


## Package management

# Update apt metadata and remove cached or unused packages.
apt_cleanup() {
    sudo apt-get update && sudo apt-get autoclean && sudo apt-get clean && sudo apt-get autoremove
}

# Export the active Conda environment from explicit history.
conda_history() {
    conda env export --from-history
}

# List installed Python packages with verbose metadata.
pip_history() {
    python -m pip list --verbose
}


## Git

# Print the current repository origin URL.
git_remote() {
    git config --get remote.origin.url
}

# Open the current repository origin URL in Google Chrome.
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

# Drop all unstaged and staged working tree changes.
git_drop_all_changes() {
    git checkout -- .
}

# Reset HEAD back one commit while keeping working tree changes.
git_reset_keep_changes() {
    git reset HEAD^
}

# Hard-reset the current repository to HEAD.
git_reset_drop_changes() {
    git reset --hard HEAD
}

# Apply the stash tree directly without Git's merge machinery.
git_stash_apply_no_merge() {
    git read-tree stash^{tree}
    git checkout-index -af
}

# Apply a patch with rejects and whitespace fixes.
git_apply_force() {
    git apply --reject --whitespace=fix "$@"
}

# Delete all local branches except the current branch.
git_remove_local_branches() {
    git branch | grep -v '\*' | xargs -r git branch -D
}
# Fetch pruned refs and delete local branches whose upstream is gone.
git_branch_cleanup() {
    git fetch --prune
    git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D
}

# Mark files executable in Git index and filesystem.
git_make_exec() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
        return
    fi
    chmod -x "$@"
    git -c core.fileMode=false update-index --chmod=+x "$@"
    chmod +x "$@"
}

# Mark files non-executable in Git index and filesystem.
git_remove_exec() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
        return
    fi
    chmod +x "$@"
    git -c core.fileMode=false update-index --chmod=-x "$@"
    chmod -x "$@"
}

# Create a zip archive of the current repository HEAD.
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

# Run one or more Git commands across repository directories.
#
# $1 - Command group name used in usage output.
# $@ - Git command names, options, and repository directories.
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

# Run `git branch` across repository directories.
git_branch_in() {
    git_cmd_in branch branch "$@"
}
# Run `git status` across repository directories.
git_status_in() {
    git_cmd_in status status "$@"
}
# Run `git fetch` across repository directories.
git_fetch_in() {
    git_cmd_in fetch fetch "$@"
}
# Run `git pull` across repository directories.
#
# Use `-stash` to run `git stash`, `git pull`, and `git stash apply` in each
# repository.
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
# Create Git HEAD zip archives across repository directories.
git_zip_in() {
    git_cmd_in zip git_zip "$@"
}

# Clone a repository and replace an existing same-named local directory.
#
# $1 - Git repository URL.
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

# Print PBS `qstat` job information, optionally filtered.
#
# Options include `-user USER`, `-state STATE`, `-logs`, `-home`, and
# `-dryrun`.
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
# Print running PBS job IDs and names for the current user.
qstat_r_jobs() {
    qstat -fx -u "$USER" | sed 's|</Job>|</Job>\n|g' | grep '<job_state>R</job_state>' | sed -r 's|.*<Job_Id>([^<]+)</Job_Id>.*<Job_Name>([^<]+)</Job_Name>.*|\1,\2|'
}
# Print running PBS job log paths for the current user.
qstat_r_joblogs() {
    qstat -fx -u "$USER" | sed 's|</Job>|</Job>\n|g' | grep '<job_state>R</job_state>' | grep -v '<Job_Name>STDIN</Job_Name>' | sed -r 's|.*<Output_Path>([^<]+)</Output_Path>.*|\1|' | sed -r 's|^.+:([^:]+)$|\1|'
}
# Print running PBS job log paths rewritten under `$HOME`.
qstat_r_joblogs_home() {
    qstat -fx -u "$USER" | sed 's|</Job>|</Job>\n|g' | grep '<job_state>R</job_state>' | grep -v '<Job_Name>STDIN</Job_Name>' | sed -r 's|.*<Output_Path>([^<]+)</Output_Path>.*|\1|' | sed -r 's|^.+:([^:]+)$|\1|' | basename_all | sed "s|^|${HOME}/|"
}

# SSH to a host using `~/.bashrc_from_ssh` as the remote Bash rcfile.
ssh_alias() {
    set -x; ssh "$@" -t "bash --rcfile ~/.bashrc_from_ssh"; set +x
}

# Run SSH through `expect` and provide a key passphrase.
#
# $1 - SSH key passphrase.
# $@ - SSH arguments after the passphrase.
ssh_expect_passphrase() {
    local passphrase="$1"; shift
    local ssh_args=$(echo "$@" | sed -r -e "s|'|\\\\\"|g" -e "s|;|\\\\;|g")
    expect -c "spawn ssh ${ssh_args}; expect \"passphrase\"; send \"${passphrase}\r\"; interact"
}

#alias rsync_example='rsync_alias auto user@hostname -rtLPv'
# Build and run an rsync command with automatic remote direction support.
#
# $1 - Direction: `to-remote`, `from-remote`, or `auto`.
# $2 - Remote host.
# $@ - Optional rsync arguments, then source and destination paths.
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

# Run `rsync_alias auto` with default recursive transfer options.
#
# $1 - Remote host.
# $@ - Source and destination paths, plus any trailing arguments accepted by
#      `rsync_alias`.
rsync_alias_defopt() {
    local remote_host="$1"; shift
    rsync_alias auto "$remote_host" -rtlv --partial-dir='.rsync-partial' --progress --exclude '.DS_Store' "$@"
}
