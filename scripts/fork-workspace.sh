#!/usr/bin/env bash
#
# Fork a Claude Code session into a new tmux pane with an isolated workspace.
#
# Workspace mode is read from @claude-workspace-mode (default: auto-detect).
#   git    — git worktree add
#   jj     — jj workspace add
#   tmpdir — plain temp directory, no VCS
#   custom — run @claude-workspace-setup with $SOURCE_DIR and $WORKSPACE_DIR
#
# Auto-detection order: jj → git → tmpdir

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC_SH="$SCRIPT_DIR/../shell/cc.sh"

PANE_PID=$(tmux display-message -p '#{pane_pid}')
SOURCE_DIR=$(tmux display-message -p '#{pane_current_path}')

source "$SCRIPT_DIR/lib/get-session-id.sh"

# --- Workspace mode --------------------------------------------------------
# Priority: .claude-fork in repo root → tmux option → auto-detect

MODE=""
SETUP_CMD=""

# Check for per-repo config (.claude-fork file)
# Walk up from SOURCE_DIR to find repo root
_dir="$SOURCE_DIR"
while [[ "$_dir" != "/" ]]; do
  if [[ -f "$_dir/.claude-fork" ]]; then
    while IFS='=' read -r key value; do
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      case "$key" in
        mode)  MODE="$value" ;;
        setup) SETUP_CMD="$value" ;;
      esac
    done < "$_dir/.claude-fork"
    break
  fi
  _dir=$(dirname "$_dir")
done

# Fall back to tmux options
if [[ -z "$MODE" ]]; then
  MODE=$(tmux show-option -gqv @claude-workspace-mode)
fi

# Auto-detect
if [[ -z "$MODE" ]]; then
  if [[ -d "$SOURCE_DIR/.jj" ]] || (cd "$SOURCE_DIR" && jj root &>/dev/null); then
    MODE="jj"
  elif (cd "$SOURCE_DIR" && git rev-parse --is-inside-work-tree &>/dev/null); then
    MODE="git"
  else
    MODE="tmpdir"
  fi
fi

# --- Create workspace ------------------------------------------------------

SUFFIX=$(date +%s | tail -c 7)

case "$MODE" in
  git)
    WORKSPACE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claude-ws-XXXXXX")
    BRANCH="claude-fork-${SUFFIX}"
    if ! git -C "$SOURCE_DIR" worktree add "$WORKSPACE_DIR" -b "$BRANCH" 2>/dev/null; then
      tmux display-message "git worktree add failed"
      rm -rf "$WORKSPACE_DIR"
      exit 1
    fi
    ;;
  jj)
    WORKSPACE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claude-ws-XXXXXX")
    if ! jj -R "$SOURCE_DIR" workspace add "$WORKSPACE_DIR" 2>/dev/null; then
      tmux display-message "jj workspace add failed"
      rm -rf "$WORKSPACE_DIR"
      exit 1
    fi
    ;;
  tmpdir)
    WORKSPACE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claude-ws-XXXXXX")
    ;;
  custom)
    WORKSPACE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/claude-ws-XXXXXX")
    # SETUP_CMD may come from .claude-fork; fall back to tmux option
    if [[ -z "$SETUP_CMD" ]]; then
      SETUP_CMD=$(tmux show-option -gqv @claude-workspace-setup)
    fi
    if [[ -z "$SETUP_CMD" ]]; then
      tmux display-message "@claude-workspace-setup not set"
      rm -rf "$WORKSPACE_DIR"
      exit 1
    fi
    export SOURCE_DIR WORKSPACE_DIR
    if ! eval "$SETUP_CMD"; then
      tmux display-message "workspace setup command failed"
      rm -rf "$WORKSPACE_DIR"
      exit 1
    fi
    ;;
  *)
    tmux display-message "Unknown workspace mode: $MODE"
    exit 1
    ;;
esac

# --- Launch ----------------------------------------------------------------

NEW_PANE=$(tmux split-window -h -c "$WORKSPACE_DIR" -P -F '#{pane_id}')
tmux send-keys -t "$NEW_PANE" "source '$CC_SH' && cc --resume '$SESSION_ID' --fork-session" Enter
