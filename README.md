# ralphish

Minimal [Ralph Wiggum Loop](https://ghuntley.com/loop/) for [fish shell](https://github.com/fish-shell/fish-shell).

Loop [Claude Code](https://docs.anthropic.com/en/docs/claude-code) until the task is done. Runs `claude --dangerously-skip-permissions` repeatedly, checking each round's output for a `DONE` signal. Supports per-round timeouts, a configurable CLI command, and graceful cancellation via pidfile.

## Installation

With [Fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install mike/ralphish
```

## Usage

```fish
ralphish "Fix the failing tests in src/"
ralphish -t 10 "Refactor the auth module"
ralphish -c "claude --model opus" "Fix the flaky test"
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-t`, `--timeout` | Per-round timeout in minutes | `30` |
| `-c`, `--cmd` | CLI command to run each round | `claude --dangerously-skip-permissions` |

### Stopping

- **Graceful** — remove the pidfile (printed at startup). Current round finishes, then exits.
- **Hard** — `kill <pid>` (also printed at startup).

### Dependencies

- `claude` (Claude Code CLI)
- `bat`
- `gtimeout` or `timeout` (optional, for per-round timeouts)

## License

[MIT](LICENSE)
