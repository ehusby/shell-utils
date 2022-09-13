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

countItemsEqual() {
    local base_el="$1"
    shift
    local comp_arr=("$@")

    local equal_count=0
    for el in "${comp_arr[@]}"; do
        if [ "$el" = "$base_el" ]; then
            ((equal_count++))
        fi
    done

    echo "$equal_count"
}

process_items() {
    local process_func="$1"; shift
    local pipe_in_items="$1"; shift
    local cwd_glob_if_no_items_provided="$1"; shift
    local processed_items=false
    local item
    if (( $# > 0 )); then
        if [ "$pipe_in_items" = true ]; then
            eval "printf '%s\n' \"\$@\" | ${process_func}"
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
escape_string() {
    local str_out=$(printf '%q' "$*")
    if [ "$str_out" == "''" ]; then
        print_string ''
    else
        print_string "$str_out"
    fi
}

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

parent_dir_exists_0() {
    local dirent="$(string_rstrip "$1" '/')"
    local parent_dir="${dirent%/*}"
    [ -d "$parent_dir" ];
}
dirent_is_empty_0() {
    find 2>/dev/null -L "$1" -prune -empty | grep -q '.'
#    { [ -e "$1" ] && [ ! -s "$1" ]; };
}
dir_is_empty_0() {
    find 2>/dev/null -L "$1" -type d -prune -empty | grep -q '.'
#    { [ -d "$1" ] && [ ! -s "$1" ]; };
}
file_is_empty_0() {
#    find 2>/dev/null -L "$1" -type f -prune -empty | grep -q '.'
    { [ -f "$1" ] && [ ! -s "$1" ]; };
}
dirent_not_empty_0() {
    find 2>/dev/null -L "$1" -prune ! -empty | grep -q '.'
#    { [ -e "$1" ] && [ -s "$1" ]; };
}
dir_not_empty_0() {
    find 2>/dev/null -L "$1" -type d -prune ! -empty | grep -q '.'
#    { [ -d "$1" ] && [ -s "$1" ]; };
}
file_not_empty_0() {
#    find 2>/dev/null -L "$1" -type f -prune ! -empty | grep -q '.'
    { [ -f "$1" ] && [ -s "$1" ]; };
}

parent_dir_exists() {
    if parent_dir_exists_0 "$1"; then
        echo true
    else
        echo false
    fi
}
dirent_is_empty() {
    local dirent="$1"
    if [ ! -e "$dirent" ]; then
        echo_e "dirent_is_empty: file/directory does not exist: ${dirent}"
        echo false
        return 1
    elif dirent_is_empty_0 "$dirent"; then
        echo true
        return 0
    else
        echo false
        return 1
    fi
}
dir_is_empty() {
    local dirent="$1"
    if [ ! -d "$dirent" ]; then
        echo_e "dir_is_empty: invalid directory path: ${dirent}"
        echo false
        return 1
    elif dir_is_empty_0 "$dirent"; then
        echo true
        return 0
    else
        echo false
        return 1
    fi
}
file_is_empty() {
    local dirent="$1"
    if [ ! -f "$dirent" ]; then
        echo_e "file_is_empty: invalid file path: ${dirent}"
        echo false
        return 1
    elif file_is_empty_0 "$dirent"; then
        echo true
        return 0
    else
        echo false
        return 1
    fi
}
dirent_not_empty() {
    local dirent="$1"
    if [ ! -e "$dirent" ]; then
        echo_e "dirent_not_empty: file/directory does not exist: ${dirent}"
        echo false
        return 1
    elif dirent_not_empty_0 "$dirent"; then
        echo true
        return 0
    else
        echo false
        return 1
    fi
}
dir_not_empty() {
    local dirent="$1"
    if [ ! -d "$dirent" ]; then
        echo_e "dir_not_empty: invalid directory path: ${dirent}"
        echo false
        return 1
    elif dir_not_empty_0 "$dirent"; then
        echo true
        return 0
    else
        echo false
        return 1
    fi
}
file_not_empty() {
    local dirent="$1"
    if [ ! -f "$dirent" ]; then
        echo_e "file_not_empty: invalid file path: ${dirent}"
        echo false
        return 1
    elif file_not_empty_0 "$dirent"; then
        echo true
        return 0
    else
        echo false
        return 1
    fi
}


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
    local path_prefix="$path"
    local path_suffix=''
    while true; do
        if [ -d "$path_prefix" ]; then
            break
        elif [ "$path_prefix" = '/' ] || [ "$path_prefix" = '.' ]; then
            break
        else
            if [ -z "$path_suffix" ]; then
                path_suffix=$(basename "$path_prefix")
            else
                path_suffix="$(basename "$path_prefix")/${path_suffix}"
            fi
            path_prefix=$(dirname "$path_prefix")
        fi
    done
    cd "$path_prefix" || { echo_e "Failed to access path: ${path_prefix}" ; return; }
    path_prefix=$(eval "$fullpath_fn")
    if [ -z "$path_suffix" ]; then
        echo "$path_prefix"
    elif [ "$path_prefix" = '/' ]; then
        echo "${path_prefix}${path_suffix}"
    else
        echo "${path_prefix}/${path_suffix}"
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
    local readlink_status=1
    if [ "$READLINK_F_AVAILABLE" = true ]; then
        readlink -f "$path"
        readlink_status=$?
    fi
    if (( readlink_status != 0 )); then
        fullpath_alias "$path" true
    fi
}

fullpath_e() {
    if (( $# != 1 )); then
        echo_e "fullpath_e: expected one path operand"
        return 1
    fi
    local path="$1"
    if [ ! -e "$path" ]; then
        echo_e "fullpath_e: path does not exist: ${path}"
        return 1
    fi
    fullpath "$path"
}
abspath_e() {
    if (( $# != 1 )); then
        echo_e "abspath_e: expected one path operand"
        return 1
    fi
    local path="$1"
    if [ ! -e "$path" ]; then
        echo_e "abspath_e: path does not exist: ${path}"
        return 1
    fi
    abspath "$path"
}

fullpath_pe() {
    if (( $# != 1 )); then
        echo_e "fullpath_pe: expected one path operand"
        return 1
    fi
    local path="$1"
    local parent_dir=$(dirname "$path")
    if [ ! -d "$parent_dir" ]; then
        echo_e "fullpath_pe: parent dir does not exist: ${parent_dir}"
        return 1
    fi
    fullpath "$path"
}
abspath_pe() {
    if (( $# != 1 )); then
        echo_e "abspath_pe: expected one path operand"
        return 1
    fi
    local path="$1"
    local parent_dir=$(dirname "$path")
    if [ ! -d "$parent_dir" ]; then
        echo_e "abspath_pe: parent dir does not exist: ${parent_dir}"
        return 1
    fi
    abspath "$path"
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
abspath_all_e() {
    process_items 'abspath_e' false true "$@"
}
fullpath_all_e() {
    process_items 'fullpath_e' false true "$@"
}
derefpath_all() {
    local deref_count="$1"; shift
    process_items "derefpath ${deref_count}" false true "$@"
}
basename_all() {
    process_items 'basename' false true "$@"
}
dirname_all() {
    process_items 'dirname' false true "$@"
}

cut_slice_alias() {
    local func_name="$1"; shift
    local item_type="$1"; shift
    local delimiter="$1"; shift
    local reverse="$1"; shift
    local idx_a idx_b
    local idx_start idx_end

    if (( $# < 1 )); then
        echo_e "${func_name}: first one or two arguments must be nonzero indices from end, like '2-1' or '2 1', respectively"
        return 1
    fi

    if [[ $1 == *-* ]]; then
        idx_a=$(echo "$1" | cut -d'-' -f1)
        idx_b=$(echo "$1" | cut -d'-' -f2)
        shift
    elif (( $# >= 2 )); then
        idx_a="$1"; shift
        idx_b="$1"; shift
    fi

    if [ "$(string_is_posint "$idx_a")" = false ] || [ "$(string_is_posint "$idx_b")" = false ]; then
        echo_e "${func_name}: first one or two arguments must be nonzero indices from end, like '2-1' or '2 1'"
        return 1
    fi
    if ! [[ -p /dev/stdin ]] && (( $# == 0 )); then
        echo_e "${func_name}: expected one or more ${item_type} operands after index arguments, or piped in on separate lines"
        return 1
    fi

    if (( idx_a < idx_b )); then
        idx_start="$idx_a"
        idx_end="$idx_b"
    else
        idx_start="$idx_b"
        idx_end="$idx_a"
    fi

    cmd="cut -d'${delimiter}' -f${idx_start}-${idx_end}"

    if [ "$reverse" = true ]; then
        cmd="rev | ${cmd} | rev"
    fi

    process_items "$cmd" true false "$@"
}
pathfrombegin() {
    cut_slice_alias pathfrombegin 'path' '/' false "$@"
}
pathfromend() {
    cut_slice_alias pathfromend 'path' '/' true "$@"
}
