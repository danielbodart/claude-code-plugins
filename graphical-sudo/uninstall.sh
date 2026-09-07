#!/usr/bin/env bash
# graphical-sudo plugin — uninstaller
#
# Removes env.SUDO_ASKPASS from ~/.claude/settings.json and deletes the helper
# at ~/.claude/sudo-askpass.sh. Run this BEFORE removing the plugin: once the
# plugin is gone its SessionStart hook no longer runs, and a SUDO_ASKPASS
# pointing at a deleted helper makes sudo fail with "no askpass program
# specified" for every password prompt.
#
# Only removes the setting if it points at our helper; refuses to touch a
# SUDO_ASKPASS configured to anything else unless --force is passed.
#
# Usage:
#   ./uninstall.sh            # safe: only remove if it's ours
#   ./uninstall.sh --force    # remove any SUDO_ASKPASS
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

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$claude_dir/settings.json"
helper="$claude_dir/sudo-askpass.sh"

command -v jq >/dev/null 2>&1 || { echo "uninstall.sh: jq is required on PATH" >&2; exit 1; }

say() { printf '%s\n' "$*"; }

# --- Remove env.SUDO_ASKPASS from settings.json ------------------------------
if [ ! -f "$settings" ]; then
  say "No settings.json found — nothing to remove there."
else
  existing=$(jq -r '.env.SUDO_ASKPASS // empty' "$settings" 2>/dev/null)
  if [ -z "$existing" ]; then
    say "No SUDO_ASKPASS configured — nothing to remove there."
  elif [ "$existing" != "$helper" ] && [ "$force" -ne 1 ]; then
    say "⚠  SUDO_ASKPASS belongs to something else:"
    say "      $existing"
    say "   Not removing. Re-run with --force to remove it anyway."
    exit 3
  elif [ "$dry" -eq 1 ]; then
    say "[dry-run] would remove env.SUDO_ASKPASS from $settings"
  else
    new_json=$(jq 'del(.env.SUDO_ASKPASS) | if (.env | length) == 0 then del(.env) else . end' "$settings") \
      || { echo "uninstall.sh: failed to update settings" >&2; exit 1; }
    tmp="$settings.tmp.$$"
    printf '%s\n' "$new_json" > "$tmp" && mv -f "$tmp" "$settings" \
      || { rm -f "$tmp"; echo "uninstall.sh: write failed" >&2; exit 1; }
    say "✓ env.SUDO_ASKPASS removed from $settings"
  fi
fi

# --- Delete the helper -------------------------------------------------------
if [ -e "$helper" ] || [ -L "$helper" ]; then
  if [ "$dry" -eq 1 ]; then
    say "[dry-run] would remove $helper"
  else
    rm -f "$helper" && say "✓ removed $helper"
  fi
fi

say ""
if [ "$dry" -eq 1 ]; then
  say "Dry run: nothing was changed."
else
  say "Done. Removing SUDO_ASKPASS from settings.json only takes effect for new"
  say "sessions — a running one keeps the value it already read."
fi
