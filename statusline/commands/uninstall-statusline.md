---
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/uninstall.sh:*), Bash(jq:*), Read
description: Remove the statusline from ~/.claude/settings.json and clean up
---

Remove this plugin's status line from `~/.claude`. The heavy lifting is done by
the deterministic engine at `${CLAUDE_PLUGIN_ROOT}/uninstall.sh`; your job is to
confirm what will be removed and report the result.

## Context

- Current statusLine command (if any): !`jq -r '.statusLine.command // "(none)"' "$HOME/.claude/settings.json" 2>/dev/null || echo "(no settings.json)"`
- Dry-run preview: !`bash "${CLAUDE_PLUGIN_ROOT}/uninstall.sh" --dry-run 2>&1`

## What to do

1. Look at the current statusLine command above.

2. **If it is `(none)`**: tell the user there is nothing to uninstall.

3. **If it contains `statusline.sh`** (this plugin's command): run the
   uninstaller — it is safe:
   ```
   bash "${CLAUDE_PLUGIN_ROOT}/uninstall.sh"
   ```

4. **If it is some OTHER command**: warn the user that the statusLine doesn't
   belong to this plugin. Only if they confirm, run:
   ```
   bash "${CLAUDE_PLUGIN_ROOT}/uninstall.sh" --force
   ```

5. Report the result. Mention that the status line disappears on the next render.
