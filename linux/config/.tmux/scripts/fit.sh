#!/bin/bash

# some useful variables, example value, and description
# client_tty   - /dev/pts/0 - this identifies the client running the script
# session_name - 0          - which session client is connected to
# window_index - 1          - which window the session has visible
# pane_index   - 1          - which pane the session has focused

client=$( tmux display-message -p '#{client_tty}' )
#session=$( tmux display-message -t "$client"  -p '#{session_name}' )
window=$( tmux display-message -t "$client" -p '#{window_index}' )                                                                                   
#pane=$( tmux display-message -p '#{pane_index}' )                                                                                       

#echo "# I am client=$client session=$session window=$window"

success=""
failed=""
for c in $( tmux list-clients -F '#{client_tty}' ) ; do
        if [[ "$client" = "$c" ]] ; then
                # skip client running this script
                continue
        fi
        w=$( tmux display-message -t "$c" -p '#{window_index}' )
        #echo >&2 "# client=$c window=$w"
        if [ "$window" = "$w" ] ; then
                #echo >&2 "# tmux detach-client -t $c"
                if tmux detach-client -t "$c" ; then
                        success="${success} $c"
                else
                        failed="${failed} $c"
                fi
        fi
done

if [ -n "${success}" ] ; then
        msg="Disconnected clients $success"
        [ -n "${failed}" ] && msg="$msg, but failed to disconnect $failed"
elif [ -n "${failed}" ] ; then
        msg="Failed to disconnect clients $failed"
else
        msg="This is the only client viewing window $window"
fi
tmux display-message "$msg"

