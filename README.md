# tmux-claude-fork

Fork a running Claude Code session into a new tmux pane with `Prefix + C-f`.

Point your Claude Code agent at this README to install:

> Install the tmux-claude-fork plugin from this repo. Follow the instructions below exactly.

## How it works

1. A Claude Code `SessionStart` hook writes the active session ID to `/tmp/claude-sessions/<pane_id>` whenever a session starts or is resumed (including via `/resume`)
2. The tmux key binding reads that file and opens a new pane with `claude --resume <id> --fork-session`

## Install

### 1. Copy the plugin

```bash
# Clone or symlink to your tmux plugins directory
ln -s /path/to/tmux-claude-fork ~/.config/tmux/plugins/tmux-claude-fork
```

### 2. Copy the hook

```bash
mkdir -p ~/.claude/hooks
cp hooks/track-session.sh ~/.claude/hooks/track-session.sh
chmod +x ~/.claude/hooks/track-session.sh
```

### 3. Register the hook in `~/.claude/settings.json`

Add this to your settings (merge with existing keys):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/track-session.sh"
          }
        ]
      }
    ]
  }
}
```

### 4. Load the plugin in `~/.config/tmux/tmux.conf`

Add before your TPM `run-shell` line:

```tmux
run-shell '~/.config/tmux/plugins/tmux-claude-fork/tmux-claude-fork.tmux'
```

Then reload: `tmux source ~/.config/tmux/tmux.conf`

## Configuration

Change the key binding (default `C-f`):

```tmux
set-option -g @claude-fork-key g
```

## Requirements

- tmux
- `jq` (for parsing hook JSON)
- Claude Code with hooks support
