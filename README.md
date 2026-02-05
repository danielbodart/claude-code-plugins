# Claude Code Plugins

A collection of Claude Code plugins, including security-focused hooks for Linux desktop and web access control.

## Plugins

### graphical-sudo

Replaces `sudo` commands with `pkexec` for graphical authentication on Linux GTK desktops (GNOME, Cinnamon, MATE, etc.).

**How it works:**
- Intercepts Bash commands containing `sudo`
- Replaces `sudo` with `pkexec` and executes via graphical PolicyKit authentication
- Returns the output to Claude without requiring terminal password entry

**Requirements:** `jq`, `pkexec` (pre-installed on most GTK desktops)

### url-allowlist

Restricts `WebFetch` to only URLs discovered via `WebSearch` results, preventing Claude from fetching arbitrary URLs.

**How it works:**
- Captures URLs from WebSearch results into an allowlist
- Validates WebFetch URLs against the allowlist
- In autonomous mode: blocks non-allowlisted URLs
- In interactive mode: prompts user to approve non-allowlisted URLs
- Automatically captures redirect URLs to allow following redirects

**Requirements:** `jq`

### commit-push-trunk

Commits and pushes directly to trunk with linear history, supporting git worktrees for feature branch development.

**How it works:**
- Detects whether you're on trunk or a feature branch (worktree)
- Stages and commits with an appropriate message
- Uses `--rebase` for pulls and `--ff-only` for merges to maintain linear history
- Handles cross-repo operations when working in worktrees

**Requirements:** Git

## Installation

1. Add the marketplace:
```
/plugin marketplace add danielbodart/claude-code-plugins
```

2. Install desired plugins:
```
/plugin install graphical-sudo@danielbodart-plugins
/plugin install url-allowlist@danielbodart-plugins
/plugin install commit-push-trunk@danielbodart-plugins
```

## Local Testing

Test plugins locally before publishing:
```bash
claude --plugin-dir ./graphical-sudo
claude --plugin-dir ./url-allowlist
claude --plugin-dir ./commit-push-trunk
```

## License

MIT
