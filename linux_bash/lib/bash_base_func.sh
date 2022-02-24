#!/bin/bash


## Array/item parsing

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

process_items() {
    local process_func="$1"; shift
    local pipe_in_items="$1"; shift
    local cwd_glob_if_no_items_provided="$1"; shift
    local processed_items=false
    local item
    if (( $# > 0 )); then
        if [ "$pipe_in_items" = true ]; then
            eval "printf '%s\n' \"$@\" | ${process_func}"
            while (( $# > 0 )); do shift; done
        else
            while (( $# > 0 )); do
                item="$1"
                eval "${process_func} \"${item}\""
                shift
            done
        fi
        processed_items=true
    fi
    if [[ -p /dev/stdin ]]; then
        if [ "$pipe_in_items" = true ]; then
            eval "$process_func"
        else
            while IFS= read -r item; do
                eval "${process_func} \"${item}\""
            done
        fi
        processed_items=true
    fi
    if [ "$processed_items" = false ] && [ "$cwd_glob_if_no_items_provided" = true ]; then
        if [ "$pipe_in_items" = true ]; then
            eval "printf '%s\n' * | ${process_func}"
        else
            for item in *; do
                eval "${process_func} \"${item}\""
            done
        fi
    fi
}


## Printing

print_string() { printf '%s' "$*"; }

echo_e()  { echo "$@" >&2; }
echo_oe() { echo "$@" | tee >(cat >&2); }


## String manipulation

base10() { print_string "$((10#$1))"; }

escape_regex_special_chars() {
    local special_chars_arr=( '^' '.' '+' '*' '?' '|' '/' '\\' '(' ')' '[' ']' '{' '}' '$' )
    local str_in="$1"
    local str_out=''
    local i char
    for (( i=0; i<${#str_in}; i++ )); do
        char="${str_in:$i:1}"
        if [ "$(itemOneOf "$char" "${special_chars_arr[@]}")" = true ]; then
            char="\\${char}"
        fi
        str_out="${str_out}${char}"
    done
    echo "$str_out"
}

string_to_uppercase() { print_string "$@" | tr '[:lower:]' '[:upper:]'; }
string_to_lowercase() { print_string "$@" | tr '[:upper:]' '[:lower:]'; }

#string_lstrip() { print_string "$1" | sed -r "s/^($(escape_regex_special_chars "$2"))+//"; }
#string_rstrip() { print_string "$1" | sed -r "s/($(escape_regex_special_chars "$2"))+$//"; }

string_lstrip() {
    local string_in="$1"
    local strip_substr=''
    local string_stripped=''

    if (( $# >= 2 )) && [ -n "$2" ]; then
        strip_substr="$(escape_regex_special_chars "$2")"
    else
        strip_substr='[[:space:]]'
    fi

    string_stripped=$(print_string "$string_in" | sed -r "s/^($(print_string "$strip_substr"))+//")

    print_string "$string_stripped"
}

string_rstrip() {
    local string_in="$1"
    local strip_substr=''
    local string_stripped=''

    if (( $# >= 2 )) && [ -n "$2" ]; then
        strip_substr="$(escape_regex_special_chars "$2")"
    else
        strip_substr='[[:space:]]'
    fi

    string_stripped=$(print_string "$string_in" | sed -r "s/($(print_string "$strip_substr"))+$//")

    print_string "$string_stripped"
}

string_strip() {
    local string_in="$1"
    local strip_substr=''
    local string_stripped=''

    if (( $# >= 2 )); then
        strip_substr="$2"
    else
        strip_substr=''
    fi

    string_stripped=$(string_lstrip "$string_in" "$strip_substr")
    string_stripped=$(string_rstrip "$string_stripped" "$strip_substr")

    print_string "$string_stripped"
}

string_strip_around_delim() {
    local string_in delim strip_substr

    strip_substr=''

    if [[ -p /dev/stdin ]]; then
        delim="$1"
        if (( $# >= 2 )); then
            strip_substr="$2"
        fi
    else
        string_in="$1"
        delim="$2"
        if (( $# >= 3 )); then
            strip_substr="$3"
        fi
    fi

    delim="$(escape_regex_special_chars "$delim")"
    if [ -n "$strip_substr" ]; then
        strip_substr="$(escape_regex_special_chars "$strip_substr")"
    else
        strip_substr='[[:space:]]'
    fi

    local sed_cmd="sed -r 's/^(${strip_substr})*//; s/(${strip_substr})*${delim}(${strip_substr})*/${delim}/g; s/(${strip_substr})*$//;'"

    if [[ -p /dev/stdin ]]; then
        eval "$sed_cmd"
    else
        eval "print_string \"${string_in}\" | ${sed_cmd}"
    fi
}

string_rstrip_decimal_zeros() { print_string "$@" | sed '/\./ s/\.\{0,1\}0\{1,\}$//'; }

collapse_repeated_substring() { print_string "$1" | sed -r "s/($(escape_regex_special_chars "$2"))+/\1/g"; }

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
re_test_0() { [ "$(re_test "$@")" = true ]; }

string_startswith() { re_test "^$(escape_regex_special_chars "$2")" "$1"; }
string_endswith() { re_test "$(escape_regex_special_chars "$2")\$" "$1"; }
string_contains() { re_test "$(escape_regex_special_chars "$2")" "$1"; }

string_is_int() {            re_test '^-?[0-9]+$' "$1"; }
string_is_posint_or_zero() { re_test   '^[0-9]+$' "$1"; }
string_is_negint_or_zero() { re_test  '^-[0-9]+$' "$1"; }

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

string_is_num() {            re_test '^-?[0-9]+\.?[0-9]*$' "$1"; }
string_is_posnum_or_zero() { re_test   '^[0-9]+\.?[0-9]*$' "$1"; }
string_is_negnum_or_zero() { re_test  '^-[0-9]+\.?[0-9]*$' "$1"; }

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


## String parsing

string_common_prefix() {
    printf "%s\n" "$@" | sed -e '$!{N;s/^\(.*\).*\n\1.*$/\1\n\1/;D;}'
}

parse_xml_value() {
    local xml_tag=$(escape_regex_special_chars "$1")
    grep -Po "<${xml_tag}>(.*?)</${xml_tag}>" | sed -r "s/<${xml_tag}>(.*?)</${xml_tag}>/\1/"
}


## Filesystem path testing

parent_dir_exists() {
    local dirent="$(string_rstrip "$1" '/')"
    local parent_dir="${dirent%/*}"
    if [ -d "$parent_dir" ]; then
        echo true
    else
        echo false
    fi
}

dirent_is_empty() {
    local dirent="$1"
    if [ ! -e "$dirent" ]; then
        echo_e "Path does not exist: ${dirent}"
        echo false
    elif [ -n "$(find "$1" -prune -empty)" ]; then
        echo true
    else
        echo false
    fi
}
file_is_empty() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo_e "Invalid file path: ${file}"
        echo false
    else
        dirent_is_empty "$file"
    fi
}
dir_is_empty() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo_e "Invalid directory path: ${dir}"
        echo false
    else
        dirent_is_empty "$dir"
    fi
}

dirent_is_empty_0() { [ "$(dirent_is_empty "$@")" = true ]; }
file_is_empty_0() { [ "$(file_is_empty "$@")" = true ]; }
dir_is_empty_0() { [ "$(dir_is_empty "$@")" = true ]; }


## Path representation

if readlink -f ~ 1>/dev/null 2>/dev/null; then
    READLINK_F_AVAILABLE=true
else
    READLINK_F_AVAILABLE=false
fi

fullpath_alias() {
    local path="$1"
    local dereference_symlinks="$2"
    if [ "$dereference_symlinks" = true ]; then
        fullpath_fn="pwd -P"
    else
        fullpath_fn="pwd"
    fi
    pushd . >/dev/null
    if [ -d "$path" ]; then
        cd "$path" || { echo "Failed to access path" ; return; }
        eval "$fullpath_fn"
    else
        cd "$(dirname "$path")" || { echo "Failed to access path" ; return; }
        local path_parent_dir=$(eval "$fullpath_fn")
        local path_basename=$(basename "$path")
        if [ "$path_parent_dir" = '/' ]; then
            echo "${path_parent_dir}${path_basename}"
        else
            echo "${path_parent_dir}/${path_basename}"
        fi
    fi
    popd >/dev/null
}

fullpath() {
    if (( $# != 1 )); then
        echo_e "fullpath: expected one path operand"
        return 1
    fi
    local path="$1"
    fullpath_alias "$path" false
}
abspath() {
    if (( $# != 1 )); then
        echo_e "abspath: expected one path operand"
        return 1
    fi
    local path="$1"
    if [ "$READLINK_F_AVAILABLE" = true ]; then
        readlink -f "$path"
    else
        fullpath_alias "$path" true
    fi
}

preserve_trailing_slash_alias() {
    if (( $# != 2 )); then
        echo_e "preserve_trailing_slash_alias: expected a path function name and one path operand"
        return 1
    fi
    local path_fn="$1"
    local path_in="$2"
    local path_out=$(eval "${path_fn} \"$path_in\"")
    if [ "$(string_endswith "$path_in" '/')" = true ]; then
        if [ "$(string_endswith "$path_out" '/')" = false ]; then
            path_out="${path_out}/"
        fi
    elif [ "$(string_endswith "$path_out" '/')" = true ]; then
        path_out=$(string_rstrip "$path_out" '/')
    fi
    echo "$path_out"
}

fullpath_preserve_trailing_slash() {
    if (( $# != 1 )); then
        echo_e "fullpath_preserve_trailing_slash: expected one path operand"
        return 1
    fi
    preserve_trailing_slash_alias 'fullpath' "$1"
}
abspath_preserve_trailing_slash() {
    if (( $# != 1 )); then
        echo_e "abspath_preserve_trailing_slash: expected one path operand"
        return 1
    fi
    abspath_trailing_slash_alias 'fullpath' "$1"
}

derefpath() {
    local deref_count="$1"; shift
    if [ "$(string_is_posint "$deref_count")" = false ]; then
        echo_e "derefpath: first argument must be nonzero deref count"
        return 1
    fi
    if (( $# != 1 )); then
        echo_e "derefpath: expected one path operand"
        return 1
    fi
    local path_temp=$(fullpath "$1")
    local path_link=''
    local path_suffix=''
    while (( deref_count > 0 )) && [ "$path_temp" != '/' ]; do
        path_link=$(readlink "$path_temp")
        if [ -n "$path_link" ]; then
            path_temp="$path_link"
            ((deref_count--))
        else
            path_suffix="$(basename "$path_temp")/${path_suffix}"
            path_temp=$(dirname "$path_temp")
        fi
    done
    echo "/$(string_strip "${path_temp}/${path_suffix}" '/')"
}

abspath_all() {
    process_items 'abspath' false true "$@"
}
fullpath_all() {
    process_items 'fullpath' false true "$@"
}
basename_all() {
    process_items 'basename' false true "$@"
}
dirname_all() {
    process_items 'dirname' false true "$@"
}

pathfromend() {
    if (( $# < 1 )); then
        echo_e "fullpath_preserve_trailing_slash: expected one path operand"
        return 1
    fi
    local start_idx end_idx
    if [[ $1 == *-* ]]; then
        start_idx=$(echo "$1" | cut -d'-' -f1)
        end_idx=$(echo "$1" | cut -d'-' -f2)
        shift
    elif (( $# >= 2 )); then
        start_idx="$1"; shift
        end_idx="$1"; shift
    fi
    if [ "$(string_is_posint "$start_idx")" = false ] || [ "$(string_is_posint "$end_idx")" = false ]; then
        echo_e "pathfromend: first one or two arguments must be nonzero indices from end, like '2-1' or '2 1'"
        return 1
    fi
    if ! [[ -p /dev/stdin ]] && (( $# == 0 )); then
        echo_e "pathfromend: expected one or more path operand after index arguments"
        return 1
    fi
    if (( start_idx < end_idx )); then
        local temp_idx="$start_idx"
        start_idx="$end_idx"
        end_idx="$temp_idx"
    fi
    start_idx="-${start_idx}"
    cmd="rev | cut -d'/' -f${end_idx}${start_idx} | rev"
    process_items "$cmd" true false "$@"
}
