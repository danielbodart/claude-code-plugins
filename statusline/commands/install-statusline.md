---
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/install.sh:*), Bash(jq:*), Read
description: Install the statusline (directory, branch, context, and subscription quota) into ~/.claude
args: "[--force]"
---

Install this plugin's status line into `~/.claude`. The heavy lifting is done by
the deterministic engine at `${CLAUDE_PLUGIN_ROOT}/install.sh`; your job is to be
the safe, judgement-adding wrapper around it so an existing custom status line is
never clobbered silently.

**Arguments:** Pass `--force` to replace an existing custom status line without
prompting (e.g. `/install-statusline --force`).

## Context

- Current statusLine command (if any): !`jq -r '.statusLine.command // "(none)"' "$HOME/.claude/settings.json" 2>/dev/null || echo "(no settings.json)"`
- Dry-run preview of what the installer would do: !`bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --dry-run 2>&1`

## What to do

1. Look at the current statusLine command above.

2. **If it is `(none)` or already `bash "$HOME/.claude/statusline.sh"`** (this
   plugin's own command): just run the installer — it is a safe no-op or a clean
   install.
   ```
   bash "${CLAUDE_PLUGIN_ROOT}/install.sh"
   ```

3. **If it is some OTHER command** (the user has a custom status line):
   - **If `--force` was passed**: proceed directly:
     ```
     bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --force
     ```
   - **Otherwise**: do NOT overwrite it blind. Show the user their existing
     command and this plugin's command, explain that installing will replace
     theirs, and ask whether to proceed. Only if they confirm, run:
     ```
     bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --force
     ```
     Otherwise stop and leave their config untouched.

4. Report the result. Mention that:
   - The status line shows: directory · git branch · `C` context · `5` five-hour
     quota · `W` weekly quota · model.
   - When installed as a marketplace plugin, it runs **in place** from the plugin
     dir under `~/.claude/`, so it auto-updates whenever the plugin updates
     (nothing is copied). Run standalone, `install.sh` copies the scripts into
     `~/.claude` instead.
   - The `5`/`W` quota bars read the `rate_limits` Claude Code reports for
     Claude.ai Pro/Max subscriptions; with an `ANTHROPIC_API_KEY` setup they show
     `--%` and everything else still works.
   - It appears on the next render.
