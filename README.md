# Claude Code Plugins

A collection of Claude Code plugins for security, git workflows, and code review. Designed for trunk-based development.

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

Commits and pushes directly to trunk with linear history, supporting git worktrees for feature branch development. Uses the `commit-commands` namespace to appear alongside the official `commit-commands` plugin from `anthropics/claude-plugins-official`.

**Command:** `/commit-commands:commit-push-trunk`

**How it works:**
- Detects whether you're on trunk or a feature branch (worktree)
- Stages and commits with an appropriate message
- Uses `--rebase` for pulls and `--ff-only` for merges to maintain linear history
- Handles cross-repo operations when working in worktrees

**Requirements:** Git

### code-review-local

Automated code review for local uncommitted or unpushed changes. Designed for trunk-based development where you review before committing or pushing.

**How it works:**
- Asks whether to review uncommitted changes or unpushed commits
- Launches 5 parallel agents to review from different perspectives
- Uses confidence scoring (0-100) to filter false positives
- Only reports issues with 80+ confidence score
- Outputs review directly to terminal (no PR required)

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
/plugin install commit-commands@danielbodart-plugins
/plugin install code-review-local@danielbodart-plugins
```

## Local Testing

Test plugins locally before publishing:
```bash
claude --plugin-dir ./graphical-sudo
claude --plugin-dir ./url-allowlist
claude --plugin-dir ./commit-push-trunk
claude --plugin-dir ./code-review-local
```

## License

MIT
