# Claude Code Plugins

A collection of Claude Code plugins for security, git workflows, code review, and web research. Designed for trunk-based development.

## Plugins

### [graphical-sudo](./graphical-sudo/)

Enables graphical password prompts for `sudo` commands on Linux GTK desktops (GNOME, Cinnamon, MATE, Xfce, etc.).

**How it works:**
- Intercepts Bash commands containing `sudo`
- Transforms `sudo` to `sudo -A` with `SUDO_ASKPASS` set to a zenity script
- Zenity shows a graphical password dialog
- Returns the output to Claude without requiring terminal password entry

**Requirements:** `jq`, `zenity` (pre-installed on most GTK desktops)

### [url-allowlist](./url-allowlist/)

Reduces prompt fatigue by automatically approving `WebFetch` for URLs discovered via `WebSearch`. No more clicking "Allow" for every search result.

**How it works:**
- Captures URLs from WebSearch results into an allowlist
- Auto-approves WebFetch for URLs in the allowlist
- Non-search URLs: blocked in autonomous mode, prompted in interactive mode
- Handles redirects automatically

**Trust model:** You're trusting that malicious sites generally don't rank well organically. Brave Search (Claude's search backend) filters adult content and SEO spam, but does NOT explicitly filter malware/phishing URLs—if you need to vet every URL, don't use this plugin.

**Requirements:** `jq`

### [commit-push-trunk](./commit-push-trunk/)

Commits and pushes directly to trunk with linear history, supporting git worktrees for feature branch development. Uses the `commit-commands` namespace to appear alongside the official `commit-commands` plugin from `anthropics/claude-plugins-official`.

**Command:** `/commit-commands:commit-push-trunk`

**How it works:**
- Detects whether you're on trunk or a feature branch (worktree)
- Stages and commits with an appropriate message
- Uses `--rebase` for pulls and `--ff-only` for merges to maintain linear history
- Handles cross-repo operations when working in worktrees

**Requirements:** Git

### [code-review-local](./code-review-local/)

Automated code review for local uncommitted or unpushed changes. Designed for trunk-based development where you review before committing or pushing. Uses the `code-review` namespace to appear alongside the official `code-review` plugin from `anthropics/claude-plugins-official`.

**Command:** `/code-review:code-review-local`

**How it works:**
- Asks whether to review uncommitted changes or unpushed commits
- Launches 5 parallel agents to review from different perspectives
- Uses confidence scoring (0-100) to filter false positives
- Only reports issues with 80+ confidence score
- Outputs review directly to terminal (no PR required)

**Requirements:** Git

### [web-researcher](./web-researcher/)

Deep web research agent that finds and synthesizes information from multiple authoritative sources. Automatically triggered when questions benefit from current web sources.

**How it works:**
- Executes strategic web searches from multiple angles
- Fetches and analyzes content from authoritative sources
- Synthesizes findings with quotes, links, and source attribution
- Notes gaps, conflicts, and version-specific details

**Agent:** `web-researcher` (auto-triggered by Claude when web research is needed)

### [notification-sound](./notification-sound/)

Plays a notification sound when Claude has been waiting for your input for over a minute. Useful for long-running tasks where you've switched to another window.

**How it works:**
- Uses the `Notification` hook with `idle_prompt` matcher (fires after ~60s idle)
- Plays `/usr/share/sounds/freedesktop/stereo/complete.oga` via `paplay`

**Requirements:** `paplay` (from `pulseaudio-utils`, pre-installed on Ubuntu/Debian desktops), `sound-theme-freedesktop`

### [statusline](./statusline/)

A status line showing directory, git branch, context window usage (`C`), and Claude subscription quota — rolling 5-hour (`5`) and weekly (`W`) — plus the model.

**How it works:**
- Not a classic auto-wiring plugin: a `plugin.json` has no `statusLine` field, so you run `/install-statusline` once to merge it into `~/.claude/settings.json`
- The command wraps a deterministic `install.sh` that preserves all other settings and **won't overwrite a custom status line** without `--force`
- Installed as a plugin, it runs in place and **auto-updates with the plugin**; run standalone, it copies itself into `~/.claude`
- Quota bars come from the Anthropic OAuth usage endpoint, cached to `~/.claude/quota-cache.json` and refreshed in the background every 15 min (no daemon)

**Requirements:** `jq`, `curl`, and an OAuth/subscription login (quota bars show `--%` under an `ANTHROPIC_API_KEY` setup)

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
/plugin install code-review@danielbodart-plugins
/plugin install web-researcher@danielbodart-plugins
/plugin install notification-sound@danielbodart-plugins
/plugin install statusline@danielbodart-plugins
```

For `statusline`, also run `/install-statusline` once after enabling it (it can't auto-wire — see [its README](./statusline/)).

## Local Testing

Test plugins locally before publishing:
```bash
claude --plugin-dir ./graphical-sudo
claude --plugin-dir ./url-allowlist
claude --plugin-dir ./commit-push-trunk
claude --plugin-dir ./code-review-local
claude --plugin-dir ./web-researcher
claude --plugin-dir ./notification-sound
claude --plugin-dir ./statusline
```

## License

MIT
