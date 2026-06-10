# Extract the --session-id from the Claude process running in the current pane.
# Sourced by fork scripts. Expects PANE_PID to be set.
#
# Sets:
#   SESSION_ID         — the session to --resume from
#   CLAUDE_PID         — pid of the Claude process found in the pane
#   LAUNCHER           — wrapper to relaunch forks with (from CC_LAUNCHER in
#                        the Claude process env; defaults to "cc")
#   TEAM_NAME          — team name (empty if not in a team)
#   TEAM_PARENT_SID    — parent session id for the team (empty if not in a team)
#
# Exits on error.

# Find the Claude process among a pane's descendants. It is not always the
# first direct child: wrappers like cccr/ccc launch cc from a subshell (so
# claude is a grandchild), and cc's dialog auto-accept poller is a short-lived
# sibling with a lower pid. BFS over the tree, match on --session-id/--resume,
# shallowest match wins.
_find_claude() {
  local queue=("$1") next=() pid child args depth
  for depth in 1 2 3 4 5; do
    for pid in "${queue[@]}"; do
      for child in $(pgrep -P "$pid" 2>/dev/null); do
        args=$(ps -o args= -p "$child" 2>/dev/null)
        if [[ "$args" =~ --session-id[[:space:]][0-9a-f-]+ ]] || \
           [[ "$args" =~ --resume[[:space:]][0-9a-f-]+ ]]; then
          echo "$child"
          return 0
        fi
        next+=("$child")
      done
    done
    [[ ${#next[@]} -eq 0 ]] && return 1
    queue=("${next[@]}")
    next=()
  done
  return 1
}

CLAUDE_PID=$(_find_claude "$PANE_PID")
if [[ -z "$CLAUDE_PID" ]]; then
  tmux display-message "No Claude with --session-id/--resume in this pane (start Claude with cc)"
  exit 0
fi

CLAUDE_ARGS=$(ps -o args= -p "$CLAUDE_PID" 2>/dev/null)
if [[ "$CLAUDE_ARGS" =~ --session-id[[:space:]]([0-9a-f-]+) ]]; then
  SESSION_ID="${BASH_REMATCH[1]}"
elif [[ "$CLAUDE_ARGS" =~ --resume[[:space:]]([0-9a-f-]+) ]]; then
  SESSION_ID="${BASH_REMATCH[1]}"
else
  tmux display-message "No --session-id or --resume found (start Claude with cc)"
  exit 0
fi

# --- Detect launcher ---------------------------------------------------------
# Relaunch forks with the same wrapper the parent was started with (cc, ccf,
# cccr, ...). Wrappers advertise themselves via CC_LAUNCHER in claude's env.
# /proc is Linux-only; elsewhere fall back to cc.

LAUNCHER="cc"
if [[ -r "/proc/$CLAUDE_PID/environ" ]]; then
  _launcher=$(tr '\0' '\n' < "/proc/$CLAUDE_PID/environ" | grep -m1 '^CC_LAUNCHER=' | cut -d= -f2)
  [[ "$_launcher" =~ ^[A-Za-z0-9_-]+$ ]] && LAUNCHER="$_launcher"
fi

# --- Detect team context ---------------------------------------------------
# Check sibling panes in the same window for teammates whose
# --parent-session-id matches our SESSION_ID.

TEAM_NAME=""
TEAM_PARENT_SID=""

_current_window=$(tmux display-message -p '#{window_id}')
while IFS= read -r _sibling_pid; do
  [[ "$_sibling_pid" == "$PANE_PID" ]] && continue
  _child=$(_find_claude "$_sibling_pid")
  [[ -z "$_child" ]] && continue
  _args=$(ps -o args= -p "$_child" 2>/dev/null)
  if [[ "$_args" =~ --parent-session-id[[:space:]]"$SESSION_ID" ]] && \
     [[ "$_args" =~ --team-name[[:space:]]([^[:space:]]+) ]]; then
    TEAM_NAME="${BASH_REMATCH[1]}"
    TEAM_PARENT_SID="$SESSION_ID"
    break
  fi
done < <(tmux list-panes -t "$_current_window" -F '#{pane_pid}')
