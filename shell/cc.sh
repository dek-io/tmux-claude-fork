#!/usr/bin/env bash
# Source this file in your shell profile (~/.zshrc or ~/.bashrc):
#   source /path/to/tmux-claude-fork/shell/cc.sh
#
# Provides `cc` (and `ccf` for fast mode) wrappers that assign each Claude
# session a UUID via --session-id. The fork scripts read this UUID from the
# process args — no hooks or tracking files needed.

# Remove any existing alias before defining function
unalias cc 2>/dev/null
unalias ccf 2>/dev/null

cc() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "--session-id" ]]; then
      command claude "$@"
      return
    fi
  done
  command claude --session-id "$(uuidgen | tr '[:upper:]' '[:lower:]')" "$@"
}

ccf() {
  cc --fast "$@"
}
