# ralphish

Minimal [Ralph Wiggum Loop](https://ghuntley.com/loop/) for [fish shell](https://github.com/fish-shell/fish-shell).

Loop an agent CLI until the task is done. `ralphish` dispatches to either Claude (`ralphish-claude`) or Codex (`ralphish-codex`) based on the fish variable `_ralphish_type`.

I use this with skills that maintain their own state machines and output `<PROMPT>DONE</PROMPT>` when they reach a terminal state. If you don't have a skill like that, ask Claude to write you one.

## Installation

With [Fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install anateus/ralphish
```

On install, Fisher triggers `ralphish_install` and prompts for backend selection (`codex` or `claude`). This sets `_ralphish_type` as a universal fish variable.

## Usage

```fish
ralphish "Fix the failing tests in src/"
ralphish -t 10 "Refactor the auth module"
ralphish -c "codex exec --model gpt-5-codex --dangerously-bypass-approvals-and-sandbox" "Fix the flaky test"
```

### Backend Selection

`ralphish` checks `_ralphish_type`:

- `codex` -> runs `ralphish-codex` (default command: `codex exec --dangerously-bypass-approvals-and-sandbox`)
- `claude` -> runs `ralphish-claude` (default command: `claude --dangerously-skip-permissions`)

Set it manually anytime:

```fish
set -U _ralphish_type codex
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-t`, `--timeout` | Per-round timeout in minutes | `30` |
| `-c`, `--cmd` | CLI command to run each round | backend-specific (`codex exec --dangerously-bypass-approvals-and-sandbox` or `claude --dangerously-skip-permissions`) |

### Stopping

- **Graceful** — remove the pidfile (printed at startup). Current round finishes, then exits.
- **Hard** — `kill <pid>` (also printed at startup).

### Dependencies

- `codex` and/or `claude` (depending on `_ralphish_type`)
- `bat`
- `gtimeout` or `timeout` (optional, for per-round timeouts)

## License

[MIT](LICENSE)
