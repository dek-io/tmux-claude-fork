#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KEY=$(tmux show-option -gqv @claude-fork-key)
KEY=${KEY:-C-f}

tmux bind-key "$KEY" run-shell "$CURRENT_DIR/scripts/fork-claude.sh"
