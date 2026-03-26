#!/usr/bin/env bash
#
# tmux-resurrect post-save hook: injects `--resume <session_id>` into Claude
# pane commands so that resurrect restores each Claude session automatically.
#
# Parses --session-id from the saved command args — no tracking files needed.
# Called by resurrect with the save file path as $1.

set -euo pipefail

SAVE_FILE="$1"

# Don't block resurrect saves on failure
trap 'exit 0' ERR

[[ -f "$SAVE_FILE" ]] || exit 0

TMP_FILE=$(mktemp "${SAVE_FILE}.XXXXXX")

while IFS= read -r line; do
  if [[ "$line" == pane$'\t'* ]]; then
    IFS=$'\t' read -ra fields <<< "$line"
    full_cmd="${fields[10]:-}"

    if [[ "$full_cmd" == *claude* && "$full_cmd" != *--resume* ]]; then
      if [[ "$full_cmd" =~ --session-id[[:space:]]([0-9a-f-]+) ]]; then
        fields[10]=":claude --resume ${BASH_REMATCH[1]}"
        line="$(IFS=$'\t'; echo "${fields[*]}")"
      fi
    fi
  fi
  printf '%s\n' "$line"
done < "$SAVE_FILE" > "$TMP_FILE"

# Atomic replace
mv "$TMP_FILE" "$SAVE_FILE"
