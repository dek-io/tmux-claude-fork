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
  # Auto-accept startup dialogs (trust + dev channels) by polling pane
  # content for "Enter to confirm" and sending Enter when detected.
  # Uses $TMUX_PANE (set per-pane by tmux) — tmux display-message returns
  # the *active* pane which is wrong when cc is launched via send-keys.
  if [[ -n "$TMUX_PANE" ]]; then
    local pane="$TMUX_PANE"
    (local sent=0
    for _ in {1..20}; do
      sleep 0.5
      if tmux capture-pane -t "$pane" -p -J 2>/dev/null | grep -q "Enter to confirm"; then
        tmux send-keys -t "$pane" Enter
        sent=1
      elif [ "$sent" = 1 ]; then
        break
      fi
    done) &
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
