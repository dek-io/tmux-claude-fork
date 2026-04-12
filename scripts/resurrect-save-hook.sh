#!/usr/bin/env bash
#
# tmux-resurrect post-save hook: normalizes Claude pane commands to
# `cc --resume <id>` so resurrect restores sessions via the cc wrapper
# (which applies CC_DEFAULT_FLAGS and auto-accepts startup dialogs).
#
# For fork commands (--session-id A --resume B --fork-session), uses
# --session-id (the forked session) as the resume target.
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
    pane_dir="${fields[7]:-}"

    if [[ "$full_cmd" == *claude* ]]; then
      resume_id=""
      # Prefer --session-id (this session) over --resume (parent for forks)
      if [[ "$full_cmd" =~ --session-id[[:space:]]([0-9a-f-]+) ]]; then
        resume_id="${BASH_REMATCH[1]}"
      elif [[ "$full_cmd" =~ --resume[[:space:]]([0-9a-f-]+) ]]; then
        resume_id="${BASH_REMATCH[1]}"
      fi
      if [[ -n "$resume_id" ]]; then
        fields[10]=":cc --resume $resume_id"
      fi

      # Strip .claude/worktrees/<name> from Claude pane dirs so resurrect
      # restores into the original project dir (where the session JSONL lives).
      if [[ "$pane_dir" == */.claude/worktrees/* ]]; then
        fields[7]="${pane_dir%%/.claude/worktrees/*}"
      fi
    fi

    if [[ "${fields[10]:-}" != "$full_cmd" || "${fields[7]:-}" != "$pane_dir" ]]; then
      line="$(IFS=$'\t'; echo "${fields[*]}")"
    fi
  fi
  printf '%s\n' "$line"
done < "$SAVE_FILE" > "$TMP_FILE"

# Atomic replace
mv "$TMP_FILE" "$SAVE_FILE"
