#!/bin/bash


## Basic printing

function echo_e() { echo "$@" >&2; }

function echo_oe() { echo "$@" | tee >(cat >&2); }

function log() { echo -e "$(date) -- $*"; }

function log_e() { log "$@" >&2; }

function log_oe() { log "$@" | tee >(cat >&2); }


## String manipulation

function string_to_uppercase() { echo "$@" | tr '[:lower:]' '[:upper:]'; }

function string_to_lowercase() { echo "$@" | tr '[:upper:]' '[:lower:]'; }

function string_lstrip() { echo "$1" | sed "s/^\(${2}\)\+//"; }

function string_rstrip() { echo "$1" | sed "s/\(${2}\)\+\$//"; }

function string_strip() {
    local result="$1"
    local strip_substr="$2"
    result=$(string_lstrip "$result" "$strip_substr")
    result=$(string_rstrip "$result" "$strip_substr")
    echo "$result"
}

function string_rstrip_decimal_zeros { echo "$@" | sed '/\./ s/\.\{0,1\}0\{1,\}$//'; }

function collapse_repeated_substring() { echo "$1" | sed "s/\(${2}\)\+/\1/"; }

function string_join() { local IFS="$1"; shift; echo "$*"; }


## String testing

function re_test() {
    local re_test="$1"
    local test_str="$2"

    if [[ $test_str =~ $re_test ]]; then
        result=true
    else
        result=false
    fi

    echo "$result"
}

function string_is_int() { re_test '^[0-9]+$' "$1"; }

function string_is_datenum() { re_test '^[1-2][0-9]{3}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])$' "$1"; }

function string_is_pairname() { re_test '^[A-Z0-9]{4}_[0-9]{8}_[0-9A-F]{16}_[0-9A-F]{16}$' "$1"; }

function string_startswith() { re_test "^${2}" "$1"; }

function string_endswith() { re_test "${2}\$" "$1"; }

function string_contains() { re_test "${2}" "$1"; }


## Run command and catch stdout/stderr

function run_and_show_all() { ("$@") }

function run_and_hide_out() { ("$@" 1>/dev/null); }

function run_and_hide_err() { ("$@" 2>/dev/null); }

function run_and_hide_all() { ("$@" 1>/dev/null 2>/dev/null); }

function run_and_send_err_to_out() { ("$@" 2>&1); }

function run_and_send_out_to_err() { ("$@" 1>&2); }

function run_and_swap_out_err() { ("$@" 3>&2 2>&1 1>&3); }

function run_and_catch_out_err() {
    local __return_out="$1"; shift
    local __return_err="$1"; shift
    local cmd="$*"

    local cmd_out=''
    local cmd_err=''
    local status=0

    if [ -n "$(env | grep '^TMPDIR=')" ]; then
        if [ ! -d "$TMPDIR" ]; then
            mkdir -p "$TMPDIR"
        fi
    fi

    local tmpfile_out=$(mktemp)
    local tmpfile_err=$(mktemp)
    trap "rm -f ${tmpfile_out} ${tmpfile_err}" 0

    { { $cmd | tee ${tmpfile_out}; } 2>&1 1>&3 | tee ${tmpfile_err}; } 3>&1 1>&2
    status=$?

    cmd_out=$(cat ${tmpfile_out})
    cmd_err=$(cat ${tmpfile_err})

    rm -f ${tmpfile_out}
    rm -f ${tmpfile_err}

    eval $__return_out="'$cmd_out'"
    eval $__return_err="'$cmd_err'"

    return $status
}

function run_and_catch_out_custom() {
    local command_redirect_fun="$1"; shift
    local __return_out="$1"; shift
    local cmd="$*"

    local cmd_out=''
    local cmd_err=''
    local status=0

    exec 5>&1
    cmd_out=$(eval $command_redirect_fun $cmd | tee >(cat - >&5))
    status=$?

    eval $__return_out="'$cmd_out'"

    return $status
}

function run_and_catch_out() {
    local command_redirect_fun='run_and_show_all'
    local __return_out="$1"; shift

    run_and_catch_out_custom "$command_redirect_fun" "$__return_out" "$*"
    status=$?

    return $status
}

function run_and_catch_swapped_err() {
    local command_redirect_fun='run_and_swap_out_err'
    local __return_out="$1"; shift

    run_and_catch_out_custom "$command_redirect_fun" "$__return_out" "$*"
    status=$?

    return $status
}

function run_and_catch_mix() {
    local command_redirect_fun='run_and_send_err_to_out'
    local __return_out="$1"; shift

    run_and_catch_out_custom "$command_redirect_fun" "$__return_out" "$*"
    status=$?

    return $status
}


## Script control

function exit_script_with_status() {
    local status="$1"
    local script_file="$CURRENT_PARENT_BASH_SCRIPT_FILE"

    echo_e "Error executing bash script, exiting with status code (${status}): ${script_file}"

    exit $status
}


## Get user input

#while true; do read -p "Continue? (y/n): " confirm && [[ $confirm == [yY] || $confirm == [nN] ]] && break ; done ; [[ $confirm == [nN] ]] && exit 1
function prompt_y_or_n() {
    local prompt="$1"

    while true; do
        read -p "$prompt" confirm
        if [[ $confirm == [yY] || $confirm == [nN] ]]; then
            break
        fi
    done

    if [[ $confirm == [yY] ]]; then
        echo true
    else
        echo false
    fi
}


## Other

#function indexOf() { local el="$1"; shift; local arr=("$@"); local index=-1; for i in "${!arr[@]}"; do [ "${arr[$i]}" == "$el" ] && { index=$i; break; } done; echo $index; }

function indexOf() {
    local el="$1"     # Save first argument in a variable
    shift             # Shift all arguments to the left (original $1 gets lost)
    local arr=("$@")  # Rebuild the array with rest of arguments
    local index=-1
    for i in "${!arr[@]}"; do
        if [ "${arr[$i]}" == "$el" ]; then
            index=$i
            break
        fi
    done
    echo $index
}


function round() {
    local number="$1"
    local mode="$2"
    local decimals="$3"

    number=$(string_rstrip_decimal_zeros "$number")
    if [[ $number =~ ^[0-9]+$ ]]; then
        mode='off'
    fi

    if [ "$mode" == 'off' ]; then
        number=$(echo "scale=${decimals}; ${number} / 1" | bc)
    elif [ "$mode" == 'on' ]; then
        :
    elif [ "$mode" == 'up' ]; then
        number=$(bc -l <<< "${number} + 5*10^(-(${decimals}+1))")
    elif [ "$mode" == 'down' ]; then
        number=$(bc -l <<< "${number} - 5*10^(-(${decimals}+1))")
    fi

    number=$(printf "%.${decimals}f" "$number")

    number_trimmed=$(echo "$number" | sed '/\./ s/\.\{0,1\}0\{1,\}$//')
    if [ "$number_trimmed" == "-0" ]; then
        number="${number:1}"
    fi

    echo "$number"
}

