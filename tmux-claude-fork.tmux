#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORK_KEY=$(tmux show-option -gqv @claude-fork-key)
FORK_KEY=${FORK_KEY:-C-f}

WORKSPACE_KEY=$(tmux show-option -gqv @claude-workspace-key)
WORKSPACE_KEY=${WORKSPACE_KEY:-C-g}

tmux bind-key "$FORK_KEY" run-shell "$CURRENT_DIR/scripts/fork-claude.sh"
tmux bind-key "$WORKSPACE_KEY" run-shell "$CURRENT_DIR/scripts/fork-workspace.sh"

# Register resurrect post-save hook to inject --resume into Claude pane commands
tmux set-option -g @resurrect-hook-post-save-layout "$CURRENT_DIR/scripts/resurrect-save-hook.sh"
