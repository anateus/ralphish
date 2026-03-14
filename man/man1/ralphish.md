ralphish(1) -- loop a CLI command until DONE
=============================================

## SYNOPSIS

`ralphish` [`-t`|`--timeout` <minutes>] [`-c`|`--cmd` <command>] <prompt>

## DESCRIPTION

**ralphish** is a minimal Ralph Wiggum Loop for fish shell. It repeatedly
runs a CLI command with the given prompt until the output contains
`<PROMPT>DONE</PROMPT>`, indicating the task is complete.

Each iteration (round) runs the configured command with the prompt, captures a
full stdout/stderr log, and checks that log for completion. If the round times
out, the next round's prompt is appended with a note about the timeout. Output
from each round is displayed via `bat`.

For the Codex backend, `ralphish-codex` also passes `-o <tempfile>` to `codex
exec` and displays Codex's saved last message by default, prefixed with the
absolute path to the full log file for that round.

Designed for use with Claude Code skills that maintain their own state machines
and output `<PROMPT>DONE</PROMPT>` when they reach a terminal state.

A pidfile is written to `/tmp/ralphish.<pid>.pid` on startup. The loop
continues as long as this file exists.

## OPTIONS

  * `-t`, `--timeout` <minutes>:
    Per-round timeout in minutes. Defaults to 50. Requires `gtimeout` or
    `timeout` to be available on the system.

  * `-c`, `--cmd` <command>:
    The CLI command to run each round. Defaults to the active backend's
    command (`codex exec --dangerously-bypass-approvals-and-sandbox` for
    `ralphish-codex`, `claude --dangerously-skip-permissions` for
    `ralphish-claude`).

## STOPPING

  * **Graceful stop**: Remove the pidfile. The current round finishes, then
    ralphish exits.

        rm /tmp/ralphish.<pid>.pid

  * **Hard stop**: Kill the process directly.

        kill <pid>

Both the pidfile path and PID are printed at startup.

## EXAMPLES

Run with default 50-minute timeout:

    ralphish "Fix the failing tests in src/"

Run with a 10-minute per-round timeout:

    ralphish -t 10 "Refactor the auth module"

Use a custom CLI command:

    ralphish -c "claude --model opus" "Fix the flaky test"

## DEPENDENCIES

  * `codex` and/or `claude` -- depending on the selected backend
  * `bat` -- used to render output
  * `gtimeout` or `timeout` -- optional, for per-round timeouts

## AUTHORS

Michael Katsevman

## SEE ALSO

fish(1), claude(1), codex(1)
