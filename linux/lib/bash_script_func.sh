#!/bin/bash

## Source base functions
source "$(dirname "${BASH_SOURCE[0]}")/bash_base_func.sh"


## Log printing

log() {
    local echo_args=( '-e' )
    local arg
    while (( $# > 0 )); do
        arg="$1"
        if [ "$(string_startswith "$arg" '-')" = true ]; then
            arg_opt=$(string_lstrip "$arg" '-')
            if [ "$(re_test '^[neE]+$' "$arg_opt")" = true ]; then
                echo_args+=( "$arg" )
                shift
            else
                break
            fi
        else
            break
        fi
    done
    echo ${echo_args[*]+${echo_args[*]}} "$(date) -- $*"
}

log_e() { log "$@" >&2; }

log_oe() { log "$@" | tee >(cat >&2); }


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


## Get user input

#while true; do read -p "Continue? (y/n): " confirm && [[ $confirm == [yY] || $confirm == [nN] ]] && break ; done ; [[ $confirm == [nN] ]] && exit 1
prompt_y_or_n() {
    local prompt="$1"
    local confirm=''

    while true; do
        read -e -r -p "$prompt" confirm
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

parse_xml_value() {
    local xml_tag="$1"
    grep -Po "<${xml_tag}>(.*?)</${xml_tag}>" | sed -r "s|<${xml_tag}>(.*?)</${xml_tag}>|\1|"
}

round() {
    local number="$1"
    local mode="$2"
    local decimals="$3"

    number=$(string_rstrip_decimal_zeros "$number")
    if [[ $number =~ ^[0-9]+$ ]]; then
        mode='off'
    fi

    if [ "$mode" = 'off' ]; then
        number=$(echo "scale=${decimals}; ${number} / 1" | bc)
    elif [ "$mode" = 'on' ]; then
        :
    elif [ "$mode" = 'up' ]; then
        number=$(bc -l <<< "${number} + 5*10^(-(${decimals}+1))")
    elif [ "$mode" = 'down' ]; then
        number=$(bc -l <<< "${number} - 5*10^(-(${decimals}+1))")
    fi

    number=$(printf "%.${decimals}f" "$number")

    number_trimmed=$(string_rstrip_decimal_zeros "$number")
    if [ "$number_trimmed" = "-0" ]; then
        number="${number:1}"
    fi

    echo "$number"
}

sec2hms() {
    local total_sec="$1"
    local hms_hr hms_min hms_sec

    hms_hr="$(( total_sec / 3600 ))"
    hms_min="$(( (total_sec % 3600) / 60 ))"
    hms_sec="$(( total_sec % 60 ))"

    printf "%02d:%02d:%02d\n" "$hms_hr" "$hms_min" "$hms_sec"
}
hms2sec() {
    local day_part hms_part
    local hms_hr hms_min hms_sec
    local total_sec

    IFS=- read -r day_part hms_part <<< "$1"
    if [ -z "$hms_part" ]; then
        hms_part="$day_part"
        day_part=0
    fi

    IFS=: read -r hms_hr hms_min hms_sec <<< "${hms_part%.*}"
    total_sec="$(( 10#$day_part*86400 + 10#$hms_hr*3600 + 10#$hms_min*60 + 10#$hms_sec ))"

    echo "$total_sec"
}

chmod_octal_digit_to_rwx() {
    local octal_digit="$1"

    local octal_r_arr=( 4 5 6 7 )
    local octal_w_arr=( 2 3 6 7 )
    local octal_x_arr=( 1 3 5 7 )

    local result=''

    if [ "$(itemOneOf "$octal_digit" "${octal_r_arr[@]}")" = true ]; then
        result="${result}r"
    fi
    if [ "$(itemOneOf "$octal_digit" "${octal_w_arr[@]}")" = true ]; then
        result="${result}w"
    fi
    if [ "$(itemOneOf "$octal_digit" "${octal_x_arr[@]}")" = true ]; then
        result="${result}x"
    fi

    echo "$result"
}
