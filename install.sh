#!/bin/sh
# tx installer — copies tx to your PATH and sets up shell completions
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TX_SOURCE="${SCRIPT_DIR}/tx"

# --- Helpers ---

info() {
    printf '  \033[1;32m✓\033[0m %s\n' "$1"
}

warn() {
    printf '  \033[1;33m!\033[0m %s\n' "$1"
}

fail() {
    printf '  \033[1;31m✗\033[0m %s\n' "$1" >&2
    exit 1
}

# --- Determine install directory ---

if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
else
    mkdir -p "$HOME/.local/bin"
    INSTALL_DIR="$HOME/.local/bin"
fi

# --- Install the script ---

cp "$TX_SOURCE" "${INSTALL_DIR}/tx"
chmod +x "${INSTALL_DIR}/tx"
info "Installed tx to ${INSTALL_DIR}/tx"

# --- Shell completions ---

TX_COMMANDS="new ls a attach detach kill split vsplit pane close resize swap full send layout win wins next prev rename help"

install_bash_completion() {
    _comp_dir=""
    if [ -d "/usr/local/etc/bash_completion.d" ] && [ -w "/usr/local/etc/bash_completion.d" ]; then
        _comp_dir="/usr/local/etc/bash_completion.d"
    elif [ -d "/etc/bash_completion.d" ] && [ -w "/etc/bash_completion.d" ]; then
        _comp_dir="/etc/bash_completion.d"
    else
        _comp_dir="$HOME/.local/share/bash-completion/completions"
        mkdir -p "$_comp_dir"
    fi

    cat > "${_comp_dir}/tx" <<'BASH_COMP'
_tx_completions() {
    local cur prev commands
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    commands="new ls a attach detach kill split vsplit pane close resize swap full send layout win wins next prev rename help"

    case "$prev" in
        tx)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            return
            ;;
        a|attach|kill)
            local sessions
            sessions=$(tmux list-sessions -F '#S' 2>/dev/null)
            COMPREPLY=($(compgen -W "$sessions" -- "$cur"))
            return
            ;;
        resize)
            COMPREPLY=($(compgen -W "left right up down" -- "$cur"))
            return
            ;;
        help)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            return
            ;;
        layout)
            COMPREPLY=($(compgen -W "2 3 4 5 6" -- "$cur"))
            return
            ;;
    esac

    # After layout count, suggest flags
    if [ "${COMP_WORDS[1]}" = "layout" ] && [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=($(compgen -W "-v grid" -- "$cur"))
        return
    fi
}
complete -F _tx_completions tx
BASH_COMP
    info "Bash completions installed to ${_comp_dir}/tx"
}

install_zsh_completion() {
    _comp_dir=""
    if [ -d "/usr/local/share/zsh/site-functions" ] && [ -w "/usr/local/share/zsh/site-functions" ]; then
        _comp_dir="/usr/local/share/zsh/site-functions"
    elif [ -d "$HOME/.zsh/completions" ]; then
        _comp_dir="$HOME/.zsh/completions"
    else
        _comp_dir="$HOME/.zsh/completions"
        mkdir -p "$_comp_dir"
    fi

    cat > "${_comp_dir}/_tx" <<'ZSH_COMP'
#compdef tx

_tx_sessions() {
    local sessions
    sessions=(${(f)"$(tmux list-sessions -F '#S' 2>/dev/null)"})
    _describe 'session' sessions
}

_tx() {
    local -a commands
    commands=(
        'new:Create a new session'
        'ls:List sessions'
        'a:Attach to session'
        'attach:Attach to session'
        'detach:Detach from session'
        'kill:Kill a session'
        'split:Split pane left/right'
        'vsplit:Split pane top/bottom'
        'pane:Switch to pane N'
        'close:Close current pane'
        'resize:Resize current pane'
        'swap:Swap current pane with pane N'
        'full:Toggle fullscreen pane'
        'send:Send command to pane N'
        'layout:Create N panes with layout'
        'win:Create new window'
        'wins:List windows'
        'next:Next window'
        'prev:Previous window'
        'rename:Rename current window'
        'help:Show help'
    )

    _arguments -C \
        '1:command:->cmd' \
        '*::arg:->args'

    case "$state" in
        cmd)
            _describe 'tx command' commands
            ;;
        args)
            case "${words[1]}" in
                a|attach|kill)
                    _tx_sessions
                    ;;
                resize)
                    local -a directions
                    directions=('left' 'right' 'up' 'down')
                    _describe 'direction' directions
                    ;;
                help)
                    local -a help_cmds
                    help_cmds=('new' 'ls' 'a' 'attach' 'detach' 'kill' 'split' 'vsplit' 'pane' 'close' 'resize' 'swap' 'full' 'send' 'layout' 'win' 'wins' 'next' 'prev' 'rename')
                    _describe 'command' help_cmds
                    ;;
                layout)
                    if [ "$CURRENT" -eq 2 ]; then
                        _message 'pane count (2-6)'
                    elif [ "$CURRENT" -eq 3 ]; then
                        local -a layout_opts
                        layout_opts=('-v:Vertical (stacked rows)' 'grid:Tiled grid layout')
                        _describe 'layout option' layout_opts
                    fi
                    ;;
                pane|swap|send)
                    _message 'pane number (1-indexed)'
                    ;;
            esac
            ;;
    esac
}

_tx "$@"
ZSH_COMP
    info "Zsh completions installed to ${_comp_dir}/_tx"

    # Check if completion dir is in fpath
    case "$FPATH" in
        *"$_comp_dir"*)
            ;;
        *)
            warn "Add this to your .zshrc if completions don't work:"
            echo "    fpath=(${_comp_dir} \$fpath)"
            echo "    autoload -Uz compinit && compinit"
            ;;
    esac
}

install_fish_completion() {
    _comp_dir="$HOME/.config/fish/completions"
    mkdir -p "$_comp_dir"

    cat > "${_comp_dir}/tx.fish" <<'FISH_COMP'
# tx completions for fish

# Disable file completions by default
complete -c tx -f

# Main commands
complete -c tx -n '__fish_use_subcommand' -a 'new' -d 'Create a new session'
complete -c tx -n '__fish_use_subcommand' -a 'ls' -d 'List sessions'
complete -c tx -n '__fish_use_subcommand' -a 'a' -d 'Attach to session'
complete -c tx -n '__fish_use_subcommand' -a 'attach' -d 'Attach to session'
complete -c tx -n '__fish_use_subcommand' -a 'detach' -d 'Detach from session'
complete -c tx -n '__fish_use_subcommand' -a 'kill' -d 'Kill a session'
complete -c tx -n '__fish_use_subcommand' -a 'split' -d 'Split pane left/right'
complete -c tx -n '__fish_use_subcommand' -a 'vsplit' -d 'Split pane top/bottom'
complete -c tx -n '__fish_use_subcommand' -a 'pane' -d 'Switch to pane N'
complete -c tx -n '__fish_use_subcommand' -a 'close' -d 'Close current pane'
complete -c tx -n '__fish_use_subcommand' -a 'resize' -d 'Resize current pane'
complete -c tx -n '__fish_use_subcommand' -a 'swap' -d 'Swap current pane with pane N'
complete -c tx -n '__fish_use_subcommand' -a 'full' -d 'Toggle fullscreen pane'
complete -c tx -n '__fish_use_subcommand' -a 'send' -d 'Send command to pane N'
complete -c tx -n '__fish_use_subcommand' -a 'layout' -d 'Create N panes with layout'
complete -c tx -n '__fish_use_subcommand' -a 'win' -d 'Create new window'
complete -c tx -n '__fish_use_subcommand' -a 'wins' -d 'List windows'
complete -c tx -n '__fish_use_subcommand' -a 'next' -d 'Next window'
complete -c tx -n '__fish_use_subcommand' -a 'prev' -d 'Previous window'
complete -c tx -n '__fish_use_subcommand' -a 'rename' -d 'Rename current window'
complete -c tx -n '__fish_use_subcommand' -a 'help' -d 'Show help'

# Session name completions for attach/kill
complete -c tx -n '__fish_seen_subcommand_from a attach kill' -a '(tmux list-sessions -F "#S" 2>/dev/null)'

# Resize directions
complete -c tx -n '__fish_seen_subcommand_from resize' -a 'left right up down'

# Layout options
complete -c tx -n '__fish_seen_subcommand_from layout' -a '-v grid'

# Help subcommands
complete -c tx -n '__fish_seen_subcommand_from help' -a 'new ls a attach detach kill split vsplit pane close resize swap full send layout win wins next prev rename'
FISH_COMP
    info "Fish completions installed to ${_comp_dir}/tx.fish"
}

# --- Detect shells and install completions ---

echo ""
echo "Installing tx..."
echo ""

# Always install the script (already done above)

# Install completions for detected shells
if command -v bash >/dev/null 2>&1; then
    install_bash_completion
fi

if command -v zsh >/dev/null 2>&1; then
    install_zsh_completion
fi

if command -v fish >/dev/null 2>&1; then
    install_fish_completion
fi

echo ""
echo "Done! Run 'tx help' to get started."

# Check if install dir is in PATH
case ":$PATH:" in
    *":${INSTALL_DIR}:"*)
        ;;
    *)
        echo ""
        warn "${INSTALL_DIR} is not in your PATH. Add it:"
        echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
        ;;
esac
