#!/bin/bash


## Basic printing

print_string() { printf '%s' "$*"; }

echo_e() { echo "$@" >&2; }

echo_oe() { echo "$@" | tee >(cat >&2); }

log() { echo -e "$(date) -- $*"; }

log_e() { log "$@" >&2; }

log_oe() { log "$@" | tee >(cat >&2); }


## String manipulation

string_to_uppercase() { print_string "$@" | tr '[:lower:]' '[:upper:]'; }

string_to_lowercase() { print_string "$@" | tr '[:upper:]' '[:lower:]'; }

string_lstrip() { print_string "$1" | sed -r "s|^(${2})+||"; }

string_rstrip() { print_string "$1" | sed -r "s|(${2})+$||"; }

string_strip() {
    local string_in="$1"
    local strip_substr=''
    local string_stripped=''

    if (( $# >= 2 )); then
        strip_substr="$2"
    else
        strip_substr='[[:space:]]'
    fi

    string_stripped=$(string_lstrip "$string_in" "$strip_substr")
    string_stripped=$(string_rstrip "$string_stripped" "$strip_substr")

    print_string "$string_stripped"
}

string_rstrip_decimal_zeros() { print_string "$@" | sed '/\./ s/\.\{0,1\}0\{1,\}$//'; }

collapse_repeated_substring() { print_string "$1" | sed -r "s|(${2})+|\1|g"; }

string_join() { local IFS="$1"; shift; print_string "$*"; }


## String testing

re_test() {
    local re_test="$1"
    local test_str="$2"

    if [[ $test_str =~ $re_test ]]; then
        echo true
    else
        echo false
    fi
}

string_startswith() { re_test "^${2}" "$1"; }

string_endswith() { re_test "${2}\$" "$1"; }

string_contains() { re_test "${2}" "$1"; }

string_common_prefix() {
    printf "%s\n" "$@" | sed -e '$!{N;s/^\(.*\).*\n\1.*$/\1\n\1/;D;}'
}

string_is_int() { re_test '^-?[0-9]+$' "$1"; }

string_is_posint_or_zero() { re_test '^[0-9]+$' "$1"; }

string_is_negint_or_zero() { re_test '^-[0-9]+$' "$1"; }

string_is_posint() {
    if [ "$(string_is_posint_or_zero "$1")" = true ] && [ "$(re_test '^0+$' "$1")" = false ]; then
        echo true
    else
        echo false
    fi
}

string_is_negint() {
    if [ "$(string_is_negint_or_zero "$1")" = true ] && [ "$(re_test '^-0+$' "$1")" = false ]; then
        echo true
    else
        echo false
    fi
}

string_is_num() { re_test '^-?[0-9]+\.?[0-9]*$' "$1"; }

string_is_posnum_or_zero() { re_test '^[0-9]+\.?[0-9]*$' "$1"; }

string_is_negnum_or_zero() { re_test '^-[0-9]+\.?[0-9]*$' "$1"; }

string_is_posnum() {
    if [ "$(string_is_posnum_or_zero "$1")" = true ] && [ "$(re_test '^0+\.?0*$' "$1")" = false ]; then
        echo true
    else
        echo false
    fi
}

string_is_negnum() {
    if [ "$(string_is_negnum_or_zero "$1")" = true ] && [ "$(re_test '^-0+\.?0*$' "$1")" = false ]; then
        echo true
    else
        echo false
    fi
}

string_is_datenum() { re_test '^[1-2][0-9]{3}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])$' "$1"; }

string_is_pairname() { re_test '^[A-Z0-9]{4}_[0-9]{8}_[0-9A-F]{16}_[0-9A-F]{16}$' "$1"; }


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

    if [ -n "$(env | grep '^TMPDIR=')" ]; then
        if [ ! -d "$TMPDIR" ]; then
            mkdir -p "$TMPDIR"
        fi
    fi

    local tmpfile_out="$(mktemp)"
    local tmpfile_err="$(mktemp)"
    trap "rm -f ${tmpfile_out} ${tmpfile_err}" 0

    { { eval "${cmd_args[@]}" | tee "$tmpfile_out"; } 2>&1 1>&3 | tee "$tmpfile_err"; } 3>&1 1>&2
    status=$?

    eval "${__return_out}=\"$(cat ${tmpfile_out})\""
    eval "${__return_err}=\"$(cat ${tmpfile_err})\""

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

    eval "${__return_out}=\"${cmd_out}\""

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

#indexOf() { local el="$1"; shift; local arr=("$@"); local index=-1; local i; for i in "${!arr[@]}"; do [ "${arr[$i]}" = "$el" ] && { index=$i; break; } done; echo $index; }
indexOf() {
    local el="$1"     # Save first argument in a variable
    shift             # Shift all arguments to the left (original $1 gets lost)
    local arr=("$@")  # Rebuild the array with rest of arguments
    local index=-1

    local i
    for i in "${!arr[@]}"; do
        if [ "${arr[$i]}" = "$el" ]; then
            index=$i
            break
        fi
    done

    echo "$index"
}

itemOneOf() {
    local el="$1"
    shift
    local arr=("$@")

    if (( $(indexOf "$el" ${arr[@]+"${arr[@]}"}) == -1 )); then
        echo false
    else
        echo true
    fi
}

parse_xml_value() {
    local xml_tag="$1"
    local xml_onelinestring=''
    while read -r xml_onelinestring; do
        echo "$xml_onelinestring" | grep -Po "<${xml_tag}>(.*?)</${xml_tag}>" | sed -r "s|<${xml_tag}>(.*?)</${xml_tag}>|\1|"
    done
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
    local hms_hr hms_min hms_sec
    local total_sec

    IFS=: read -r hms_hr hms_min hms_sec <<< "${1%.*}"
    total_sec="$(( 10#$hms_hr*3600 + 10#$hms_min*60 + 10#$hms_sec ))"

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
