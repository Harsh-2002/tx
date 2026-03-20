# tx

A dead-simple tmux wrapper. No keybindings to memorize — just type what you mean.

## Install

```sh
git clone https://github.com/Harsh-2002/tx.git && cd tx && ./install.sh
```

Or just copy the script:

```sh
curl -fsSL https://raw.githubusercontent.com/Harsh-2002/tx/main/tx -o /usr/local/bin/tx && chmod +x /usr/local/bin/tx
```

## Usage

```
SESSIONS
  tx                      Attach, create, or list sessions (smart default)
  tx new [name]           New session
  tx ls                   List sessions
  tx a [name]             Attach to session
  tx kill [name]          Kill session

PANES
  tx split                Split left/right
  tx vsplit               Split top/bottom
  tx layout <n>           N columns
  tx layout <n> -v        N rows
  tx layout <n> grid      Grid layout
  tx pane <n>             Switch to pane N
  tx close                Close current pane
  tx resize <dir> [n]     Resize (left/right/up/down)
  tx swap <n>             Swap with pane N
  tx full                 Toggle fullscreen

SEND
  tx send <n> '<cmd>'     Run command in pane N

WINDOWS
  tx win [name]           New window
  tx wins                 List windows
  tx next / tx prev       Switch windows
  tx rename <name>        Rename window
```

### Layout with commands

The killer feature — create panes and run commands in one shot:

```sh
tx layout 3 'vim' 'npm run dev' 'htop'
```

This creates 3 columns and runs a command in each one.

```sh
tx layout 4 grid                        # 2x2 grid
tx layout 3 -v 'cmd1' 'cmd2' 'cmd3'     # 3 stacked rows with commands
```

### Smart `tx` (no args)

- No sessions → creates one called "main"
- One session → attaches to it
- Multiple sessions → lists them
- Inside tmux → shows status

## Requirements

- `tmux`
- POSIX shell (`/bin/sh`)

## License

MIT
