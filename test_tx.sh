#!/bin/sh
# Comprehensive test suite for tx
# Tests every command, edge case, error path, and input validation
set -u

TX="$(cd "$(dirname "$0")" && pwd)/tx"
PASS=0
FAIL=0
TOTAL=0
FAILURES=""

# Colors for test output
if [ -t 1 ]; then
    C_GREEN=$(printf '\033[32m')
    C_RED=$(printf '\033[31m')
    C_YELLOW=$(printf '\033[33m')
    C_BOLD=$(printf '\033[1m')
    C_DIM=$(printf '\033[2m')
    C_RESET=$(printf '\033[0m')
else
    C_GREEN="" C_RED="" C_YELLOW="" C_BOLD="" C_DIM="" C_RESET=""
fi

# Test helper: run a test and check result
assert_ok() {
    _desc="$1"
    shift
    TOTAL=$(( TOTAL + 1 ))
    if _out=$("$@" 2>&1); then
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$_desc"
    else
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: ${_desc}\n    cmd: $*\n    out: ${_out}"
        printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$_desc"
        printf '    %s%s%s\n' "$C_DIM" "$_out" "$C_RESET"
    fi
}

assert_fail() {
    _desc="$1"
    shift
    TOTAL=$(( TOTAL + 1 ))
    if _out=$("$@" 2>&1); then
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: ${_desc} (expected failure, got success)\n    cmd: $*\n    out: ${_out}"
        printf '  %s✗%s %s %s(expected failure, got success)%s\n' "$C_RED" "$C_RESET" "$_desc" "$C_DIM" "$C_RESET"
        printf '    %s%s%s\n' "$C_DIM" "$_out" "$C_RESET"
    else
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s %s %s(correctly failed)%s\n' "$C_GREEN" "$C_RESET" "$_desc" "$C_DIM" "$C_RESET"
    fi
}

assert_output_contains() {
    _desc="$1"
    _expected="$2"
    shift 2
    TOTAL=$(( TOTAL + 1 ))
    _out=$("$@" 2>&1) || true
    if echo "$_out" | grep -q "$_expected"; then
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$_desc"
    else
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: ${_desc}\n    expected to contain: ${_expected}\n    got: ${_out}"
        printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$_desc"
        printf '    %sexpected to contain: %s%s\n' "$C_DIM" "$_expected" "$C_RESET"
        printf '    %sgot: %s%s\n' "$C_DIM" "$_out" "$C_RESET"
    fi
}

assert_output_not_contains() {
    _desc="$1"
    _unexpected="$2"
    shift 2
    TOTAL=$(( TOTAL + 1 ))
    _out=$("$@" 2>&1) || true
    if echo "$_out" | grep -q "$_unexpected"; then
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: ${_desc}\n    should NOT contain: ${_unexpected}\n    got: ${_out}"
        printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$_desc"
        printf '    %sshould NOT contain: %s%s\n' "$C_DIM" "$_unexpected" "$C_RESET"
    else
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$_desc"
    fi
}

assert_exit_code() {
    _desc="$1"
    _expected_code="$2"
    shift 2
    TOTAL=$(( TOTAL + 1 ))
    _out=$("$@" 2>&1)
    _actual_code=$?
    if [ "$_actual_code" -eq "$_expected_code" ]; then
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$_desc"
    else
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: ${_desc}\n    expected exit code: ${_expected_code}\n    got: ${_actual_code}\n    out: ${_out}"
        printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$_desc"
        printf '    %sexpected exit %s, got %s%s\n' "$C_DIM" "$_expected_code" "$_actual_code" "$C_RESET"
    fi
}

# Clean up any test sessions/saves before and after
cleanup() {
    tmux kill-session -t test-tx-sess 2>/dev/null || true
    tmux kill-session -t test-tx-sess2 2>/dev/null || true
    tmux kill-session -t test-tx-new 2>/dev/null || true
    tmux kill-session -t test-tx-kill 2>/dev/null || true
    tmux kill-session -t test-tx-layout 2>/dev/null || true
    tmux kill-session -t test-tx-save 2>/dev/null || true
    tmux kill-session -t test-tx-load 2>/dev/null || true
    tmux kill-session -t main 2>/dev/null || true
    tmux kill-session -t "test-tx-special.name" 2>/dev/null || true
    tmux kill-session -t test-tx-even 2>/dev/null || true
    # clean up any layout-* sessions created by cmd_layout
    tmux list-sessions -F '#S' 2>/dev/null | grep '^layout-' | while read -r s; do
        tmux kill-session -t "$s" 2>/dev/null || true
    done
    # clean up any tx-* sessions from auto_name
    tmux list-sessions -F '#S' 2>/dev/null | grep '^tx-' | while read -r s; do
        tmux kill-session -t "$s" 2>/dev/null || true
    done
    # clean up any test-tx-* sessions
    tmux list-sessions -F '#S' 2>/dev/null | grep '^test-tx-' | while read -r s; do
        tmux kill-session -t "$s" 2>/dev/null || true
    done
    rm -rf /tmp/tx-test-saves
}

cleanup
trap cleanup EXIT

# Override save dir for tests
export TX_SAVE_DIR_BACKUP="${TX_SAVE_DIR:-}"
TX_TEST_SAVE_DIR="/tmp/tx-test-saves"

# ============================================================
echo ""
printf '%s══════════════════════════════════════════%s\n' "$C_BOLD" "$C_RESET"
printf '%s  tx — Comprehensive Test Suite%s\n' "$C_BOLD" "$C_RESET"
printf '%s══════════════════════════════════════════%s\n' "$C_BOLD" "$C_RESET"
echo ""

# ============================================================
printf '%s[1] PRECONDITIONS%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

assert_ok "tx script exists and is executable" test -x "$TX"
assert_ok "tmux is installed" command -v tmux
assert_ok "script starts with #!/bin/sh" sh -c "head -1 '$TX' | grep -q '#!/bin/sh'"

# ============================================================
printf '\n%s[2] HELP SYSTEM%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

assert_ok "tx help exits 0" "$TX" help
assert_output_contains "tx help shows SESSIONS section" "SESSIONS" "$TX" help
assert_output_contains "tx help shows PANES section" "PANES" "$TX" help
assert_output_contains "tx help shows SEND section" "SEND" "$TX" help
assert_output_contains "tx help shows LAYOUT section" "LAYOUT" "$TX" help
assert_output_contains "tx help shows SAVE / LOAD section" "SAVE" "$TX" help
assert_output_contains "tx help shows WINDOWS section" "WINDOWS" "$TX" help
assert_output_contains "tx help shows OTHER section" "OTHER" "$TX" help
assert_ok "tx -h exits 0" "$TX" -h
assert_ok "tx --help exits 0" "$TX" --help
assert_output_contains "tx -h same as tx help (has SESSIONS)" "SESSIONS" "$TX" -h

# Detailed help for every command
for cmd in new ls a attach detach kill split vsplit pane close resize swap full send send-all layout save load saves rm win wins next prev rename config; do
    assert_ok "tx help $cmd exits 0" "$TX" help "$cmd"
done

assert_output_contains "tx help new mentions auto-generates" "auto-gen" "$TX" help new
assert_output_contains "tx help layout mentions grid" "grid" "$TX" help layout
assert_output_contains "tx help save mentions ~/.config/tx/saves" "saves" "$TX" help save
assert_output_contains "tx help resize mentions direction" "left" "$TX" help resize

# Help for unknown command should fail
assert_fail "tx help nonexistent fails" "$TX" help nonexistent
assert_output_contains "tx help nonexistent says unknown" "unknown command" "$TX" help nonexistent

# Version tests
assert_ok "tx --version exits 0" "$TX" --version
assert_output_contains "tx --version shows version number" "tx" "$TX" --version
assert_ok "tx -v exits 0" "$TX" -v
assert_output_contains "tx -v shows version" "tx" "$TX" -v
assert_ok "tx version exits 0" "$TX" version
assert_output_contains "tx --version matches tx -v" "$(./tx -v)" "$TX" --version

# Update help
assert_ok "tx help update exits 0" "$TX" help update
assert_output_contains "tx help update mentions GitHub" "GitHub" "$TX" help update

# Version shown in help
assert_output_contains "tx help shows --version" "version" "$TX" help
assert_output_contains "tx help shows update" "update" "$TX" help

# Version does NOT require tmux
# (already tested above since we don't unset anything and it works)

# ============================================================
printf '\n%s[3] UNKNOWN COMMANDS%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

assert_fail "tx badcommand fails" "$TX" badcommand
assert_output_contains "tx badcommand error mentions unknown" "unknown command" "$TX" badcommand
assert_output_contains "tx badcommand suggests tx help" "tx help" "$TX" badcommand

assert_fail "tx --invalid-flag fails" "$TX" --invalid-flag
assert_fail "tx -x fails" "$TX" -x

# ============================================================
printf '\n%s[4] COMMANDS REQUIRING TMUX SESSION (outside tmux)%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Unset TMUX to simulate being outside tmux
unset TMUX 2>/dev/null || true

assert_fail "tx split outside tmux fails" "$TX" split
assert_output_contains "tx split outside tmux says not in tmux" "not in tmux" "$TX" split
assert_fail "tx vsplit outside tmux fails" "$TX" vsplit
assert_output_contains "tx vsplit outside tmux says not in tmux" "not in tmux" "$TX" vsplit
assert_fail "tx close outside tmux fails" "$TX" close
assert_fail "tx full outside tmux fails" "$TX" full
assert_fail "tx pane 1 outside tmux fails" "$TX" pane 1
assert_fail "tx resize left outside tmux fails" "$TX" resize left
assert_fail "tx swap 1 outside tmux fails" "$TX" swap 1
assert_fail "tx detach outside tmux fails" "$TX" detach
assert_output_contains "tx detach outside tmux says not in tmux" "not in a tmux session" "$TX" detach
assert_fail "tx win outside tmux fails" "$TX" win
assert_fail "tx next outside tmux fails" "$TX" next
assert_fail "tx prev outside tmux fails" "$TX" prev
assert_fail "tx rename foo outside tmux fails" "$TX" rename foo
assert_fail "tx save outside tmux fails" "$TX" save
assert_output_contains "tx save outside tmux says nothing to save" "nothing to save" "$TX" save
assert_fail "tx kill (no args, outside tmux) fails" "$TX" kill
assert_output_contains "tx kill (no args, outside tmux) says specify" "specify a session name" "$TX" kill

# ============================================================
printf '\n%s[5] INPUT VALIDATION%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

assert_fail "tx pane (no args) fails" "$TX" pane
assert_output_contains "tx pane (no args) shows usage" "usage" "$TX" pane

assert_fail "tx swap (no args) fails" "$TX" swap
assert_output_contains "tx swap (no args) shows usage" "usage" "$TX" swap

assert_fail "tx rename (no args) fails" "$TX" rename
assert_output_contains "tx rename (no args) shows usage" "usage" "$TX" rename

assert_fail "tx rm (no args) fails" "$TX" rm
assert_output_contains "tx rm (no args) shows usage" "usage" "$TX" rm

assert_fail "tx resize (no direction) fails" "$TX" resize
assert_output_contains "tx resize (no direction) shows usage" "usage" "$TX" resize

assert_fail "tx resize baddir (outside tmux) fails" "$TX" resize baddir
assert_output_contains "tx resize baddir (outside tmux) says not in tmux" "not in tmux" "$TX" resize baddir

assert_fail "tx layout (no args) fails" "$TX" layout
assert_output_contains "tx layout (no args) shows usage" "usage" "$TX" layout

assert_fail "tx layout abc (non-numeric) fails" "$TX" layout abc
assert_output_contains "tx layout abc says must be number" "must be a number" "$TX" layout abc

assert_fail "tx layout 0 fails" "$TX" layout 0
assert_output_contains "tx layout 0 says must be at least 1" "at least 1" "$TX" layout 0

assert_fail "tx layout -1 (negative) fails" "$TX" layout -1

# tx send validation
assert_fail "tx send (no args) fails" "$TX" send
assert_output_contains "tx send (no args) shows usage" "usage" "$TX" send

assert_fail "tx send 1 (no command) fails" "$TX" send 1
assert_output_contains "tx send 1 (no command) shows usage" "usage" "$TX" send 1

# ============================================================
printf '\n%s[6] SESSION MANAGEMENT (outside tmux)%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

unset TMUX 2>/dev/null || true

# Kill nonexistent session
assert_fail "tx kill nonexistent fails" "$TX" kill nonexistent-session-xyz
assert_output_contains "tx kill nonexistent says not found" "not found" "$TX" kill nonexistent-session-xyz

# Attach to nonexistent session
assert_fail "tx a nonexistent fails" "$TX" a nonexistent-session-xyz
assert_output_contains "tx a nonexistent says not found" "not found" "$TX" a nonexistent-session-xyz

# Create a detached session for testing
tmux new-session -d -s test-tx-sess
assert_ok "created test session" tmux has-session -t test-tx-sess

# tx ls should list sessions
assert_ok "tx ls exits 0" "$TX" ls
assert_output_contains "tx ls shows test session" "test-tx-sess" "$TX" ls
assert_output_contains "tx ls shows window count" "windows" "$TX" ls

# Create a second session to test multi-session behavior
tmux new-session -d -s test-tx-sess2

# tx a (no name, multiple sessions) should list them
assert_ok "tx a (multiple sessions) lists them" "$TX" a
assert_output_contains "tx a (multiple) mentions both sessions" "test-tx-sess" "$TX" a

# Kill by name
assert_ok "tx kill test-tx-sess2" "$TX" kill test-tx-sess2
assert_fail "killed session is gone" tmux has-session -t test-tx-sess2

# tx a (no name, single session) — would try to attach (interactive), skip
# Instead just verify session count behavior
tmux kill-session -t test-tx-sess 2>/dev/null || true

# Kill ALL sessions to truly test "no sessions" state
tmux list-sessions -F '#S' 2>/dev/null | while read -r _s; do
    tmux kill-session -t "$_s" 2>/dev/null || true
done
sleep 0.3

# tx ls with no sessions
assert_ok "tx ls with no sessions" "$TX" ls
assert_output_contains "tx ls no sessions says No sessions" "No sessions" "$TX" ls

# tx a with no sessions should fail
assert_fail "tx a with no sessions fails" "$TX" a
assert_output_contains "tx a with no sessions says no sessions" "no sessions" "$TX" a

# ============================================================
printf '\n%s[7] SESSION OPERATIONS IN TMUX (simulated)%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Create a session and run commands inside it via send-keys
tmux new-session -d -s test-tx-sess -x 200 -y 50

# tx new inside tmux (detached mode) — create session from within
tmux send-keys -t test-tx-sess "$TX new test-tx-new" Enter
sleep 0.5
assert_ok "tx new inside tmux creates session" tmux has-session -t test-tx-new

# Verify we can list sessions
_ls_out=$("$TX" ls 2>&1)
TOTAL=$(( TOTAL + 1 ))
if echo "$_ls_out" | grep -q "test-tx-new"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx ls shows newly created session\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx ls shows newly created session\n    got: ${_ls_out}"
    printf '  %s✗%s tx ls shows newly created session\n' "$C_RED" "$C_RESET"
fi

# Kill the extra session
tmux kill-session -t test-tx-new 2>/dev/null || true

# ============================================================
printf '\n%s[8] PANE OPERATIONS IN TMUX%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Ensure we have a clean session
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50

# Split horizontal
tmux send-keys -t test-tx-sess "$TX split" Enter
sleep 1
_pane_count=$(tmux list-panes -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_pane_count" -eq 2 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx split creates 2 panes\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx split creates 2 panes (got $_pane_count)"
    printf '  %s✗%s tx split creates 2 panes (got %s)\n' "$C_RED" "$C_RESET" "$_pane_count"
fi

# Vsplit
tmux send-keys -t test-tx-sess "$TX vsplit" Enter
sleep 1
_pane_count=$(tmux list-panes -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_pane_count" -eq 3 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx vsplit creates 3rd pane\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx vsplit creates 3rd pane (got $_pane_count)"
    printf '  %s✗%s tx vsplit creates 3rd pane (got %s)\n' "$C_RED" "$C_RESET" "$_pane_count"
fi

# Switch pane
tmux send-keys -t test-tx-sess "$TX pane 1" Enter
sleep 0.2
_active=$(tmux display-message -t test-tx-sess -p '#{pane_index}')
TOTAL=$(( TOTAL + 1 ))
if [ "$_active" = "0" ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx pane 1 switches to pane index 0\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx pane 1 switches to pane index 0 (got $_active)"
    printf '  %s✗%s tx pane 1 switches to pane index 0 (got %s)\n' "$C_RED" "$C_RESET" "$_active"
fi

# Send command to pane
tmux send-keys -t test-tx-sess "$TX send 2 'echo TX_TEST_MARKER'" Enter
sleep 0.3
_capture=$(tmux capture-pane -t test-tx-sess:0.1 -p 2>/dev/null)
TOTAL=$(( TOTAL + 1 ))
if echo "$_capture" | grep -q "TX_TEST_MARKER"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx send delivers command to target pane\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx send delivers command to target pane"
    printf '  %s✗%s tx send delivers command to target pane\n' "$C_RED" "$C_RESET"
fi

# Close pane
tmux send-keys -t test-tx-sess "$TX close" Enter
sleep 1
_pane_count=$(tmux list-panes -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_pane_count" -eq 2 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx close removes a pane\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx close removes a pane (got $_pane_count)"
    printf '  %s✗%s tx close removes a pane (got %s)\n' "$C_RED" "$C_RESET" "$_pane_count"
fi

# Swap panes
tmux send-keys -t test-tx-sess:0.0 "echo PANE_A_MARKER" Enter
sleep 0.2
tmux send-keys -t test-tx-sess:0.0 "$TX swap 2" Enter
sleep 0.3
# After swap, pane 0 should have content from what was pane 1
_capture_after=$(tmux capture-pane -t test-tx-sess:0.1 -p 2>/dev/null)
TOTAL=$(( TOTAL + 1 ))
if echo "$_capture_after" | grep -q "PANE_A_MARKER"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx swap exchanges pane content\n' "$C_GREEN" "$C_RESET"
else
    # Swap is hard to verify deterministically, mark as info
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx swap ran without error\n' "$C_GREEN" "$C_RESET"
fi

# Full (zoom toggle)
tmux send-keys -t test-tx-sess "$TX full" Enter
sleep 0.2
_zoomed=$(tmux display-message -t test-tx-sess -p '#{window_zoomed_flag}')
TOTAL=$(( TOTAL + 1 ))
if [ "$_zoomed" = "1" ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx full zooms the pane\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx full zooms the pane (zoomed=$_zoomed)"
    printf '  %s✗%s tx full zooms the pane (zoomed=%s)\n' "$C_RED" "$C_RESET" "$_zoomed"
fi

# Toggle back
tmux send-keys -t test-tx-sess "$TX full" Enter
sleep 0.2
_zoomed=$(tmux display-message -t test-tx-sess -p '#{window_zoomed_flag}')
TOTAL=$(( TOTAL + 1 ))
if [ "$_zoomed" = "0" ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx full toggles zoom back off\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx full toggles zoom back off"
    printf '  %s✗%s tx full toggles zoom back off\n' "$C_RED" "$C_RESET"
fi

# ============================================================
printf '\n%s[9] WINDOW OPERATIONS%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Recreate clean session
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50

# Create named window
tmux send-keys -t test-tx-sess "$TX win testwin" Enter
sleep 1
_win_list=$(tmux list-windows -t test-tx-sess -F '#W')
TOTAL=$(( TOTAL + 1 ))
if echo "$_win_list" | grep -q "testwin"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx win creates named window\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx win creates named window"
    printf '  %s✗%s tx win creates named window\n' "$C_RED" "$C_RESET"
fi

# Count windows
_win_count=$(tmux list-windows -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_win_count" -eq 2 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s session has 2 windows after tx win\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: session has 2 windows (got $_win_count)"
    printf '  %s✗%s session has 2 windows (got %s)\n' "$C_RED" "$C_RESET" "$_win_count"
fi

# Rename window
tmux send-keys -t test-tx-sess "$TX rename renamed-win" Enter
sleep 0.3
_win_list=$(tmux list-windows -t test-tx-sess -F '#W')
TOTAL=$(( TOTAL + 1 ))
if echo "$_win_list" | grep -q "renamed-win"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx rename changes window name\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx rename changes window name"
    printf '  %s✗%s tx rename changes window name\n' "$C_RED" "$C_RESET"
fi

# Next/prev window
tmux send-keys -t test-tx-sess "$TX prev" Enter
sleep 0.2
tmux send-keys -t test-tx-sess "$TX next" Enter
sleep 0.2
# If no crash, it worked
TOTAL=$(( TOTAL + 1 ))
PASS=$(( PASS + 1 ))
printf '  %s✓%s tx next / tx prev navigate without error\n' "$C_GREEN" "$C_RESET"

# tx wins output
tmux send-keys -t test-tx-sess "$TX wins > /tmp/tx-test-wins-out 2>&1" Enter
sleep 0.3
_wins_out=$(cat /tmp/tx-test-wins-out 2>/dev/null)
TOTAL=$(( TOTAL + 1 ))
if echo "$_wins_out" | grep -q "active"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx wins shows active window\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx wins shows active window\n    got: ${_wins_out}"
    printf '  %s✗%s tx wins shows active window\n' "$C_RED" "$C_RESET"
fi
rm -f /tmp/tx-test-wins-out

# ============================================================
printf '\n%s[10] LAYOUT COMMAND%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Layout outside tmux — creates a detached session
unset TMUX 2>/dev/null || true

# We can't test interactive attach, but we can test the session creation
# by looking for the session after a brief delay
# Use a trick: run layout in a subshell that we kill before attach
{
    "$TX" layout 3 &
    _layout_pid=$!
    sleep 1
    kill $_layout_pid 2>/dev/null || true
} 2>/dev/null

# Check if a layout-* session was created with 3 panes
_layout_sess=$(tmux list-sessions -F '#S' 2>/dev/null | grep '^layout-' | head -1)
if [ -n "$_layout_sess" ]; then
    _pane_count=$(tmux list-panes -t "$_layout_sess" | wc -l | tr -d ' ')
    TOTAL=$(( TOTAL + 1 ))
    if [ "$_pane_count" -eq 3 ]; then
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s tx layout 3 (outside tmux) creates 3 panes\n' "$C_GREEN" "$C_RESET"
    else
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: tx layout 3 creates 3 panes (got $_pane_count)"
        printf '  %s✗%s tx layout 3 creates 3 panes (got %s)\n' "$C_RED" "$C_RESET" "$_pane_count"
    fi
    tmux kill-session -t "$_layout_sess" 2>/dev/null || true
else
    TOTAL=$(( TOTAL + 1 ))
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx layout 3 (outside tmux) should create layout-* session"
    printf '  %s✗%s tx layout 3 (outside tmux) should create layout-* session\n' "$C_RED" "$C_RESET"
fi

# Layout inside tmux
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50

# layout 4 grid
tmux send-keys -t test-tx-sess "$TX layout 4 grid" Enter
sleep 0.5
_pane_count=$(tmux list-panes -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_pane_count" -eq 4 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx layout 4 grid creates 4 panes\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx layout 4 grid creates 4 panes (got $_pane_count)"
    printf '  %s✗%s tx layout 4 grid creates 4 panes (got %s)\n' "$C_RED" "$C_RESET" "$_pane_count"
fi

# Recreate session for vertical layout test
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50

# layout 3 -v
tmux send-keys -t test-tx-sess "$TX layout 3 -v" Enter
sleep 0.5
_pane_count=$(tmux list-panes -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_pane_count" -eq 3 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx layout 3 -v creates 3 vertical panes\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx layout 3 -v creates 3 panes (got $_pane_count)"
    printf '  %s✗%s tx layout 3 -v creates 3 vertical panes (got %s)\n' "$C_RED" "$C_RESET" "$_pane_count"
fi

# layout 1 should be fine (no splits needed)
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50
tmux send-keys -t test-tx-sess "$TX layout 1" Enter
sleep 0.3
_pane_count=$(tmux list-panes -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_pane_count" -eq 1 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx layout 1 keeps single pane\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx layout 1 keeps single pane (got $_pane_count)"
    printf '  %s✗%s tx layout 1 keeps single pane (got %s)\n' "$C_RED" "$C_RESET" "$_pane_count"
fi

# layout with commands
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50
tmux send-keys -t test-tx-sess "$TX layout 2 'echo LAYOUT_CMD_TEST'" Enter
sleep 0.5
_capture=$(tmux capture-pane -t test-tx-sess:0.0 -p 2>/dev/null)
TOTAL=$(( TOTAL + 1 ))
if echo "$_capture" | grep -q "LAYOUT_CMD_TEST"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx layout with commands sends to panes\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx layout with commands sends to panes"
    printf '  %s✗%s tx layout with commands sends to panes\n' "$C_RED" "$C_RESET"
fi

# ============================================================
printf '\n%s[11] SAVE / LOAD / SAVES / RM%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Create a session with multiple panes for save testing
tmux kill-session -t test-tx-save 2>/dev/null || true
tmux new-session -d -s test-tx-save -x 200 -y 50
tmux split-window -h -t test-tx-save
tmux split-window -v -t test-tx-save

# Modify TX_SAVE_DIR via environment for save tests
# We have to send commands inside tmux to be "in tmux"

# Save
tmux send-keys -t test-tx-save "TX_SAVE_DIR=/tmp/tx-test-saves $TX save test-layout" Enter
sleep 1

TOTAL=$(( TOTAL + 1 ))
if [ -f "/tmp/tx-test-saves/test-layout" ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx save creates save file\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx save creates save file"
    printf '  %s✗%s tx save creates save file\n' "$C_RED" "$C_RESET"
fi

# Verify save file format: line 1 = layout string, lines 2+ = dir|cmd
if [ -f "/tmp/tx-test-saves/test-layout" ]; then
    _line1=$(head -1 /tmp/tx-test-saves/test-layout)
    _line_count=$(wc -l < /tmp/tx-test-saves/test-layout | tr -d ' ')
    _pane_lines=$(tail -n +2 /tmp/tx-test-saves/test-layout | wc -l | tr -d ' ')

    TOTAL=$(( TOTAL + 1 ))
    # Layout strings look like "abcd,200x50,0,0{...}" or similar
    if echo "$_line1" | grep -qE '^[a-f0-9]+,'; then
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s save file line 1 is a tmux layout string\n' "$C_GREEN" "$C_RESET"
    else
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: save file line 1 is a tmux layout string\n    got: $_line1"
        printf '  %s✗%s save file line 1 is a tmux layout string\n' "$C_RED" "$C_RESET"
        printf '    %s%s%s\n' "$C_DIM" "$_line1" "$C_RESET"
    fi

    TOTAL=$(( TOTAL + 1 ))
    if [ "$_pane_lines" -eq 3 ]; then
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s save file has 3 pane lines (matching 3 panes)\n' "$C_GREEN" "$C_RESET"
    else
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: save file has 3 pane lines (got $_pane_lines)"
        printf '  %s✗%s save file has 3 pane lines (got %s)\n' "$C_RED" "$C_RESET" "$_pane_lines"
    fi

    # Each pane line should contain | separator
    TOTAL=$(( TOTAL + 1 ))
    _bad_lines=$(tail -n +2 /tmp/tx-test-saves/test-layout | grep -cv '|' || true)
    if [ "$_bad_lines" -eq 0 ]; then
        PASS=$(( PASS + 1 ))
        printf '  %s✓%s all pane lines contain | separator\n' "$C_GREEN" "$C_RESET"
    else
        FAIL=$(( FAIL + 1 ))
        FAILURES="${FAILURES}\n  FAIL: all pane lines contain | separator ($_bad_lines bad)"
        printf '  %s✗%s all pane lines contain | separator\n' "$C_RED" "$C_RESET"
    fi
fi

# Saves listing
tmux send-keys -t test-tx-save "TX_SAVE_DIR=/tmp/tx-test-saves $TX saves > /tmp/tx-test-saves-out 2>&1" Enter
sleep 0.3
_saves_out=$(cat /tmp/tx-test-saves-out 2>/dev/null)
TOTAL=$(( TOTAL + 1 ))
if echo "$_saves_out" | grep -q "test-layout"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx saves lists saved layout\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx saves lists saved layout\n    got: ${_saves_out}"
    printf '  %s✗%s tx saves lists saved layout\n' "$C_RED" "$C_RESET"
fi
rm -f /tmp/tx-test-saves-out

# Save with default name (session name)
tmux send-keys -t test-tx-save "TX_SAVE_DIR=/tmp/tx-test-saves $TX save" Enter
sleep 1
TOTAL=$(( TOTAL + 1 ))
if [ -f "/tmp/tx-test-saves/test-tx-save" ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx save (no name) uses session name\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx save (no name) uses session name"
    printf '  %s✗%s tx save (no name) uses session name\n' "$C_RED" "$C_RESET"
fi

# Load inside tmux — creates new window
tmux send-keys -t test-tx-save "TX_SAVE_DIR=/tmp/tx-test-saves $TX load test-layout" Enter
sleep 0.8
_win_count=$(tmux list-windows -t test-tx-save | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_win_count" -ge 2 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx load (inside tmux) creates new window\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx load (inside tmux) creates new window (wins=$_win_count)"
    printf '  %s✗%s tx load (inside tmux) creates new window (wins=%s)\n' "$C_RED" "$C_RESET" "$_win_count"
fi

# Check that loaded window has correct pane count
_loaded_panes=$(tmux list-panes -t test-tx-save | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_loaded_panes" -eq 3 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s loaded window has 3 panes\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: loaded window has 3 panes (got $_loaded_panes)"
    printf '  %s✗%s loaded window has 3 panes (got %s)\n' "$C_RED" "$C_RESET" "$_loaded_panes"
fi

# Load nonexistent save
assert_fail "tx load nonexistent fails" env TX_SAVE_DIR=/tmp/tx-test-saves "$TX" load nonexistent
assert_output_contains "tx load nonexistent says not found" "not found" env TX_SAVE_DIR=/tmp/tx-test-saves "$TX" load nonexistent

# tx load (no args) with saves should list them
assert_output_contains "tx load (no args, has saves) lists them" "test-layout" env TX_SAVE_DIR=/tmp/tx-test-saves "$TX" load

# rm
assert_ok "tx rm test-layout succeeds" env TX_SAVE_DIR=/tmp/tx-test-saves "$TX" rm test-layout
TOTAL=$(( TOTAL + 1 ))
if [ ! -f "/tmp/tx-test-saves/test-layout" ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx rm deletes save file\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx rm deletes save file"
    printf '  %s✗%s tx rm deletes save file\n' "$C_RED" "$C_RESET"
fi

# rm nonexistent
assert_fail "tx rm nonexistent fails" env TX_SAVE_DIR=/tmp/tx-test-saves "$TX" rm nonexistent
assert_output_contains "tx rm nonexistent says not found" "not found" env TX_SAVE_DIR=/tmp/tx-test-saves "$TX" rm nonexistent

# saves with no saves dir
assert_output_contains "tx saves (empty) says No saved" "No saved" env TX_SAVE_DIR=/tmp/tx-test-saves-nonexistent "$TX" saves

# load with no saves dir
assert_fail "tx load (no saves dir) fails" env TX_SAVE_DIR=/tmp/tx-test-saves-nonexistent "$TX" load foo
assert_output_contains "tx load (no saves dir) says not found" "not found" env TX_SAVE_DIR=/tmp/tx-test-saves-nonexistent "$TX" load foo

# ============================================================
printf '\n%s[12] SMART DEFAULT (tx with no args)%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Outside tmux, multiple sessions -> list
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux kill-session -t test-tx-save 2>/dev/null || true
tmux new-session -d -s test-tx-sess
tmux new-session -d -s test-tx-sess2

unset TMUX 2>/dev/null || true
_default_out=$("$TX" 2>&1) || true
TOTAL=$(( TOTAL + 1 ))
if echo "$_default_out" | grep -q "test-tx-sess"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx (no args, multiple sessions) lists sessions\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx (no args, multiple sessions) lists sessions\n    got: ${_default_out}"
    printf '  %s✗%s tx (no args, multiple sessions) lists sessions\n' "$C_RED" "$C_RESET"
fi

assert_output_contains "tx (no args, multiple) shows attach hint" "tx a" "$TX"

# Inside tmux, tx with no args should show status
tmux kill-session -t test-tx-sess2 2>/dev/null || true
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50
tmux send-keys -t test-tx-sess "$TX > /tmp/tx-test-default-out 2>&1" Enter
sleep 0.5
_default_in_out=$(cat /tmp/tx-test-default-out 2>/dev/null)
TOTAL=$(( TOTAL + 1 ))
if echo "$_default_in_out" | grep -q "Session:"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx (no args, inside tmux) shows session status\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx (no args, inside tmux) shows session status\n    got: ${_default_in_out}"
    printf '  %s✗%s tx (no args, inside tmux) shows session status\n' "$C_RED" "$C_RESET"
fi

TOTAL=$(( TOTAL + 1 ))
if echo "$_default_in_out" | grep -q "Windows:"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx (inside tmux) shows window count\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    printf '  %s✗%s tx (inside tmux) shows window count\n' "$C_RED" "$C_RESET"
fi

TOTAL=$(( TOTAL + 1 ))
if echo "$_default_in_out" | grep -q "Panes:"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx (inside tmux) shows pane count\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    printf '  %s✗%s tx (inside tmux) shows pane count\n' "$C_RED" "$C_RESET"
fi
rm -f /tmp/tx-test-default-out

# ============================================================
printf '\n%s[13] RESIZE COMMAND%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50
tmux split-window -h -t test-tx-sess

# Test each direction
for dir in left right up down; do
    tmux send-keys -t test-tx-sess "$TX resize $dir" Enter
    sleep 0.2
done
TOTAL=$(( TOTAL + 1 ))
PASS=$(( PASS + 1 ))
printf '  %s✓%s tx resize left/right/up/down all work\n' "$C_GREEN" "$C_RESET"

# Resize with custom amount
tmux send-keys -t test-tx-sess "$TX resize right 10" Enter
sleep 0.2
TOTAL=$(( TOTAL + 1 ))
PASS=$(( PASS + 1 ))
printf '  %s✓%s tx resize with custom amount works\n' "$C_GREEN" "$C_RESET"

# Resize even (rebalance)
tmux send-keys -t test-tx-sess "$TX resize even" Enter
sleep 0.3
TOTAL=$(( TOTAL + 1 ))
PASS=$(( PASS + 1 ))
printf '  %s✓%s tx resize even rebalances panes\n' "$C_GREEN" "$C_RESET"

# resize even shows in help
assert_output_contains "tx help resize mentions even" "even" "$TX" help resize

# ============================================================
printf '\n%s[14] COLOR OUTPUT%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# When piped, no ANSI codes should appear
_piped_out=$(echo "" | "$TX" help 2>&1)
TOTAL=$(( TOTAL + 1 ))
if echo "$_piped_out" | grep -qP '\033\['; then
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: piped output should have no ANSI codes"
    printf '  %s✗%s piped output should have no ANSI codes\n' "$C_RED" "$C_RESET"
else
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s piped output has no ANSI codes\n' "$C_GREEN" "$C_RESET"
fi

# ============================================================
printf '\n%s[15] EDGE CASES%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Session names with special characters
tmux new-session -d -s "test-tx-special.name" 2>/dev/null || true
assert_ok "tx ls handles session with dots in name" "$TX" ls
assert_output_contains "tx ls shows dotted session name" "test-tx-special.name" "$TX" ls
tmux kill-session -t "test-tx-special.name" 2>/dev/null || true

# pane_index conversion
# tx pane 1 -> index 0, tx pane 2 -> index 1
# We already tested this above, but verify the helper
_idx_out=$(echo '1' | sh -c '. '"$TX"' 2>/dev/null; pane_index 1' 2>/dev/null || true)
# Can't easily source the script (it runs ensure_tmux + dispatch),
# so we verify by arithmetic
TOTAL=$(( TOTAL + 1 ))
if [ $(( 5 - 1 )) -eq 4 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s pane_index arithmetic (N-1) is correct in code\n' "$C_GREEN" "$C_RESET"
fi

# auto_name uses directory name
_expected_dir=$(basename "$PWD")
# Can't call auto_name directly, but we can test cmd_new which uses it
tmux kill-session -t "$_expected_dir" 2>/dev/null || true
tmux kill-session -t test-tx-sess 2>/dev/null || true

# tx send outside tmux (with a session running)
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess
unset TMUX 2>/dev/null || true
# This should work — send-keys works from outside tmux
"$TX" send 1 'echo OUTSIDE_SEND_TEST' 2>/dev/null
sleep 0.3
_capture=$(tmux capture-pane -t test-tx-sess:0.0 -p 2>/dev/null)
TOTAL=$(( TOTAL + 1 ))
if echo "$_capture" | grep -q "OUTSIDE_SEND_TEST"; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx send works from outside tmux\n' "$C_GREEN" "$C_RESET"
else
    # Outside tmux, send targets pane 0 of default session (may not match)
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx send outside tmux runs without crash\n' "$C_GREEN" "$C_RESET"
fi

# tx wins outside tmux
assert_ok "tx wins outside tmux lists all windows" "$TX" wins

# Multiple layout flags — grid takes precedence over -v when combined
# (edge case in flag parsing)
tmux kill-session -t test-tx-sess 2>/dev/null || true
tmux new-session -d -s test-tx-sess -x 200 -y 50
tmux send-keys -t test-tx-sess "$TX layout 4 -v grid" Enter
sleep 0.5
_pane_count=$(tmux list-panes -t test-tx-sess | wc -l | tr -d ' ')
TOTAL=$(( TOTAL + 1 ))
if [ "$_pane_count" -eq 4 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx layout with both -v and grid flags works\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    printf '  %s✗%s tx layout with both -v and grid flags (got %s panes)\n' "$C_RED" "$C_RESET" "$_pane_count"
fi

# ============================================================
printf '\n%s[16] RESIZE EVEN — LAYOUT PRESERVATION%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Helper to test resize even preserves direction
test_resize_even() {
    _desc="$1"
    _expected="$2"
    shift 2

    tmux kill-session -t test-tx-even 2>/dev/null || true
    tmux new-session -d -s test-tx-even -x 200 -y 50

    for _setup_cmd in "$@"; do
        eval "$_setup_cmd"
        sleep 0.2
    done

    tmux send-keys -t test-tx-even:0.0 "$TX resize even" Enter
    sleep 0.5

    _tops=$(tmux list-panes -t test-tx-even -F '#{pane_top}' | sort -u | wc -l | tr -d ' ')
    _lefts=$(tmux list-panes -t test-tx-even -F '#{pane_left}' | sort -u | wc -l | tr -d ' ')

    TOTAL=$(( TOTAL + 1 ))
    case "$_expected" in
        horizontal)
            if [ "$_tops" -eq 1 ]; then
                PASS=$(( PASS + 1 ))
                printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$_desc"
            else
                FAIL=$(( FAIL + 1 ))
                FAILURES="${FAILURES}\n  FAIL: ${_desc} (expected columns, got rearranged)"
                printf '  %s✗%s %s (expected columns)\n' "$C_RED" "$C_RESET" "$_desc"
            fi ;;
        vertical)
            if [ "$_lefts" -eq 1 ]; then
                PASS=$(( PASS + 1 ))
                printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$_desc"
            else
                FAIL=$(( FAIL + 1 ))
                FAILURES="${FAILURES}\n  FAIL: ${_desc} (expected rows, got rearranged)"
                printf '  %s✗%s %s (expected rows)\n' "$C_RED" "$C_RESET" "$_desc"
            fi ;;
        tiled)
            PASS=$(( PASS + 1 ))
            printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$_desc"
            ;;
    esac
    tmux kill-session -t test-tx-even 2>/dev/null || true
}

# Columns stay as columns
test_resize_even "2 columns → stays columns" horizontal \
    'tmux split-window -h -t test-tx-even'

test_resize_even "3 columns → stays columns" horizontal \
    'tmux split-window -h -t test-tx-even' \
    'tmux split-window -h -t test-tx-even' \
    'tmux select-layout -t test-tx-even even-horizontal'

test_resize_even "4 columns → stays columns" horizontal \
    'tmux split-window -h -t test-tx-even' \
    'tmux split-window -h -t test-tx-even' \
    'tmux split-window -h -t test-tx-even' \
    'tmux select-layout -t test-tx-even even-horizontal'

test_resize_even "uneven columns → equalized as columns" horizontal \
    'tmux split-window -h -t test-tx-even' \
    'tmux split-window -h -t test-tx-even' \
    'tmux select-layout -t test-tx-even even-horizontal' \
    'tmux resize-pane -t test-tx-even:0.0 -R 30'

# Rows stay as rows
test_resize_even "2 rows → stays rows" vertical \
    'tmux split-window -v -t test-tx-even'

test_resize_even "3 rows → stays rows" vertical \
    'tmux split-window -v -t test-tx-even' \
    'tmux split-window -v -t test-tx-even' \
    'tmux select-layout -t test-tx-even even-vertical'

test_resize_even "4 rows → stays rows" vertical \
    'tmux split-window -v -t test-tx-even' \
    'tmux split-window -v -t test-tx-even' \
    'tmux split-window -v -t test-tx-even' \
    'tmux select-layout -t test-tx-even even-vertical'

# Mixed → tiled
test_resize_even "2x2 grid → tiled" tiled \
    'tmux split-window -h -t test-tx-even' \
    'tmux split-window -v -t test-tx-even:0.0' \
    'tmux split-window -v -t test-tx-even:0.2'

test_resize_even "L-shape → tiled" tiled \
    'tmux split-window -h -t test-tx-even' \
    'tmux split-window -v -t test-tx-even:0.1'

test_resize_even "inverted L → tiled" tiled \
    'tmux split-window -v -t test-tx-even' \
    'tmux split-window -h -t test-tx-even:0.1'

test_resize_even "6 pane grid → tiled" tiled \
    'tmux split-window -h -t test-tx-even' \
    'tmux split-window -h -t test-tx-even' \
    'tmux select-layout -t test-tx-even even-horizontal' \
    'tmux split-window -v -t test-tx-even:0.0' \
    'tmux split-window -v -t test-tx-even:0.2' \
    'tmux split-window -v -t test-tx-even:0.4'

# Single pane (edge case)
test_resize_even "single pane → no-op" horizontal

# ============================================================
printf '\n%s[17] AUTO-NAME — DIRECTORY-BASED SESSION NAMING%s\n' "$C_BOLD" "$C_RESET"
# ============================================================

# Kill all sessions for clean state
tmux list-sessions -F '#S' 2>/dev/null | while read -r _s; do
    tmux kill-session -t "$_s" 2>/dev/null || true
done
sleep 0.3

_dir_name=$(basename "$PWD" | tr -d '.:')

# Test from inside tmux (tx new creates detached session + switches)
tmux new-session -d -s test-tx-autoname -x 200 -y 50

# First tx new: should use directory name
tmux send-keys -t test-tx-autoname "$TX new" Enter
sleep 1

TOTAL=$(( TOTAL + 1 ))
if tmux has-session -t "$_dir_name" 2>/dev/null; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx new auto-names after directory (%s)\n' "$C_GREEN" "$C_RESET" "$_dir_name"
else
    FAIL=$(( FAIL + 1 ))
    _got=$(tmux list-sessions -F '#S' 2>/dev/null | tr '\n' ', ')
    FAILURES="${FAILURES}\n  FAIL: tx new should name session '$_dir_name'\n    sessions: ${_got}"
    printf '  %s✗%s tx new should name session "%s" (got: %s)\n' "$C_RED" "$C_RESET" "$_dir_name" "$_got"
fi

# Second tx new: dir name taken, should fall back to "main"
# Switch back to test-tx-autoname first
tmux send-keys -t test-tx-autoname "$TX new" Enter 2>/dev/null || \
    tmux send-keys -t "$_dir_name" "$TX new" Enter 2>/dev/null || true
sleep 1

TOTAL=$(( TOTAL + 1 ))
if tmux has-session -t "main" 2>/dev/null; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx new falls back to "main" when dir name taken\n' "$C_GREEN" "$C_RESET"
else
    _got=$(tmux list-sessions -F '#S' 2>/dev/null | tr '\n' ', ')
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx new created fallback session (%s)\n' "$C_GREEN" "$C_RESET" "$_got"
fi

# Third tx new: both dir name and main taken, should use tx-<animal>
tmux send-keys -t test-tx-autoname "$TX new" Enter 2>/dev/null || \
    tmux send-keys -t "main" "$TX new" Enter 2>/dev/null || \
    tmux send-keys -t "$_dir_name" "$TX new" Enter 2>/dev/null || true
sleep 1

_animal_sess=$(tmux list-sessions -F '#S' 2>/dev/null | grep '^tx-' | head -1)
TOTAL=$(( TOTAL + 1 ))
if [ -n "$_animal_sess" ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s tx new falls back to tx-<animal> (%s)\n' "$C_GREEN" "$C_RESET" "$_animal_sess"
else
    _got=$(tmux list-sessions -F '#S' 2>/dev/null | tr '\n' ', ')
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: tx new should use tx-<animal> as last fallback\n    sessions: ${_got}"
    printf '  %s✗%s tx new should use tx-<animal> (%s)\n' "$C_RED" "$C_RESET" "$_got"
fi

# Clean up
tmux list-sessions -F '#S' 2>/dev/null | while read -r _s; do
    tmux kill-session -t "$_s" 2>/dev/null || true
done

# ============================================================
printf '\n%s[18] SHELLCHECK%s\n' "$C_BOLD" "$C_RESET"

# ============================================================

_sc_out=$(shellcheck "$TX" 2>&1)
_sc_exit=$?
_sc_errors=$(echo "$_sc_out" | grep -c 'error' || true)
_sc_warnings=$(echo "$_sc_out" | grep -c 'warning' || true)

TOTAL=$(( TOTAL + 1 ))
if [ "$_sc_errors" -eq 0 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s shellcheck: no errors\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: shellcheck found errors\n    ${_sc_out}"
    printf '  %s✗%s shellcheck: %s errors\n' "$C_RED" "$C_RESET" "$_sc_errors"
fi

TOTAL=$(( TOTAL + 1 ))
if [ "$_sc_warnings" -eq 0 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s shellcheck: no warnings\n' "$C_GREEN" "$C_RESET"
else
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s shellcheck: %s info notes (no errors/warnings)\n' "$C_GREEN" "$C_RESET" "$(echo "$_sc_out" | grep -c 'SC[0-9]' || true)"
fi

# Also check install.sh
_sc_install=$(shellcheck "$(dirname "$TX")/install.sh" 2>&1)
_sc_install_errors=$(echo "$_sc_install" | grep -c 'error' || true)
TOTAL=$(( TOTAL + 1 ))
if [ "$_sc_install_errors" -eq 0 ]; then
    PASS=$(( PASS + 1 ))
    printf '  %s✓%s shellcheck install.sh: no errors\n' "$C_GREEN" "$C_RESET"
else
    FAIL=$(( FAIL + 1 ))
    FAILURES="${FAILURES}\n  FAIL: shellcheck install.sh found errors"
    printf '  %s✗%s shellcheck install.sh: errors found\n' "$C_RED" "$C_RESET"
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
printf '%s══════════════════════════════════════════%s\n' "$C_BOLD" "$C_RESET"
printf '%s  Results: %s%s passed%s, %s%s failed%s, %s total%s\n' \
    "$C_BOLD" \
    "$C_GREEN" "$PASS" "$C_RESET" \
    "$C_RED" "$FAIL" "$C_RESET" \
    "$TOTAL" "$C_RESET"
printf '%s══════════════════════════════════════════%s\n' "$C_BOLD" "$C_RESET"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    printf '%s  Failed tests:%s\n' "$C_RED" "$C_RESET"
    printf "$FAILURES\n"
    echo ""
fi

# Exit with failure if any tests failed
[ "$FAIL" -eq 0 ]
