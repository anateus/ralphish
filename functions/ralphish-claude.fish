function ralphish-claude --description "Ralph Wiggum Loop for Claude Code"
    argparse 't/timeout=' 'c/cmd=' -- $argv
    or return 1

    if test (count $argv) -eq 0
        echo "Usage: ralphish [-t/--timeout MINUTES] [-c/--cmd CMD] <prompt>"
        return 1
    end

    set -l timeout_mins 50
    if set -q _flag_timeout
        set timeout_mins $_flag_timeout
    end

    set -l cli_cmd "claude --dangerously-skip-permissions"
    if set -q _flag_cmd
        set cli_cmd $_flag_cmd
    end

    set -l pidfile /tmp/ralphish.$fish_pid.pid
    echo $fish_pid > $pidfile

    echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] ralphish started"
    echo "  PID: $fish_pid | Timeout: "$timeout_mins"m per round"
    echo "  Graceful stop: rm $pidfile"
    echo "  Hard stop:     kill $fish_pid"
    echo

    set -l timeout_cmd
    if command -q gtimeout
        set timeout_cmd gtimeout
    else if command -q timeout
        set timeout_cmd timeout
    end

    set -l statusline_cmd (jq -r '.statusLine.command // empty' ~/.claude/settings.json 2>/dev/null)

    set -l project_dir_name (string replace -a '/' '-' (pwd))
    set -l project_dir "$HOME/.claude/projects/$project_dir_name"

    set -l session_id ""
    set -l transcript_path ""
    set -l ts_marker /tmp/ralphish_ts_marker.$fish_pid
    touch "$ts_marker"

    set -l status_file /tmp/ralphish_status.$fish_pid.json
    touch "$status_file"

    function _ralphish_detect_session --no-scope-shadowing
        if test -d "$project_dir"
            set -l marker_time (stat -f '%m' "$ts_marker")
            set -l candidates (find "$project_dir" -maxdepth 1 -name '*.jsonl' 2>/dev/null | \
                while read -l f
                    set -l bt (stat -f '%B' "$f")
                    test "$bt" -ge "$marker_time"
                    and echo "$bt $f"
                end | sort -rn)
            for candidate in $candidates
                set -l cfile (string replace -r '^[0-9]+ ' '' -- "$candidate")
                set -l first_user_msg (head -5 "$cfile" | jq -r \
                    'select(.type == "user") | .message.content |
                    if type == "string" then .
                    elif type == "array" then map(select(.type == "text") | .text) | join("")
                    else "" end' 2>/dev/null)
                if string match -rq -- (string escape --style=regex -- "$full_prompt") "$first_user_msg"
                    set session_id (basename "$cfile" .jsonl)
                    set transcript_path "$cfile"
                    return 0
                end
            end
            if test (count $candidates) -gt 0
                set -l cfile (string replace -r '^[0-9]+ ' '' -- "$candidates[1]")
                set session_id (basename "$cfile" .jsonl)
                set transcript_path "$cfile"
                return 0
            end
        end
        return 1
    end

    function _ralphish_update_status --no-scope-shadowing
        if test -n "$statusline_cmd"
            set -l sj '{"workspace":{"current_dir":"'(pwd)'"},"model":{"display_name":"Ralph Loop"},"session_id":"'$session_id'","transcript_path":"'$transcript_path'"}'
            echo "$sj" > "$status_file"
            echo $sj | $statusline_cmd >/dev/null 2>&1
        end
    end

    if test -n "$statusline_cmd"
        set -l max_age (math "$timeout_mins * 60")
        fish -c "
            while test -f '$status_file'
                sleep 180
                test -f '$status_file'; or break
                set -l file_age (math (date +%s) - (stat -f '%m' '$status_file' 2>/dev/null; or echo 0))
                if test \$file_age -ge $max_age
                    break
                end
                cat '$status_file' 2>/dev/null | '$statusline_cmd' >/dev/null 2>&1
            end
            rm -f '$status_file'
        " &
        disown $last_pid 2>/dev/null
    end

    set -l round 1
    set -l prompt_suffix ""
    while test -f $pidfile
        if test -n "$statusline_cmd"; and test -n "$session_id"
            set -l status_output (echo '{"workspace":{"current_dir":"'(pwd)'"},"model":{"display_name":"Ralph Loop"},"session_id":"'$session_id'","transcript_path":"'$transcript_path'"}' | $statusline_cmd 2>/dev/null)
            if test -n "$status_output"
                echo "  $status_output"
            end
        end
        echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Round $round — Running..."

        set -l full_prompt "$argv[1]$prompt_suffix"
        set prompt_suffix ""

        touch "$ts_marker"
        set -l outfile (mktemp)

        if test -n "$timeout_cmd"; and test $timeout_mins -gt 0
            env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT $timeout_cmd {$timeout_mins}m fish -c "$cli_cmd -p "(string escape -- $full_prompt) </dev/null >$outfile 2>&1 &
        else
            env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT fish -c "$cli_cmd -p "(string escape -- $full_prompt) </dev/null >$outfile 2>&1 &
        end
        set -l claude_pid $last_pid

        set -l session_detected false
        set -l poll_interval 2
        while kill -0 $claude_pid 2>/dev/null
            if not test -f $pidfile
                kill $claude_pid 2>/dev/null
                break
            end
            if test "$session_detected" = false
                if _ralphish_detect_session
                    set session_detected true
                    echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Session: $session_id"
                    _ralphish_update_status
                    set poll_interval 10
                end
            end
            sleep $poll_interval
        end

        wait $claude_pid
        set -l claude_exit $status

        if test "$session_detected" = false
            if _ralphish_detect_session
                echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Session: $session_id"
                _ralphish_update_status
            end
        end

        if test -z "$session_id"
            echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Error: unable to detect session after round $round"
            set -l output (string collect < $outfile)
            if test -n "$output"
                echo "Claude output:"
                echo $output | bat --language=md --style=plain --paging=never
            end
            rm -f $pidfile $ts_marker $status_file $outfile
            functions -e _ralphish_detect_session _ralphish_update_status
            return 1
        end

        if test -n "$timeout_cmd"; and test $timeout_mins -gt 0; and test $claude_exit -eq 124
            echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Round $round — Timed out after "$timeout_mins"m"
            set prompt_suffix ". Previous run timed out after $timeout_mins minutes."
        end

        set -l output (string collect < $outfile)
        rm -f $outfile

        echo $output | bat --language=md --style=plain --paging=never
        echo

        if string match -q '*<PROMPT>DONE</PROMPT>*' -- $output
            echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Done."
            rm -f $pidfile $ts_marker
            functions -e _ralphish_detect_session _ralphish_update_status
            return 0
        end

        set round (math $round + 1)
        sleep 5
    end

    rm -f "$ts_marker"
    echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Stopped (pidfile removed)."
    functions -e _ralphish_detect_session _ralphish_update_status
    return 0
end
