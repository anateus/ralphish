function ralphish-codex --description "Ralph Wiggum Loop for Codex"
    argparse 't/timeout=' 'c/cmd=' -- $argv
    or return 1

    if test (count $argv) -eq 0
        echo "Usage: ralphish-codex [-t/--timeout MINUTES] [-c/--cmd CMD] <prompt>"
        return 1
    end

    set -l timeout_mins 50
    if set -q _flag_timeout
        set timeout_mins $_flag_timeout
    end

    set -l cli_cmd "codex exec --dangerously-bypass-approvals-and-sandbox"
    if set -q _flag_cmd
        set cli_cmd $_flag_cmd
    end

    set -l pidfile /tmp/ralphish.$fish_pid.pid
    echo $fish_pid > $pidfile

    echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] ralphish-codex started"
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

    set -l codex_thread_id ""
    set -l codex_history_file "$HOME/.codex/history.jsonl"
    set -l ts_marker /tmp/ralphish_codex_ts_marker.$fish_pid
    touch "$ts_marker"

    function _ralphish_detect_codex_thread --no-scope-shadowing
        if set -q CODEX_THREAD_ID
            set codex_thread_id "$CODEX_THREAD_ID"
            return 0
        end

        if set -q CODEX_SESSION_ID
            set codex_thread_id "$CODEX_SESSION_ID"
            return 0
        end

        if test -f "$codex_history_file"
            set -l marker_time (stat -f '%m' "$ts_marker" 2>/dev/null; or echo 0)
            set -l recent_id (tail -n 200 "$codex_history_file" | jq -r --argjson marker "$marker_time" 'select((.ts // 0) >= $marker) | .session_id // empty' 2>/dev/null | tail -n 1)
            if test -n "$recent_id"
                set codex_thread_id "$recent_id"
                return 0
            end

            set -l latest_id (tail -n 200 "$codex_history_file" | jq -r '.session_id // empty' 2>/dev/null | tail -n 1)
            if test -n "$latest_id"
                set codex_thread_id "$latest_id"
                return 0
            end
        end

        return 1
    end

    function _ralphish_update_pane_title --no-scope-shadowing
        set -l rename_cmd "$HOME/.local/bin/rename-pane.sh"

        if test -z "$ZELLIJ_PANE_ID"
            return 1
        end

        if test -z "$codex_thread_id"
            return 1
        end

        set -l title_file "$HOME/.codex/session-titles/$codex_thread_id"
        if not test -r "$title_file"
            return 1
        end

        set -l pane_title (string trim -- (string collect < "$title_file"))
        if test -z "$pane_title"
            return 1
        end

        if not test -x "$rename_cmd"
            echo $pane_title
            return 0
        end

        "$rename_cmd" "$ZELLIJ_PANE_ID" "$pane_title" >/dev/null 2>&1
        return 0
    end

    set -l round 1
    set -l prompt_suffix ""
    while test -f $pidfile
        if test -z "$codex_thread_id"
            _ralphish_detect_codex_thread
        end
        _ralphish_update_pane_title

        echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Round $round - Running..."

        set -l full_prompt "$argv[1]$prompt_suffix"
        set prompt_suffix ""

        touch "$ts_marker"
        set -l logfile (mktemp)
        set -l last_message_file (mktemp)
        set -l escaped_last_message_file (string escape -- $last_message_file)
        set -l escaped_prompt (string escape -- $full_prompt)
        set -l round_cmd "$cli_cmd -o $escaped_last_message_file $escaped_prompt"

        if test -n "$timeout_cmd"; and test $timeout_mins -gt 0
            $timeout_cmd {$timeout_mins}m fish -c "$round_cmd" </dev/null >$logfile 2>&1 &
        else
            fish -c "$round_cmd" </dev/null >$logfile 2>&1 &
        end
        set -l codex_pid $last_pid

        while kill -0 $codex_pid 2>/dev/null
            if not test -f $pidfile
                kill $codex_pid 2>/dev/null
                break
            end
            sleep 2
        end

        wait $codex_pid
        set -l codex_exit $status

        if test -z "$codex_thread_id"
            if _ralphish_detect_codex_thread
                echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Thread: $codex_thread_id"
            end
        end
        _ralphish_update_pane_title

        if test -n "$timeout_cmd"; and test $timeout_mins -gt 0; and test $codex_exit -eq 124
            echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Round $round - Timed out after "$timeout_mins"m"
            set prompt_suffix ". Previous run timed out after $timeout_mins minutes."
        end

        set -l output (string collect < $logfile)
        if test -s "$last_message_file"
            begin
                printf 'Full log of this run is at %s\n\n' "$logfile"
                cat "$last_message_file"
            end | bat --language=md --style=plain --paging=never
        else
            printf '%s\n' "$output" | bat --language=md --style=plain --paging=never
        end
        rm -f $last_message_file
        echo

        if string match -q '*<PROMPT>DONE</PROMPT>*' -- $output
            echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Done."
            rm -f $pidfile "$ts_marker"
            functions -e _ralphish_detect_codex_thread _ralphish_update_pane_title
            return 0
        end

        set round (math $round + 1)
        sleep 5
    end

    rm -f "$ts_marker"
    echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Stopped (pidfile removed)."
    functions -e _ralphish_detect_codex_thread _ralphish_update_pane_title
    return 0
end
