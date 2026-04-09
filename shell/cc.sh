#!/usr/bin/env bash
# Source this file in your shell profile (~/.zshrc or ~/.bashrc):
#   source /path/to/tmux-claude-fork/shell/cc.sh
#
# Provides `cc` (and `ccf` for fast mode) wrappers that assign each Claude
# session a UUID via --session-id. The fork scripts read this UUID from the
# process args — no hooks or tracking files needed.
#
# Set CC_DEFAULT_FLAGS before sourcing to inject default flags into every cc call:
#   CC_DEFAULT_FLAGS=(--dangerously-skip-permissions --effort max)
#   source /path/to/tmux-claude-fork/shell/cc.sh

# Remove any existing alias before defining function
unalias cc 2>/dev/null
unalias ccf 2>/dev/null
unalias ccs 2>/dev/null

_cc_run() {
  # Auto-accept startup dialogs (trust + dev channels) via tmux send-keys.
  # No PTY wrapper needed — claude runs with direct TTY access.
  if [[ -n "$TMUX" ]]; then
    local pane
    pane=$(tmux display-message -p '#{pane_id}')
    # Send Enter twice with delay to handle up to 2 sequential dialogs
    (sleep 0.3 && tmux send-keys -t "$pane" Enter \
     && sleep 0.3 && tmux send-keys -t "$pane" Enter) &
    disown
  fi
  command claude "$@"
}

cc() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "--session-id" || "$arg" == "--resume" ]]; then
      _cc_run "${CC_DEFAULT_FLAGS[@]}" "$@"
      return
    fi
  done
  _cc_run --session-id "$(uuidgen | tr '[:upper:]' '[:lower:]')" "${CC_DEFAULT_FLAGS[@]}" "$@"
}

ccf() {
  cc --settings '{"fastMode": true}' "$@"
}

ccs() {
  cc --model claude-sonnet-4-6 "$@"
}
