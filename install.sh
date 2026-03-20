#!/bin/sh
# tx installer — one command, ready to go
set -e

REPO="Harsh-2002/tx"
RAW="https://raw.githubusercontent.com/${REPO}/main"

info() { printf '  \033[1;32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[1;33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[1;31m✗\033[0m %s\n' "$1" >&2; exit 1; }

# Pick a download tool
fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$1"
    else
        fail "Need curl or wget to install"
    fi
}

# Install directory
if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    BIN="/usr/local/bin"
else
    BIN="$HOME/.local/bin"
    mkdir -p "$BIN"
fi

echo ""
echo "Installing tx..."
echo ""

# Download and install tx
fetch "${RAW}/tx" > "${BIN}/tx"
chmod +x "${BIN}/tx"
info "Installed tx to ${BIN}/tx"

# Ensure BIN is in PATH
add_to_path() {
    _line="export PATH=\"${BIN}:\$PATH\""
    for _rc in "$@"; do
        [ -f "$_rc" ] || continue
        case "$(cat "$_rc")" in
            *"$BIN"*) return 0 ;;
        esac
    done
    _target="$1"
    {
        echo ""
        echo "# tx"
        echo "$_line"
    } >> "$_target"
    info "Added ${BIN} to PATH in ${_target}"
}

case ":$PATH:" in
    *":${BIN}:"*) ;;
    *)
        _shell="$(basename "${SHELL:-/bin/sh}")"
        case "$_shell" in
            zsh)  add_to_path "$HOME/.zshrc" ;;
            bash) add_to_path "$HOME/.bashrc" "$HOME/.bash_profile" ;;
            fish) mkdir -p "$HOME/.config/fish"
                  echo "fish_add_path ${BIN}" >> "$HOME/.config/fish/config.fish"
                  info "Added ${BIN} to PATH in config.fish" ;;
            *)    add_to_path "$HOME/.profile" ;;
        esac
        ;;
esac

# Shell completions
_shell="$(basename "${SHELL:-/bin/sh}")"

case "$_shell" in
    zsh)
        _comp_dir="$HOME/.zsh/completions"
        mkdir -p "$_comp_dir"

        cat > "${_comp_dir}/_tx" <<'ZSH_COMP'
#compdef tx

_tx_sessions() {
    local sessions
    sessions=(${(f)"$(tmux list-sessions -F '#S' 2>/dev/null)"})
    _describe 'session' sessions
}

_tx_saves() {
    local saves_dir="$HOME/.config/tx/saves"
    [ -d "$saves_dir" ] || return
    local -a saved
    saved=($(ls "$saves_dir" 2>/dev/null))
    _describe 'saved layout' saved
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
        'save:Save current layout'
        'load:Load a saved layout'
        'saves:List saved layouts'
        'rm:Remove a saved layout'
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
                load|rm)
                    _tx_saves
                    ;;
                resize)
                    local -a directions
                    directions=('left' 'right' 'up' 'down')
                    _describe 'direction' directions
                    ;;
                help)
                    local -a help_cmds
                    help_cmds=('new' 'ls' 'a' 'attach' 'detach' 'kill' 'split' 'vsplit' 'pane' 'close' 'resize' 'swap' 'full' 'send' 'layout' 'save' 'load' 'saves' 'rm' 'win' 'wins' 'next' 'prev' 'rename')
                    _describe 'command' help_cmds
                    ;;
                layout)
                    if [ "$CURRENT" -eq 2 ]; then
                        _message 'pane count'
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
        info "Zsh completions installed"

        # Ensure fpath + compinit in .zshrc
        if ! grep -q '.zsh/completions' "$HOME/.zshrc" 2>/dev/null; then
            cat >> "$HOME/.zshrc" <<'ZSHRC'

# tx completions
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
ZSHRC
            info "Updated .zshrc with completion config"
        fi
        ;;

    bash)
        _comp_dir="$HOME/.local/share/bash-completion/completions"
        mkdir -p "$_comp_dir"

        cat > "${_comp_dir}/tx" <<'BASH_COMP'
_tx_completions() {
    local cur prev commands
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    commands="new ls a attach detach kill split vsplit pane close resize swap full send layout save load saves rm win wins next prev rename help"

    case "$prev" in
        tx)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            return ;;
        a|attach|kill)
            local sessions
            sessions=$(tmux list-sessions -F '#S' 2>/dev/null)
            COMPREPLY=($(compgen -W "$sessions" -- "$cur"))
            return ;;
        load|rm)
            local saves_dir="$HOME/.config/tx/saves"
            if [ -d "$saves_dir" ]; then
                local saves
                saves=$(ls "$saves_dir" 2>/dev/null)
                COMPREPLY=($(compgen -W "$saves" -- "$cur"))
            fi
            return ;;
        resize)
            COMPREPLY=($(compgen -W "left right up down" -- "$cur"))
            return ;;
        help)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            return ;;
        layout)
            COMPREPLY=($(compgen -W "2 3 4 5 6" -- "$cur"))
            return ;;
    esac

    if [ "${COMP_WORDS[1]}" = "layout" ] && [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=($(compgen -W "-v grid" -- "$cur"))
        return
    fi
}
complete -F _tx_completions tx
BASH_COMP
        info "Bash completions installed"

        # Source completions in .bashrc if not already
        if ! grep -q 'bash-completion/completions/tx' "$HOME/.bashrc" 2>/dev/null; then
            {
                echo ''
                echo '# tx completions'
                echo '[ -f ~/.local/share/bash-completion/completions/tx ] && . ~/.local/share/bash-completion/completions/tx'
            } >> "$HOME/.bashrc"
            info "Updated .bashrc with completion config"
        fi
        ;;

    fish)
        _comp_dir="$HOME/.config/fish/completions"
        mkdir -p "$_comp_dir"

        cat > "${_comp_dir}/tx.fish" <<'FISH_COMP'
complete -c tx -f
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
complete -c tx -n '__fish_use_subcommand' -a 'save' -d 'Save current layout'
complete -c tx -n '__fish_use_subcommand' -a 'load' -d 'Load a saved layout'
complete -c tx -n '__fish_use_subcommand' -a 'saves' -d 'List saved layouts'
complete -c tx -n '__fish_use_subcommand' -a 'rm' -d 'Remove a saved layout'
complete -c tx -n '__fish_use_subcommand' -a 'win' -d 'Create new window'
complete -c tx -n '__fish_use_subcommand' -a 'wins' -d 'List windows'
complete -c tx -n '__fish_use_subcommand' -a 'next' -d 'Next window'
complete -c tx -n '__fish_use_subcommand' -a 'prev' -d 'Previous window'
complete -c tx -n '__fish_use_subcommand' -a 'rename' -d 'Rename current window'
complete -c tx -n '__fish_use_subcommand' -a 'help' -d 'Show help'
complete -c tx -n '__fish_seen_subcommand_from a attach kill' -a '(tmux list-sessions -F "#S" 2>/dev/null)'
complete -c tx -n '__fish_seen_subcommand_from load rm' -a '(ls ~/.config/tx/saves/ 2>/dev/null)'
complete -c tx -n '__fish_seen_subcommand_from resize' -a 'left right up down'
complete -c tx -n '__fish_seen_subcommand_from layout' -a '-v grid'
complete -c tx -n '__fish_seen_subcommand_from help' -a 'new ls a attach detach kill split vsplit pane close resize swap full send layout save load saves rm win wins next prev rename'
FISH_COMP
        info "Fish completions installed"
        ;;
esac

# Reload shell config
echo ""

_shell="$(basename "${SHELL:-/bin/sh}")"
case "$_shell" in
    zsh)
        rm -f "$HOME/.zcompdump" 2>/dev/null
        info "Cleared completion cache (will rebuild on next shell)"
        ;;
esac

echo ""
echo "Done! Start a new shell or run:"
echo ""
case "$_shell" in
    zsh)  echo "  source ~/.zshrc" ;;
    bash) echo "  source ~/.bashrc" ;;
    fish) echo "  source ~/.config/fish/config.fish" ;;
    *)    echo "  source ~/.profile" ;;
esac
echo ""
echo "Then type 'tx help' to get started."
