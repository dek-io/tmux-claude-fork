#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$SCRIPT_DIR/fork-wrapper.sh"

PANE_ID=$(tmux display-message -p '#{pane_id}')
PANE_CWD=$(tmux display-message -p '#{pane_current_path}')

SESSION_FILE="/tmp/claude-sessions/$PANE_ID"

if [[ ! -f "$SESSION_FILE" ]]; then
  tmux display-message "No Claude session in this pane"
  exit 0
fi

SESSION_ID=$(jq -r '.session_id' "$SESSION_FILE")

if [[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]]; then
  tmux display-message "No Claude session in this pane"
  exit 0
fi

tmux split-window -h -c "$PANE_CWD" "$WRAPPER $SESSION_ID --dangerously-skip-permissions --effort max"
