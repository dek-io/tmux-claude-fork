# tmux-claude-fork

Fork a running Claude Code session into a new tmux pane or iTerm2 tab. Optionally create an isolated workspace (git worktree, jj workspace, or custom).

Point your Claude Code agent at this README to install:

> Install the tmux-claude-fork plugin from this repo. Follow the instructions below exactly.

## How it works

1. A Claude Code `SessionStart` hook writes the active session ID to `/tmp/claude-sessions/<pane_id>` (tmux) or `/tmp/claude-sessions/<tty_name>` (iTerm2) whenever a session starts or is resumed
2. A keybinding forks the session into a new pane/tab
3. A wrapper script detects the real forked session ID so that forking a fork works correctly

## Key bindings

### tmux

| Binding | Action |
|---------|--------|
| `Prefix + C-f` | Fork session in same directory |
| `Prefix + C-g` | Fork session in new workspace |

### iTerm2

| Binding | Action |
|---------|--------|
| `Cmd + §` (or your choice) | Fork session in new tab |

## Install (tmux)

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

### 4. Load the plugin in your tmux config

Add before your TPM `run-shell` line (if using TPM):

```tmux
run-shell '~/.config/tmux/plugins/tmux-claude-fork/tmux-claude-fork.tmux'
```

Then reload: `tmux source ~/.config/tmux/tmux.conf`

## Install (iTerm2)

### 1. Copy the hook and scripts

```bash
mkdir -p ~/.claude/hooks ~/.claude/scripts
cp hooks/track-session.sh ~/.claude/hooks/track-session.sh
cp scripts/fork-wrapper.sh ~/.claude/scripts/fork-wrapper.sh
cp scripts/iterm-fork-claude.sh ~/.claude/scripts/iterm-fork-claude.sh
chmod +x ~/.claude/hooks/track-session.sh ~/.claude/scripts/fork-wrapper.sh ~/.claude/scripts/iterm-fork-claude.sh
```

### 2. Register the hook in `~/.claude/settings.json`

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

### 3. Set up the iTerm2 keybinding (manual step)

1. Open **iTerm2 → Settings → Profiles → Keys → Key Bindings**
2. Click **+** to add a new mapping
3. Press your desired keyboard shortcut (e.g., **Cmd+§**)
4. Set Action to **"Run Coprocess"**
5. Set the command to: `~/.claude/scripts/iterm-fork-claude.sh`
6. Click **OK**

> **Note:** The fork works mid-session (even while Claude is busy) because the keybinding is handled by iTerm2, not by Claude Code.

## Workspace modes (tmux only)

Configuration priority: `.claude-fork` file in repo root → tmux options → auto-detect.

The workspace fork (`Prefix + C-g`) auto-detects your VCS:

| Mode | Detection | What it does |
|------|-----------|-------------|
| `jj` | `.jj` directory or `jj root` succeeds | `jj workspace add <tmpdir>` |
| `git` | Inside a git work tree | `git worktree add <tmpdir> -b claude-fork-<id>` |
| `tmpdir` | Fallback | Plain temp directory |
| `custom` | Explicit config | Runs your command with `$SOURCE_DIR` and `$WORKSPACE_DIR` |

### Force a specific mode

```tmux
set-option -g @claude-workspace-mode jj
```

### Custom setup command

```tmux
set-option -g @claude-workspace-mode custom
set-option -g @claude-workspace-setup 'cp -r "$SOURCE_DIR" "$WORKSPACE_DIR"'
```

`$SOURCE_DIR` and `$WORKSPACE_DIR` are exported as environment variables before the command runs.

## Per-repo configuration

Create a `.claude-fork` file in your repo root:

```ini
mode=jj
```

For custom mode:

```ini
mode=custom
setup=my-worktree-tool create "$WORKSPACE_DIR" --from "$SOURCE_DIR"
```

This overrides tmux options for that repo. The file is searched by walking up from the current directory.

## Configuration (tmux)

```tmux
# Change fork key (default: C-f)
set-option -g @claude-fork-key C-f

# Change workspace key (default: C-g)
set-option -g @claude-workspace-key C-g

# Force workspace mode (default: auto-detect)
set-option -g @claude-workspace-mode git

# Custom workspace setup command (requires mode=custom)
set-option -g @claude-workspace-setup 'my-worktree-tool create "$WORKSPACE_DIR" --from "$SOURCE_DIR"'
```

## Permission mode

The forked session preserves the original session's permission mode:

- **tmux:** Always uses `--dangerously-skip-permissions` (matching original behavior)
- **iTerm2:** Reads the `permission_mode` from the session tracking file and passes the corresponding flag. Falls back to `--dangerously-skip-permissions` if the mode cannot be determined.

## Requirements

- **tmux** or **iTerm2** (macOS)
- `jq` (for parsing hook JSON)
- Claude Code with hooks support
- `git` or `jj` (for workspace modes, optional)
