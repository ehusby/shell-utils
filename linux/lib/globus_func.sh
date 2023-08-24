#!/bin/bash

## Source base functions
source "$(dirname "${BASH_SOURCE[0]}")/bash_base_func.sh"


globus_xfer_watchdog() {
    local task_name="$1"
    local task_id="$2"
    local dstdir="$3"

    local recent_event_info
    local prev_latest_event=''
    local curr_latest_event=''

    local has_made_progress=false
    local no_event_counter=0
    local no_progress_counter=0

    local stall_issue_characteristic
    local last_progress_event_before_stall
    local attempted_stall_fix=false
    local waiting_for_progress_after_stall_fix=false
    local last_stalled_files_fixed=''
    local last_progress_event

    local email_body
    local emailed_stall_issue=false
    local emailed_noprog_issue=false

    while true; do
        prev_latest_event="$curr_latest_event"
        sleep 5m

        recent_event_info=$(globus task event-list "$task_id")
        curr_latest_event=$(echo "$recent_event_info" | head -n 3 | tail -n 1)

        if echo "$curr_latest_event" | grep -q "PAUSED"; then
            continue
        fi


        if echo "$recent_event_info" | grep -q "PROGRESS"; then
            has_made_progress=true
            no_progress_counter=0
            if [ "$waiting_for_progress_after_stall_fix" = true ]; then
                last_progress_event=$(echo "$recent_event_info" | grep -m1 "PROGRESS")
                if [ -n "$last_progress_event" ] && [ "${last_progress_event}" != "${last_progress_event_before_stall}" ]; then
                    waiting_for_progress_after_stall_fix=false
                    last_stalled_files_fixed=''
                    attempted_stall_fix=false
                fi
            fi
        else
            ((no_progress_counter++))
        fi

        if [ "$curr_latest_event" == "$prev_latest_event" ]; then
            ((no_event_counter++))
        else
            no_event_counter=0
        fi


        if (( no_progress_counter > 0 )) && [ "$emailed_noprog_issue" = false ]; then
            if [ "$has_made_progress" = false ] && (( no_progress_counter >= 12 )); then
                echo "Globus transfer task \"${task_name}\" (${task_id}) has not reported progress within 1 hour after startup" | mail -s "Globus xfer NO PROGRESS - ${task_name}" "$MY_EMAIL"
                emailed_noprog_issue=true
            fi
            if [ "$has_made_progress" = true ] && (( no_progress_counter >= 4 )); then
                echo "Globus transfer task \"${task_name}\" (${task_id}) has not reported progress within the past 20 minutes" | mail -s "Globus xfer NO PROGRESS - ${task_name}" "$MY_EMAIL"
                emailed_noprog_issue=true
            fi
        fi


        if [ "$has_made_progress" = true ] && (( no_event_counter >= 3 )); then

            if echo "$curr_latest_event" | grep -q -E "(SUCCEEDED|PROGRESS)"; then
                stall_issue_characteristic=true
            else
                stall_issue_characteristic=false
            fi

            if [ "$waiting_for_progress_after_stall_fix" = false ]; then
                last_progress_event_before_stall=$(echo "$recent_event_info" | grep -m1 "PROGRESS")

                if [ -d "$dstdir" ] && [ "$stall_issue_characteristic" = true ] && [ "$attempted_stall_fix" = false ]; then
                    # Globus transfer is stalled, possibly due to DTN churning on faulty Vida file
                    # with filesystem metadata stats reporting a file size in the EB range.
                    # Search dstdir for file(s) with size greater than 100TB, remove and replace
                    # with an empty file. Globus transfer should report checksum verification failed
                    # and hopefully soon after replace the empty file with a good copy.
                    echo
                    echo "Detected transfer stall on SUCCEEDED/PROGRESS event"
                    echo "Searching destination directory for faulty files greater than 100TB..."
                    last_stalled_files_fixed=$(find "$dstdir" -type f -size +102400G -ls -exec rm -f {} + -exec touch {} +)
                    if [ -n "$last_stalled_files_fixed" ]; then
                        echo "Fixed the following stalled files:"
                        echo "$last_stalled_files_fixed"
                        waiting_for_progress_after_stall_fix=true
                        no_event_counter=0
                    else
                        echo "No files greater than 100TB found in destination directory"
                    fi
                    attempted_stall_fix=true
                fi
            fi

            if (( no_event_counter >= 4 )) && [ "$emailed_stall_issue" = false ]; then
                if [ "$waiting_for_progress_after_stall_fix" = true ]; then
                    email_body="Globus transfer task \"${task_name}\" (${task_id}) is stalled after last SUCCEEDED/PROGRESS event and has not recovered after attempted fix of faulty files:\n\n${last_stalled_files_fixed}"
                elif [ "$stall_issue_characteristic" = true ]; then
                    email_body="Globus transfer task \"${task_name}\" (${task_id}) is stalled after last SUCCEEDED/PROGRESS event but no faulty files could be found to blame"
                else
                    email_body="Globus transfer task \"${task_name}\" (${task_id}) is stalled after last ERROR event:\n\n${curr_latest_event}"
                fi
                echo -e "$email_body" | mail -s "Globus xfer STALLED - ${task_name}" "$MY_EMAIL"
                emailed_stall_issue=true
            fi
        fi
    done
}


rsync_globus() {
    local disable_pipefail_at_end
    if [ "$(string_contains "$SHELLOPTS" 'pipefail')" = true ]; then
        disable_pipefail_at_end=false
    else
        set -o pipefail
        disable_pipefail_at_end=true
    fi

    if (( $# != 4 )); then
        echo >/dev/stderr "USAGE: SRC DST SYNC_LEVEL(exists|size|mtime|checksum) TASK_NAME"
        return
    fi
    local src="$1"
    local dst="$2"
    local sync_level="$3"
    local task_name="$4"

    local dst_path=$(echo "$dst" | cut -d':' -f2)

    local cmd
    local cmd_out
    local cmd_status

    local task_id=''
    local transfer_rc
    local task_status
    local rc_success=100
    local rc_fail=101

    local error_logdir="${GLOBUS_ERRROR_LOGDIR:-}"
    if [ -z "$error_logdir" ]; then
        error_logdir="$(pwd)/globus_transfer_errorlogs/"
    fi
    if [ ! -e "$error_logdir" ]; then
        mkdir -p "$error_logdir"
    fi

    local check_for_existing_transfer=true

    if [ "$check_for_existing_transfer" = true ]; then
        cmd="globus task list --limit 20 --filter-status ACTIVE --filter-status INACTIVE --filter-label \"${task_name//' '/*}\" --inexact"
        echo -e "Checking for existing transfer with the following command:\n${cmd}"
        exec 5>&1
        cmd_out=$(eval "$cmd" 2>&1 | tee >(cat - >&5))
        cmd_status=$?
        if (( cmd_status != 0 )); then
            echo "Received non-zero exit status (${cmd_status}) from 'globus task list' command"
            echo "Exiting without attempting transfer"
            return "$rc_fail"
        fi

        local col_header_arr col_idx_task_id col_idx_label
        IFS='|' read -r -a col_header_arr <<< "$(echo "$cmd_out" | head -n 1 | string_strip_around_delim '|')"
        col_idx_task_id=$(indexOf 'Task ID' "${col_header_arr[@]}")
        col_idx_label=$(indexOf 'Label' "${col_header_arr[@]}")
        if (( col_idx_task_id == -1 )) || (( col_idx_label == -1 )); then
            echo "Cannot parse header information from output of 'globus task list' command"
            echo "Exiting without attempting transfer"
            return "$rc_fail"
        fi

        local line row_values_arr row_label
        while IFS= read -r line; do
            IFS='|' read -r -a row_values_arr <<< "$line"
            row_task_id="${row_values_arr["$col_idx_task_id"]}"
            row_label="${row_values_arr["$col_idx_label"]}"
            if [ "$row_label" == "$task_name" ]; then
                task_id="$row_task_id"
                break
            fi
        done < <(echo "$cmd_out" | tail -n +3 | string_strip_around_delim '|')

        if [ -n "$task_id" ]; then
            echo "Found Task ID for existing transfer: ${task_id}"
        fi
        echo
    fi

    if [ -z "$task_id" ]; then
#        cmd="globus ls --filter "'\!\~\*'" --format unix \"${src}\""
#        echo -e "Verifying source path with the following command:\n${cmd}"
#        eval "$cmd"
#        cmd_status=$?
#        if (( cmd_status != 0 )); then
#            echo "Received non-zero exit status (${cmd_status}) from 'globus ls' command"
#            echo "Exiting without attempting transfer"
#            return "$rc_fail"
#        fi
#        echo

#        if [ "$(string_endswith "$dst_path" '/')" = true ]; then
#            cmd="globus mkdir ${dst}"
#            echo -e "Creating destination directory with the following command:\n${cmd}"
#            exec 5>&1
#            cmd_out=$(eval "$cmd" 2>&1 | tee >(cat - >&5))
#            cmd_status=$?
#            if (( cmd_status != 0 )); then
#                if echo "$cmd_out" | grep -q 'ExternalError.MkdirFailed.Exists'; then
#                    echo "Ignoring 'globus mkdir' failure due to directory already exists error"
#                else
#                    echo "Received non-zero exit status (${cmd_status}) from 'globus mkdir' command"
#                    echo "Exiting without attempting transfer"
#                    return "$rc_fail"
#                fi
#            fi
#            echo
#        fi

        sleep_sec=10
        deadline=$(date -d "+10 days" "+%Y-%m-%d")
        cmd="globus transfer --label \"${task_name}\" --deadline \"${deadline}\" --recursive --sync-level ${sync_level} --preserve-mtime --verify-checksum --encrypt --jmespath 'task_id' --format unix \"${src}\" \"${dst}\""
        echo -e "Sleeping ${sleep_sec} seconds before submitting Globus transfer with the following command:\n${cmd}"
        sleep ${sleep_sec}s
        task_id=$(eval "$cmd")
        echo
    fi


#    # Start background process to watch for and fix some transfer issues
#    if [ -e "$dst_path" ]; then
#        globus_xfer_watchdog "$task_name" "$task_id" "$dst_path" &
#        watchdog_pid=$!
#    fi

    cmd="globus task wait --heartbeat --polling-interval 300 --format unix ${task_id}"
    echo -e "Waiting for Globus transfer to complete with the following command:\n${cmd}"
    eval "$cmd"
    transfer_rc=$?
    echo

#    # Kill watchdog background process
#    kill ${watchdog_pid}


    if (( transfer_rc == 0 )); then
        task_status="SUCCESS"
    else
        task_status="FAILED"
    fi

    echo "Globus transfer task \"${task_name}\" (${task_id}) final status: ${task_status} ('globus task wait' exit status ${transfer_rc})"
    echo

    cmd="globus task event-list --filter-errors --format json ${task_id}"
    echo -e "Checking for errors in transfer with the following command:\n${cmd}"
    exec 5>&1
    cmd_out=$(eval "$cmd" 2>&1 | tee >(cat - >&5))
    cmd_status=$?
    if (( cmd_status != 0 )); then
        echo "Received non-zero exit status (${cmd_status}) from 'globus task event-list' command"
    fi
    if [ -n "$cmd_out" ]; then
        transfer_error_logfile="${error_logdir}/${task_name// /_}.txt"
        echo -e "Sending error messages to the following log file:\n${transfer_error_logfile}"
        echo "$cmd_out" >> "$transfer_error_logfile"
    fi
    echo

    if [ "$disable_pipefail_at_end" = true ]; then
        set +o pipefail
    fi

    if (( transfer_rc == 0 )); then
        return "$rc_success"
    else
        return "$rc_fail"
    fi
}


globus_rm_pgc() {
    if (( $# != 2 )); then
        echo >/dev/stderr "USAGE: PATH TASK_NAME"
        return
    fi
    local rm_path="$1"
    local task_name="$2"
    local task_id
    echo "Deleting PGC path:"
    echo "    ${rm_path}"
#    rm_path_adj=$(echo "$rm_path" | sed -r -e 's|^/+mnt/+pgc/+|/|' -e 's|^/project/vida/+|/data/|')
#    if [ "$rm_path" != "$rm_path_adj" ]; then
#        echo "Adjusted path to Globus endpoint mount location:"
#        echo "    ${rm_path_adj}"
#        rm_path="$rm_path_adj"
#    fi
    sleep_sec=8
    echo "Sleeping ${sleep_sec} seconds before submitting delete task"
    sleep "$sleep_sec"
    task_id="$(globus delete "${GLOBUS_UMN_PGC}:${rm_path}" --label "${task_name}" --recursive --jmespath 'task_id' --format unix)"
    echo "Waiting on ${task_id}"
    globus task wait "$task_id"
}

globus_transfer_alias() {
    if (( $# != 4 )); then
        echo >/dev/stderr "USAGE: SRC DST SYNC_LEVEL(exists|size|mtime|checksum) TASK_NAME"
        return
    fi
    local src="$1"
    local dst="$2"
    local sync_level="$3"
    local task_name="$4"
#    wrap_cmd_set_pipefail rsync_globus "$src" "$dst" "$sync_level" "$task_name"
    rsync_globus "$src" "$dst" "$sync_level" "$task_name"
}

globus_pgc_to_pgc() {
    local src="${1:-}"; shift
    local dst="${1:-}"; shift
#    src=$(echo "$src" | sed -r -e 's|^/+mnt/+pgc/+|/|' -e 's|^/project/vida/+|/data/|')
#    dst=$(echo "$dst" | sed -r -e 's|^/+mnt/+pgc/+|/|' -e 's|^/project/vida/+|/data/|')
    globus_transfer_alias "${GLOBUS_UMN_PGC}:${src}" "${GLOBUS_UMN_PGC}:${dst}" "$@"
}
