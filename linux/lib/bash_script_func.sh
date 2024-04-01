#!/bin/bash

## Source base functions
source "$(dirname "${BASH_SOURCE[0]}")/bash_base_func.sh"


wrap_cmd_custom_exec() {
    if [ -n "$CUSTOM_EXEC" ]; then
        local cmd
        if (( $# == 0 )); then
            cmd=''
        elif (( $# == 1 )); then
            cmd="$1"
        else
            cmd=$(printf "%q " "$@")
        fi
        ${CUSTOM_EXEC} bash -c "$cmd"
    elif (( $# == 1 )); then
        eval "$1"
    else
        "$@"
    fi
}

wrap_cmd_set_pipefail() {
    local disable_pipefail_at_end cmd_rc
    if [ "$(string_contains "$SHELLOPTS" 'pipefail')" = true ]; then
        disable_pipefail_at_end=false
    else
        set -o pipefail
        disable_pipefail_at_end=true
    fi
    "$@"
    cmd_rc=$?
    if [ "$disable_pipefail_at_end" = true ]; then
        set +o pipefail
    fi
    return "$cmd_rc"
}


## Run command and catch stdout/stderr

run_and_show_all() { ("$@") }

run_and_hide_out() { ("$@" 1>/dev/null); }

run_and_hide_err() { ("$@" 2>/dev/null); }

run_and_hide_all() { ("$@" 1>/dev/null 2>/dev/null); }

run_and_send_err_to_out() { ("$@" 2>&1); }

run_and_send_out_to_err() { ("$@" 1>&2); }

run_and_swap_out_err() { ("$@" 3>&2 2>&1 1>&3); }

run_and_catch_out_err() {
    local __return_out="$1"; shift
    local __return_err="$1"; shift
    local cmd_args=("$@")
    local status=0

    if env | grep -q '^TMPDIR='; then
        if [ ! -d "$TMPDIR" ]; then
            mkdir -p "$TMPDIR"
        fi
    fi

    local tmpfile_out=$(mktemp)
    local tmpfile_err=$(mktemp)
    trap "rm -f \"${tmpfile_out}\" \"${tmpfile_err}\"" 0

    { { eval "${cmd_args[@]}" | tee "$tmpfile_out"; } 2>&1 1>&3 | tee "$tmpfile_err"; } 3>&1 1>&2
    status=$?

    eval "${__return_out}="'$(cat "$tmpfile_out")'
    eval "${__return_err}="'$(cat "$tmpfile_err")'

    rm -f "$tmpfile_out"
    rm -f "$tmpfile_err"

    return $status
}

run_and_catch_out_custom() {
    local command_redirect_fun="$1"; shift
    local __return_out="$1"; shift
    local cmd_args=("$@")
    local cmd_out=''
    local status=0

    exec 5>&1
    cmd_out=$(eval "$command_redirect_fun" "${cmd_args[@]}" | tee >(cat - >&5))
    status=$?

    eval "${__return_out}="'"$cmd_out"'

    return $status
}

run_and_catch_out() {
    local command_redirect_fun='run_and_show_all'
    local __return_out="$1"; shift
    local status=0

    run_and_catch_out_custom "$command_redirect_fun" "$__return_out" "$@"
    status=$?

    return $status
}

run_and_catch_swapped_err() {
    local command_redirect_fun='run_and_swap_out_err'
    local __return_out="$1"; shift
    local status=0

    run_and_catch_out_custom "$command_redirect_fun" "$__return_out" "$@"
    status=$?

    return $status
}

run_and_catch_mix() {
    local command_redirect_fun='run_and_send_err_to_out'
    local __return_out="$1"; shift
    local status=0

    run_and_catch_out_custom "$command_redirect_fun" "$__return_out" "$@"
    status=$?

    return $status
}


## Script control

exit_script_with_status() {
    local status="$1"
    local script_file="$CURRENT_PARENT_BASH_SCRIPT_FILE"

    echo_e -e "\nError executing bash script, exiting with status code (${status}): ${script_file}"

    exit $status
}
