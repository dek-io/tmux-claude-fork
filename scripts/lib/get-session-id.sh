# Extract the --session-id from the Claude process running in the current pane.
# Sourced by fork scripts. Expects PANE_PID to be set.
#
# Sets:
#   SESSION_ID         — the session to --resume from
#   TEAM_NAME          — team name (empty if not in a team)
#   TEAM_PARENT_SID    — parent session id for the team (empty if not in a team)
#
# Exits on error.

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

# --- Detect team context ---------------------------------------------------
# Check sibling panes in the same window for teammates whose
# --parent-session-id matches our SESSION_ID.

TEAM_NAME=""
TEAM_PARENT_SID=""

_current_window=$(tmux display-message -p '#{window_id}')
while IFS= read -r _sibling_pid; do
  [[ "$_sibling_pid" == "$PANE_PID" ]] && continue
  _child=$(pgrep -P "$_sibling_pid" 2>/dev/null | head -1)
  [[ -z "$_child" ]] && continue
  _args=$(ps -o args= -p "$_child" 2>/dev/null)
  if [[ "$_args" =~ --parent-session-id[[:space:]]"$SESSION_ID" ]] && \
     [[ "$_args" =~ --team-name[[:space:]]([^[:space:]]+) ]]; then
    TEAM_NAME="${BASH_REMATCH[1]}"
    TEAM_PARENT_SID="$SESSION_ID"
    break
  fi
done < <(tmux list-panes -t "$_current_window" -F '#{pane_pid}')
