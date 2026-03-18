#!/usr/bin/env bash
# Writes the active Claude session info to a per-pane/TTY file.
# Triggered by the SessionStart hook on both new sessions and /resume.
#
# Supports both tmux (keyed by $TMUX_PANE) and iTerm2 (keyed by TTY name).
#
# Fork-chain fix: session_id from the hook payload is unreliable for
# --fork-session (it reports the original resumed ID, not the forked one).
# The fork-wrapper.sh script detects the real ID and writes a .fork-id
# marker (ORIGINAL:FORK). If the marker's ORIGINAL matches the hook's
# session_id, we use the FORK ID instead. Otherwise the marker is stale
# and we delete it.

INPUT=$(cat)
HOOK_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
[[ -z "$HOOK_SESSION_ID" ]] && exit 0

PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // "bypassPermissions"')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Determine session key: tmux pane ID or TTY name
if [[ -n "$TMUX_PANE" ]]; then
  KEY="$TMUX_PANE"
else
  KEY=$(ps -o tty= -p $$ 2>/dev/null | tr -d ' ')
  [[ -z "$KEY" || "$KEY" == "??" ]] && exit 0
fi

DIR="/tmp/claude-sessions"
TRACKING="$DIR/$KEY"
FORK_MARKER="${TRACKING}.fork-id"
mkdir -p "$DIR"

SESSION_ID="$HOOK_SESSION_ID"

# Check if the wrapper wrote a corrected fork ID
if [[ -f "$FORK_MARKER" ]]; then
  MARKER_CONTENT=$(cat "$FORK_MARKER")
  MARKER_ORIGINAL="${MARKER_CONTENT%%:*}"
  MARKER_FORK="${MARKER_CONTENT#*:}"

  if [[ "$HOOK_SESSION_ID" == "$MARKER_ORIGINAL" && -n "$MARKER_FORK" ]]; then
    SESSION_ID="$MARKER_FORK"
  else
    rm -f "$FORK_MARKER"
  fi
fi

jq -n \
  --arg sid "$SESSION_ID" \
  --arg mode "$PERMISSION_MODE" \
  --arg cwd "$CWD" \
  '{session_id: $sid, permission_mode: $mode, cwd: $cwd}' \
  > "$TRACKING"
