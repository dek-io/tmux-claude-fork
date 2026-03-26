#!/usr/bin/env bash
#
# Fork a running Claude Code session into a new tmux pane.
# Reads the session ID from the Claude process's --session-id arg.
# Requires Claude to be started via `cc` (see shell/cc.sh).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC_SH="$SCRIPT_DIR/../shell/cc.sh"

PANE_PID=$(tmux display-message -p '#{pane_pid}')
PANE_CWD=$(tmux display-message -p '#{pane_current_path}')

source "$SCRIPT_DIR/lib/get-session-id.sh"

tmux split-window -h -c "$PANE_CWD" "source '$CC_SH' && cc --resume '$SESSION_ID' --fork-session"
