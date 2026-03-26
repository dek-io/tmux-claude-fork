#!/usr/bin/env bash
#
# Fork a running Claude Code session into a new tmux pane.
# Reads the session ID from the Claude process's --session-id arg.
# Requires Claude to be started via `cc` (see shell/cc.sh).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PANE_PID=$(tmux display-message -p '#{pane_pid}')
PANE_CWD=$(tmux display-message -p '#{pane_current_path}')

source "$SCRIPT_DIR/lib/get-session-id.sh"

FORK_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
NEW_PANE=$(tmux split-window -h -c "$PANE_CWD" -P -F '#{pane_id}')
tmux send-keys -t "$NEW_PANE" "cc --session-id '$FORK_ID' --resume '$SESSION_ID' --fork-session" Enter
