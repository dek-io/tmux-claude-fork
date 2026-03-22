#!/usr/bin/env bash
#
# tmux-resurrect post-save hook: injects `--resume <session_id>` into Claude
# pane commands so that resurrect restores each Claude session automatically.
#
# Called by resurrect with the save file path as $1.

set -euo pipefail

SAVE_FILE="$1"
SESSION_DIR="$HOME/.local/state/tmux-claude-sessions"

# Don't block resurrect saves on failure
trap 'exit 0' ERR

[[ -f "$SAVE_FILE" ]] || exit 0
[[ -d "$SESSION_DIR" ]] || exit 0

# Build map: session_name\twindow_index\tpane_index → pane_id
declare -A PANE_MAP
while IFS=$'\t' read -r sess win pidx pid; do
  PANE_MAP["${sess}	${win}	${pidx}"]="$pid"
done < <(tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_id}')

TMP_FILE=$(mktemp "${SAVE_FILE}.XXXXXX")

while IFS= read -r line; do
  # Try to rewrite Claude pane commands with --resume
  if [[ "$line" == pane$'\t'* ]]; then
    IFS=$'\t' read -ra fields <<< "$line"
    full_cmd="${fields[10]:-}"

    if [[ "$full_cmd" == *claude* && "$full_cmd" != *--resume* ]]; then
      pane_id="${PANE_MAP["${fields[1]}	${fields[2]}	${fields[5]}"]:-}"
      session_file="$SESSION_DIR/$pane_id"

      if [[ -n "$pane_id" && -f "$session_file" ]]; then
        session_id=$(<"$session_file")
        if [[ -n "$session_id" ]]; then
          fields[10]=":claude --resume $session_id"
          line="$(IFS=$'\t'; echo "${fields[*]}")"
        fi
      fi
    fi
  fi
  printf '%s\n' "$line" >> "$TMP_FILE"
done < "$SAVE_FILE"

# Atomic replace
mv "$TMP_FILE" "$SAVE_FILE"
