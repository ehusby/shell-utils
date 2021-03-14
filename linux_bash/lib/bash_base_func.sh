#!/bin/bash


#function indexOf() { local el="$1"; shift; local arr=("$@"); local index=-1; local i; for i in "${!arr[@]}"; do [ "${arr[$i]}" == "$el" ] && { index=$i; break; } done; echo $index; }

function indexOf() {
    local el="$1"     # Save first argument in a variable
    shift             # Shift all arguments to the left (original $1 gets lost)
    local arr=("$@")  # Rebuild the array with rest of arguments
    local index=-1
    local i
    for i in "${!arr[@]}"; do
        if [ "${arr[$i]}" == "$el" ]; then
            index=$i
            break
        fi
    done
    echo $index
}

