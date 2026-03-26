# Extract the --session-id from the Claude process running in the current pane.
# Sourced by fork scripts. Expects PANE_PID to be set. Sets SESSION_ID or exits.

CHILD_PID=$(pgrep -P "$PANE_PID" | head -1)
if [[ -z "$CHILD_PID" ]]; then
  tmux display-message "No process running in this pane"
  exit 0
fi

CLAUDE_ARGS=$(ps -o args= -p "$CHILD_PID" 2>/dev/null)
if [[ "$CLAUDE_ARGS" =~ --session-id[[:space:]]([0-9a-f-]+) ]]; then
  SESSION_ID="${BASH_REMATCH[1]}"
elif [[ "$CLAUDE_ARGS" =~ --resume[[:space:]]([0-9a-f-]+) ]]; then
  SESSION_ID="${BASH_REMATCH[1]}"
else
  tmux display-message "No --session-id or --resume found (start Claude with cc)"
  exit 0
fi

# Check that the session has a JSONL transcript (created on first message)
CWD=$(tmux display-message -p '#{pane_current_path}')
SANITIZED_CWD=$(cd "$CWD" && pwd -P | tr '/' '-')
if ! ls "$HOME/.claude/projects/$SANITIZED_CWD/$SESSION_ID".jsonl &>/dev/null; then
  tmux display-message "Send a message first — session has no transcript yet"
  exit 0
fi
