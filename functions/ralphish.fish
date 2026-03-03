function ralphish --description "Loop yolo-claude until DONE"
    argparse 't/timeout=' 'c/cmd=' -- $argv
    or return 1

    if test (count $argv) -eq 0
        echo "Usage: ralphish [-t/--timeout MINUTES] [-c/--cmd CMD] <prompt>"
        return 1
    end

    set -l timeout_mins 30
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
    echo "  PID: $fish_pid | Timeout: {$timeout_mins}m per round"
    echo "  Graceful stop: rm $pidfile"
    echo "  Hard stop:     kill $fish_pid"
    echo

    set -l timeout_cmd
    if command -q gtimeout
        set timeout_cmd gtimeout
    else if command -q timeout
        set timeout_cmd timeout
    end

    set -l round 1
    set -l prompt_suffix ""
    while test -f $pidfile
        echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Round $round — Running..."

        set -l full_prompt "$argv[1]$prompt_suffix"
        set prompt_suffix ""

        set -l outfile (mktemp)
        if test -n "$timeout_cmd"; and test $timeout_mins -gt 0
            $timeout_cmd {$timeout_mins}m fish -c "$cli_cmd -p "(string escape -- $full_prompt) >$outfile 2>&1
            if test $status -eq 124
                echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Round $round — Timed out after {$timeout_mins}m"
                set prompt_suffix ". Previous run timed out after $timeout_mins minutes."
            end
        else
            eval $cli_cmd -p $full_prompt >$outfile 2>&1
        end
        set -l output (string collect < $outfile)
        rm -f $outfile

        echo $output | bat --language=md --style=plain --paging=never
        echo

        if string match -q '*<PROMPT>DONE</PROMPT>*' -- $output
            echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Done."
            rm -f $pidfile
            return 0
        end

        set round (math $round + 1)
        sleep 5
    end

    echo "["(date -u +"%Y-%m-%dT%H:%M:%SZ")"] Stopped (pidfile removed)."
    return 0
end
