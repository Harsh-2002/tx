# tx

A dead-simple tmux wrapper. No keybindings to memorize — just type what you mean.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Harsh-2002/tx/main/install.sh | sh
```

That's it. Downloads `tx`, puts it in your PATH, creates `~/.tmux.conf` with sane defaults, sets up tab completions, done.

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
  tx resize <dir> [n]     Resize (left/right/up/down/even)
  tx swap <n>             Swap with pane N
  tx full                 Toggle fullscreen

SEND
  tx send <n> '<cmd>'     Run command in pane N

SAVE / LOAD
  tx save [name]          Save current layout + commands
  tx load <name>          Restore a saved layout
  tx saves                List saved layouts
  tx rm <name>            Delete a saved layout

WINDOWS
  tx win [name]           New window
  tx wins                 List windows
  tx next / tx prev       Switch windows
  tx rename <name>        Rename window

OTHER
  tx --version            Show version
  tx update               Update tx to latest version
```

### Layout with commands

Create panes and run commands in one shot:

```sh
tx layout 3 'vim' 'npm run dev' 'htop'
```

3 columns, each running a command.

```sh
tx layout 4 grid                        # 2x2 grid
tx layout 3 -v 'cmd1' 'cmd2' 'cmd3'     # 3 stacked rows with commands
```

### Save and load

Save your perfect setup once, restore it anytime:

```sh
tx save backend          # snapshot current layout + commands
tx load backend          # recreate the exact setup
tx saves                 # list all saved layouts
tx rm backend            # delete a save
```

### Smart `tx` (no args)

- No sessions → creates one called "main"
- One session → attaches to it
- Multiple sessions → lists them
- Inside tmux → shows status with pane details

## Requirements

- `tmux`
- `/bin/sh`

## License

MIT
