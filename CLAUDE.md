# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`tx` is a dead-simple tmux wrapper written as a single POSIX shell script (`/bin/sh`). It provides human-friendly commands for tmux session, pane, window, and layout management. The entire tool is two files: `tx` (the script) and `install.sh`.

## Development

- **Lint:** `shellcheck tx install.sh`
- **Test:** `sh test_tx.sh` (173 tests — requires tmux; creates/destroys temporary sessions)
- **Run locally:** `./tx` (requires tmux installed)
- **Install locally:** `./install.sh`

## Architecture

- **`tx`** — The entire tool. Structured top-to-bottom as:
  1. `set -e`, `TX_VERSION`, and `TX_SAVE_DIR` (both overridable via env)
  2. `setup_colors()` — auto-detects terminal color support; disables when piped or `TERM=dumb`
  3. Helpers: `ensure_tmux`, `in_tmux` (checks `$TMUX`), `auto_name` (generates `tx-XXXXX`), `pane_index` (converts 1-indexed CLI to 0-indexed tmux), `die`
  4. `cmd_*` functions — one per subcommand. Many have dual paths for inside/outside tmux (e.g., `cmd_layout` creates a new session when outside tmux, splits in the current session when inside)
  5. `cmd_version` / `cmd_update` — version display and self-update from GitHub
  6. `cmd_help` + `cmd_help_detail` — all help text is inline heredocs, not in a separate file
  7. Main dispatch: two `case` blocks — first handles `--version`/`-v`/`version`/`update`/`help` (no tmux required), second dispatches all tmux commands after `ensure_tmux`

- **Save file format** (`~/.config/tx/saves/<name>`):
  - Line 1: tmux layout string from `#{window_layout}`
  - Lines 2+: `<directory>|<command>` per pane (command is empty if pane is at a shell prompt)
  - `cmd_save` detects running commands via `ps` child-process lookup on `#{pane_pid}`

- **`install.sh`** (308 lines) — Downloads `tx` into `/usr/local/bin` (or `~/.local/bin` as fallback), adds to PATH in shell rc files, and installs tab completions for zsh, bash, and fish

## Conventions

- POSIX `sh` only — no bashisms. Validate with `shellcheck`.
- Local variables use underscore prefix (`_name`, `_count`) since POSIX sh has no `local` scoping. Globals use `UPPER_CASE`.
- Panes are 1-indexed in the user-facing CLI but converted to tmux's 0-index internally via `pane_index()`.
- `set -e` is active — functions use `die()` for error exits; guard patterns like `in_tmux || die "..."` are used throughout.
- Argument validation order: validate args first, then check `in_tmux`. This gives a useful "usage:" message even outside tmux.
- Shell completions (zsh/bash/fish) are embedded directly in `install.sh`, not separate files.
- `cmd_layout` uses `eval "set -- ..."` to reparse args after stripping flags — commands containing `$`, backticks, or double quotes may be expanded prematurely by eval before being sent to panes.
