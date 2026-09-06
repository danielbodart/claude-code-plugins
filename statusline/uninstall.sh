#!/usr/bin/env bash
# statusline plugin — uninstaller
#
# Removes the statusLine key from ~/.claude/settings.json and cleans up
# any copied scripts and the quota cache. Only removes the statusLine if
# it was installed by this plugin (points at our script); refuses to touch
# a foreign statusLine unless --force is passed.
#
# Usage:
#   ./uninstall.sh            # safe: only remove if it's ours
#   ./uninstall.sh --force    # remove any statusLine
#   ./uninstall.sh --dry-run  # preview, write nothing

set -u

force=0 dry=0
for a in "$@"; do
  case "$a" in
    --force)   force=1 ;;
    --dry-run) dry=1 ;;
    -h|--help) grep '^#' "$0" | sed '1d;s/^# \{0,1\}//'; exit 0 ;;
    *) echo "uninstall.sh: unknown option '$a'" >&2; exit 2 ;;
  esac
done

claude_dir="$HOME/.claude"
settings="$claude_dir/settings.json"

command -v jq >/dev/null 2>&1 || { echo "uninstall.sh: jq is required on PATH" >&2; exit 1; }

say() { printf '%s\n' "$*"; }
run() { if [ "$dry" -eq 1 ]; then say "[dry-run] $*"; else eval "$*"; fi; }

# --- Check current statusLine ------------------------------------------------
if [ ! -f "$settings" ]; then
  say "No settings.json found — nothing to uninstall."
  exit 0
fi

existing_cmd=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)
if [ -z "$existing_cmd" ]; then
  say "No statusLine configured — nothing to uninstall."
  exit 0
fi

# Is this our statusLine? Check if it points at statusline.sh (ours).
is_ours=0
case "$existing_cmd" in
  *statusline.sh*) is_ours=1 ;;
esac

if [ "$is_ours" -eq 0 ] && [ "$force" -ne 1 ]; then
  say "⚠  statusLine belongs to something else:"
  say "      $existing_cmd"
  say "   Not removing. Re-run with --force to remove it anyway."
  exit 3
fi

# --- Remove statusLine from settings.json ------------------------------------
new_json=$(jq 'del(.statusLine)' "$settings") || { echo "uninstall.sh: failed to update settings" >&2; exit 1; }

if [ "$dry" -eq 1 ]; then
  say "[dry-run] would remove statusLine from $settings"
else
  tmp="$settings.tmp.$$"
  printf '%s\n' "$new_json" > "$tmp" && mv -f "$tmp" "$settings" || { rm -f "$tmp"; echo "uninstall.sh: write failed" >&2; exit 1; }
  say "✓ statusLine removed from $settings"
fi

# --- Clean up the installed script (symlink or copy) and cache ---------------
# quota-refresh.sh is legacy (older copy-mode installs); remove it if present.
for f in "$claude_dir/statusline.sh" "$claude_dir/quota-refresh.sh" "$claude_dir/quota-cache.json"; do
  if [ -e "$f" ] || [ -L "$f" ]; then
    run "rm -f \"$f\""
    [ "$dry" -eq 0 ] && say "✓ removed $f"
  fi
done

say ""
if [ "$dry" -eq 1 ]; then
  say "Dry run: nothing was changed."
else
  say "Done. The status line is removed on your next Claude Code render."
fi
