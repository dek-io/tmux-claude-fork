#!/usr/bin/env bash
# Wrapper for forked Claude Code sessions.
# Detects the real forked session ID (which differs from the --resume'd one)
# by watching for a newly created .jsonl transcript file, then updates the
# per-pane/TTY tracking file so that re-forking works correctly.
#
# Works with both tmux and iTerm2.
#
# Usage: fork-wrapper.sh <session-id> [claude-args...]

ORIGINAL_ID="$1"
shift
CLAUDE_ARGS=("$@")

CWD=$(pwd)
SANITIZED_CWD=$(echo "$CWD" | tr '/' '-')
SESSIONS_DIR="$HOME/.claude/projects/$SANITIZED_CWD"

# Determine tracking key: tmux pane ID or TTY name
if [[ -n "$TMUX_PANE" ]]; then
  KEY="$TMUX_PANE"
else
  TTY_PATH=$(tty 2>/dev/null)
  if [[ $? -eq 0 && -n "$TTY_PATH" ]]; then
    KEY=$(basename "$TTY_PATH")
  else
    KEY=$(ps -o tty= -p $$ 2>/dev/null | tr -d ' ')
  fi
fi

# If we can't determine the key, just launch Claude without tracking
[[ -z "$KEY" ]] && exec claude --resume "$ORIGINAL_ID" --fork-session "${CLAUDE_ARGS[@]}"

# Clean up any stale marker from a previous fork on this pane/TTY
rm -f "/tmp/claude-sessions/${KEY}.fork-id"

# Snapshot existing JSONL files before Claude creates the forked one
BEFORE=$(ls "$SESSIONS_DIR"/*.jsonl 2>/dev/null | sort)

# Background: poll for a new JSONL file and update the tracking file
(
  for _ in $(seq 1 30); do
    sleep 1
    AFTER=$(ls "$SESSIONS_DIR"/*.jsonl 2>/dev/null | sort)
    NEW_FILE=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | head -1)
    if [[ -n "$NEW_FILE" ]]; then
      NEW_ID=$(basename "$NEW_FILE" .jsonl)
      TRACKING="/tmp/claude-sessions/$KEY"

      # Write marker as ORIGINAL_ID:FORK_ID so the hook can validate
      echo "${ORIGINAL_ID}:${NEW_ID}" > "${TRACKING}.fork-id"

      if [[ -f "$TRACKING" ]]; then
        TMP="${TRACKING}.tmp.$$"
        jq --arg sid "$NEW_ID" '.session_id = $sid' "$TRACKING" > "$TMP" && mv "$TMP" "$TRACKING"
      else
        mkdir -p /tmp/claude-sessions
        jq -n --arg sid "$NEW_ID" --arg mode "bypassPermissions" --arg cwd "$CWD" \
          '{session_id: $sid, permission_mode: $mode, cwd: $cwd}' > "$TRACKING"
      fi
      break
    fi
  done
) &

# Launch Claude — exec replaces this process so the terminal behaves normally
exec claude --resume "$ORIGINAL_ID" --fork-session "${CLAUDE_ARGS[@]}"
