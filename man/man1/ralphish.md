ralphish(1) -- loop a CLI command until DONE
=============================================

## SYNOPSIS

`ralphish` [`-t`|`--timeout` <minutes>] [`-c`|`--cmd` <command>] <prompt>

## DESCRIPTION

**ralphish** repeatedly runs a CLI command with the given prompt until the
output contains `<PROMPT>DONE</PROMPT>`, indicating the task is complete.

Each iteration (round) runs `<command> -p <prompt>` and checks the output.
If the round times out, the next round's prompt is appended with a note about
the timeout. Output from each round is displayed via `bat`.

A pidfile is written to `/tmp/ralphish.<pid>.pid` on startup. The loop
continues as long as this file exists.

## OPTIONS

  * `-t`, `--timeout` <minutes>:
    Per-round timeout in minutes. Defaults to 30. Requires `gtimeout` or
    `timeout` to be available on the system.

  * `-c`, `--cmd` <command>:
    The CLI command to run each round. Defaults to
    `claude --dangerously-skip-permissions`.

## STOPPING

  * **Graceful stop**: Remove the pidfile. The current round finishes, then
    ralphish exits.

        rm /tmp/ralphish.<pid>.pid

  * **Hard stop**: Kill the process directly.

        kill <pid>

Both the pidfile path and PID are printed at startup.

## EXAMPLES

Run with default 30-minute timeout:

    ralphish "Fix the failing tests in src/"

Run with a 10-minute per-round timeout:

    ralphish -t 10 "Refactor the auth module"

## DEPENDENCIES

  * `claude` -- Anthropic's Claude Code CLI (default command)
  * `bat` -- used to render output
  * `gtimeout` or `timeout` -- optional, for per-round timeouts

## AUTHORS

Michael Katsevman

## SEE ALSO

fish(1), claude(1)
