# CLAUDE.md — Source of Truth

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

`tx` is a dead-simple tmux wrapper written as a single POSIX shell script (`/bin/sh`). It provides human-friendly commands for tmux session, pane, window, and layout management.

**Files:**
- `tx` — Main script (~962 lines)
- `install.sh` — Installer (~334 lines)

**Requirements:**
- `tmux` installed on system
- `/bin/sh` (POSIX shell)

---

## Installation

### Quick Install
```sh
curl -fsSL https://raw.githubusercontent.com/Harsh-2002/tx/main/install.sh | sh
```

### What happens on install:
1. Downloads `tx` to `/usr/local/bin` or `~/.local/bin`
2. Adds to PATH in shell rc files (`.zshrc`, `.bashrc`, etc.)
3. Creates `~/.tmux.conf` with sane defaults (if not exists)
4. Installs tab completions for zsh, bash, and fish
5. Auto-reloads shell config

### Uninstall
```sh
rm /usr/local/bin/tx  # or ~/.local/bin/tx
# Remove PATH entry from shell rc files manually
# Remove ~/.config/tx/ for saves
```

---

## Commands (24 total)

### Session Commands
| Command | Description |
|---------|-------------|
| `tx` | Smart default — attach/create/list sessions |
| `tx new [name]` | Create new session (auto-names if omitted) |
| `tx ls` | List all sessions |
| `tx a [name]` | Attach to session |
| `tx detach` | Detach from current session |
| `tx kill [name]` | Kill session |

### Pane Commands
| Command | Description |
|---------|-------------|
| `tx split` | Split left/right |
| `tx vsplit` | Split top/bottom |
| `tx pane <n>` | Switch to pane N (1-indexed) |
| `tx close` | Close current pane |
| `tx resize <dir> [n]` | Resize pane (left/right/up/down/even) |
| `tx swap <n>` | Swap with pane N |
| `tx full` | Toggle fullscreen |

### Send Commands
| Command | Description |
|---------|-------------|
| `tx send <n> '<cmd>'` | Run command in pane N |
| `tx send-all '<cmd>'` | Broadcast to all panes |

### Layout Commands
| Command | Description |
|---------|-------------|
| `tx layout <n>` | N columns |
| `tx layout <n> -v` | N rows |
| `tx layout <n> grid` | N panes in grid |
| `tx layout <n> [cmds...]` | Create panes and run commands |

### Save/Load Commands
| Command | Description |
|---------|-------------|
| `tx save [name]` | Save current layout + commands |
| `tx load <name>` | Restore saved layout |
| `tx saves` | List saved layouts |
| `tx rm <name>` | Delete saved layout |

### Window Commands
| Command | Description |
|---------|-------------|
| `tx win [name]` | Create new window |
| `tx wins` | List windows |
| `tx next` | Next window |
| `tx prev` | Previous window |
| `tx rename <name>` | Rename window |

### Other Commands
| Command | Description |
|---------|-------------|
| `tx help` | Show help |
| `tx --version` | Show version |
| `tx update` | Update tx to latest |

---

## Development

- **Lint:** `shellcheck tx install.sh`
- **Run locally:** `./tx` (requires tmux)
- **Install locally:** `./install.sh`

---

## Architecture

### `tx` Structure
1. `set -e`, `TX_VERSION`, and `TX_SAVE_DIR` (both overridable via env)
2. `setup_colors()` — auto-detects terminal color support; disables when piped
3. Helper functions: `ensure_tmux`, `in_tmux`, `auto_name`, `pane_index`, `die`
4. `cmd_*` functions — one per subcommand. Many have dual paths for inside/outside tmux
5. `cmd_version` / `cmd_update` — version and self-update
6. `cmd_help` + `cmd_help_detail` — inline heredocs
7. Main dispatch: two `case` blocks — first handles non-tmux commands, second dispatches tmux commands

### Save File Format
`~/.config/tx/saves/<name>`:
- Line 1: tmux layout string from `#{window_layout}`
- Lines 2+: `<directory>|<command>` per pane (command empty if at shell prompt)
- `cmd_save` detects running commands via `ps` child-process lookup on `#{pane_pid}`

### Auto-Naming Priority
1. Current directory name (sanitized)
2. "main" fallback
3. Random animal name: `tx-{fox,owl,lynx,puma,yak,emu,cobra,raven,...}`

### Default tmux Config (`~/.tmux.conf`)
```sh
set -g mouse on
set -g history-limit 50000
set -sg escape-time 0
set -g renumber-windows on
set -g default-terminal "screen-256color"
```

---

## Conventions

- **POSIX sh only** — no bashisms. Validate with `shellcheck`.
- **Local variables** use underscore prefix (`_name`) — POSIX sh has no `local` keyword. Globals use `UPPER_CASE`.
- **Panes are 1-indexed** in CLI but 0-indexed in tmux — converted via `pane_index()`.
- **`set -e` is active** — use `die()` for error exits; guard patterns like `in_tmux || die "..."`
- **Argument validation order** — validate args first, then check `in_tmux` (gives useful usage message outside tmux)
- **Shell completions** embedded in `install.sh`, not separate files
- **`cmd_layout` uses `eval`** — commands with `$`, backticks, or double quotes may expand prematurely

---

## Key Behaviors

### Smart Default (`tx` with no args)
- No sessions → creates "main"
- One session → attaches to it
- Multiple sessions → lists them
- Inside tmux → shows status (session, windows, panes)

### tmux Config Auto-Loading
- On first install: `~/.tmux.conf` created automatically
- On re-run: skipped if config exists (preserves user config)
- Config loads automatically when tmux server starts

### Layout with Commands
```sh
tx layout 3 'vim' 'npm run dev' 'htop'  # 3 columns with commands
tx layout 4 grid                        # 2x2 grid
tx layout 3 -v 'cmd1' 'cmd2' 'cmd3'     # 3 rows
```

### Save/Load Workflow
```sh
tx save backend    # snapshot current layout + commands
tx load backend   # recreate exact setup
tx saves          # list all saved layouts
tx rm backend     # delete a save
```

---

## Testing

No test suite — relies on shellcheck validation and manual testing.

---

## Version History

See `git log` for complete history. Current version defined in `tx` as `TX_VERSION`.