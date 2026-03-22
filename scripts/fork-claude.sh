#!/usr/bin/env bash

PANE_ID=$(tmux display-message -p '#{pane_id}')
PANE_CWD=$(tmux display-message -p '#{pane_current_path}')

SESSION_FILE="$HOME/.local/state/tmux-claude-sessions/$PANE_ID"

if [[ ! -f "$SESSION_FILE" ]]; then
  tmux display-message "No Claude session in this pane"
  exit 0
fi

SESSION_ID=$(cat "$SESSION_FILE")

if [[ -z "$SESSION_ID" ]]; then
  tmux display-message "No Claude session in this pane"
  exit 0
fi

tmux split-window -h -c "$PANE_CWD" "claude --dangerously-skip-permissions --effort max --resume $SESSION_ID --fork-session 2>&1; echo '=== EXITED WITH CODE '$?' ==='; sleep 10"
