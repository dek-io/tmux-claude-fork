#!/usr/bin/env bash
# Fork a running Claude Code session into a new iTerm2 tab.
# Triggered by an iTerm2 keybinding as a coprocess.
#
# Coprocess I/O: stdin receives terminal output, stdout sends input to terminal.
# We drain stdin and use a group redirect to /dev/null so the original pipe
# fds stay open and iTerm2 does not tear us down prematurely.

WRAPPER="$HOME/.claude/scripts/fork-wrapper.sh"

# Drain coprocess stdin in background to prevent pipe buffer backup
cat >/dev/null &
DRAIN_PID=$!

# Run all logic inside a group redirect so stdout/stderr go to /dev/null
# but the original fd 1 (pipe to iTerm2) is NOT closed.
{
  # Get current session's TTY via AppleScript
  TTY_PATH=$(osascript -e 'tell application "iTerm2" to tell current window to tell current session to return tty')

  if [[ -z "$TTY_PATH" ]]; then
    osascript -e 'display notification "Could not detect iTerm2 session" with title "Claude Fork"'
    kill $DRAIN_PID 2>/dev/null
    exit 1
  fi

  TTY_NAME=$(basename "$TTY_PATH")
  SESSION_FILE="/tmp/claude-sessions/$TTY_NAME"

  if [[ ! -f "$SESSION_FILE" ]]; then
    osascript -e 'display notification "No Claude session tracked for this tab" with title "Claude Fork"'
    kill $DRAIN_PID 2>/dev/null
    exit 1
  fi

  SESSION_ID=$(jq -r '.session_id' "$SESSION_FILE")
  PERMISSION_MODE=$(jq -r '.permission_mode // "bypassPermissions"' "$SESSION_FILE")
  CWD=$(jq -r '.cwd // ""' "$SESSION_FILE")

  if [[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]]; then
    osascript -e 'display notification "No Claude session found" with title "Claude Fork"'
    kill $DRAIN_PID 2>/dev/null
    exit 1
  fi

  # Default CWD to home if missing
  [[ -z "$CWD" || "$CWD" == "null" ]] && CWD="$HOME"

  # Map permission mode to CLI flag
  case "$PERMISSION_MODE" in
    bypassPermissions) MODE_FLAG="--dangerously-skip-permissions" ;;
    *)                 MODE_FLAG="--permission-mode $PERMISSION_MODE" ;;
  esac

  # Escape single quotes in CWD for shell use inside AppleScript
  ESCAPED_CWD="${CWD//\'/\'\\\'\'}"

  osascript <<APPLESCRIPT
tell application "iTerm2"
  tell current window
    set newTab to (create tab with default profile)
    tell current session of newTab
      write text "cd '${ESCAPED_CWD}' && '${WRAPPER}' '${SESSION_ID}' ${MODE_FLAG}"
    end tell
  end tell
end tell
APPLESCRIPT
} >/dev/null 2>&1

# Clean up the stdin drain process
kill $DRAIN_PID 2>/dev/null
wait $DRAIN_PID 2>/dev/null
