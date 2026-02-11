# ocm-container-custom

Simple `Makefile` and `Dockerfile` to build [ocm-container](https://github.com/openshift/ocm-contianer) with the backplane-cli
and SRE utils from OPS-SOP. It can be easily extended or customized to add your own tools.

Please consider creating PRs upstream for things that may be useful to others, however.

## Usage

Source your ocm-container config (`source ~/.config/ocm-container/env.source`) and then build the container image ocm-container:latest with backplane and SRE tools by running the command `make`:

```shell
# Build ocm-container with backplane-cli and SRE tooling
$ source ~/.config/ocm-container/env.source
$ make
```

## Claude Code Integration

This container includes [Claude Code](https://claude.ai/claude-code), Anthropic's AI-powered coding assistant, installed via a secure multi-stage build process.

### Security Features

- **No script-to-bash piping**: Binary is downloaded directly using container `ADD` instruction
- **Checksum verification**: SHA256 checksum is verified during build (build fails on mismatch)
- **Version pinning**: Explicit version control for reproducible builds
- **Auditable**: All parameters (version, checksum, platform) are hardcoded in the Containerfile

### Installation Details

The Claude Code installation uses a dedicated build stage (`claude-builder`) that:

1. Downloads the official Claude Code binary for `linux-x64` platform from Google Cloud Storage
2. Verifies the binary's SHA256 checksum against the hardcoded value from the manifest
3. Copies the verified binary to `/usr/local/bin/claude` in the final image
4. Runs `claude install` to set up shell integration and launchers

### Required Volume Mounts

For Claude Code to function properly in the container, add these volume mounts to your `~/.config/ocm-container/ocm-container.yaml`:

```yaml
volumeMounts:
  # Claude Code configuration and state (read-write)
  - /home/YOUR_USERNAME/.claude/:/root/.claude:rw
  - /home/YOUR_USERNAME/.config/claude/:/root/.config/claude/:rw
  - /home/YOUR_USERNAME/.claude.json:/root/.claude.json:rw
```

**What each mount provides:**

- **`~/.claude/`** - Main Claude Code directory
  - Downloads, sessions, and runtime state
  - Read-write access allows Claude to save sessions and update itself

- **`~/.config/claude/`** - Claude configuration directory
  - Your CLAUDE.md supplemental configs (CLAUDE.md.d/)
  - Settings and preferences
  - Read-write access allows configuration updates

- **`~/.claude.json`** - Claude authentication file
  - API keys and user credentials
  - Authentication tokens
  - Read-write for credential updates

**Benefits of these mounts:**

✅ **Persistent configuration** - Settings and API keys shared between host and container
✅ **Session continuity** - Claude sessions persist across container restarts
✅ **Shared custom configs** - Your CLAUDE.md instructions available inside the container
✅ **Unified environment** - Same Claude setup on host and in ocm-container

### Updating Claude Code

To update to the latest version of Claude Code, run:

```shell
make update-claude-version
```

This target will:

1. Fetch the latest version number from the Claude Code release channel
2. Download the manifest.json for that version
3. Extract the SHA256 checksum for the `linux-x64` platform
4. Update the following values in the Containerfile:
   - `CLAUDE_VERSION` - version number
   - `CLAUDE_CHECKSUM` - SHA256 checksum
   - Version comment - build date

**After running the update:**

```shell
# Review the changes
git diff Containerfile

# Test the build
make build_custom

# Commit the update
git add Containerfile
git commit -m "Update Claude Code to version X.Y.Z"
```

### Manual Version Control

If you prefer to manually set a specific Claude Code version:

1. Visit https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/latest to get the version number
2. Download the manifest: `https://storage.googleapis.com/.../claude-code-releases/VERSION/manifest.json`
3. Extract the `linux-x64` checksum from the manifest
4. Update three ARG values in the `claude-builder` stage of the Containerfile:
   - `CLAUDE_VERSION`
   - `CLAUDE_CHECKSUM`
   - Update the version comment with the build date

### Tmux Integration

The container includes a comprehensive tmux configuration that automatically sets up your workspace.

#### Automatic Session Setup

When the container starts, tmux automatically:
- Creates a new session with a split-pane layout
- Launches Claude Code in a background pane (30% height, bottom)
- Displays your SRE terminal in the main pane (70% height, top, zoomed)
- Shows `osdctl cluster context` output (if `CLUSTER_ID` is set)

**Layout:**
```
┌─────────────────────────────────┐
│                                 │
│  SRE Terminal (zoomed)          │
│  - osdctl cluster context       │
│  - Your normal workflow         │
│                                 │
│  Press Ctrl-b z to toggle       │
│                                 │
└─────────────────────────────────┘

(Claude running in hidden pane below - toggle with Ctrl-b z)
```

#### Tmux Configuration Features

The `.tmux.conf` provides:

- **Mouse support** - Click to switch panes, drag to resize, scroll with mouse wheel
- **Large scrollback buffer** - 50,000 lines for reviewing logs and command output
- **Auto-initialization hook** - Claude pane setup happens automatically on any new session
- **Custom status bar** - Date and time display in the right corner
- **Color-coded pane borders** - Active pane highlighted in cyan for easy identification
- **Window auto-renumbering** - Sequential numbering maintained when windows are closed

#### Tmux Keybindings

Common commands you'll use:

- `Ctrl-b z` - Toggle zoom to show/hide the Claude pane
- `Ctrl-b o` - Switch focus between panes (or just click with mouse)
- `Ctrl-b "` - Create additional horizontal pane splits
- `Ctrl-b %` - Create additional vertical pane splits
- `Ctrl-b c` - Create a new window
- `Ctrl-b [` - Enter copy mode for scrollback navigation
- `Ctrl-b d` - Detach from session (container keeps running)

#### Mouse Support

With mouse mode enabled, you can:
- Click on any pane to switch to it
- Drag the pane divider to resize splits
- Scroll through command history with the mouse wheel
- Select and copy text (behavior varies by terminal emulator)

#### Configuration Files

Tmux behavior is controlled by:
- `.tmux.conf` - Main tmux configuration with settings and hooks
- `bashrc.d/tmux.bashrc` - Auto-starts tmux on container login

This setup ensures Claude is immediately available without interrupting your SRE workflow. Simply toggle the zoom when you need to interact with Claude for code assistance, incident analysis, or other tasks.
