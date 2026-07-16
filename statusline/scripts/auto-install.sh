#!/bin/bash
# Auto-install the statusline on first session after plugin is enabled.
# Runs via SessionStart hook. Does nothing if already installed or if a
# different (custom) statusLine is configured — never clobbers silently.
# Also cleans up if the plugin was disabled and re-enabled with stale config.

set -u

settings="$HOME/.claude/settings.json"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)}"
installer="$plugin_root/install.sh"

[ -x "$installer" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# If no statusLine is configured at all, install (safe — no clobber risk).
if [ ! -f "$settings" ] || [ "$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)" = "" ]; then
  bash "$installer" >/dev/null 2>&1
fi
