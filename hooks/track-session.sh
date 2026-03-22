#!/usr/bin/env bash
# Writes the active Claude session ID to a per-pane file for tmux-claude-fork.
# Triggered by the SessionStart hook on both new sessions and /resume.

[[ -z "$TMUX_PANE" ]] && exit 0

SESSION_ID=$(jq -r '.session_id // empty')
[[ -z "$SESSION_ID" ]] && exit 0

DIR="$HOME/.local/state/tmux-claude-sessions"
mkdir -p "$DIR"
echo "$SESSION_ID" > "$DIR/$TMUX_PANE"
