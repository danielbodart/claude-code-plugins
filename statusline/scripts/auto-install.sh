#!/usr/bin/env bash
# Auto-install / self-heal the statusline on every session start.
# Runs via the SessionStart hook.
#
# The statusLine setting lives in the USER's settings.json and Claude Code
# never rewrites it when the plugin version changes — so a path baked in at
# install time goes stale the moment the plugin updates (the version dir it
# points at gets orphaned). To avoid that, we install via a STABLE symlink:
#
#     ~/.claude/statusline.sh  ->  <active plugin version>/scripts/statusline.sh
#
# and point settings.json at the stable path `bash "$HOME/.claude/statusline.sh"`.
# On each session start we re-point the symlink at the current version, so the
# status line always tracks the installed plugin with no drift.
#
# Clobber-safe on two fronts:
#   * settings.json — we only touch it when it is empty or already OURS (the
#     stable command, or a legacy versioned-cache link to this plugin). A
#     foreign statusLine is left completely alone.
#   * the symlink path — we only create/replace ~/.claude/statusline.sh when it
#     is absent or is already a symlink into a statusline plugin cache. A real
#     file a user put there is never overwritten.

set -u

settings="$HOME/.claude/settings.json"
claude_dir="$HOME/.claude"
link="$claude_dir/statusline.sh"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)}"
src="$plugin_root/scripts/statusline.sh"
our_cmd='bash "$HOME/.claude/statusline.sh"'

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$src" ] || exit 0

current=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)

# Is the configured command one of ours? Either the stable symlink command, or
# a legacy link that points directly into this plugin's versioned cache dir.
is_ours() {
  case "$1" in
    "$our_cmd") return 0 ;;
    *"/plugins/cache/"*"/statusline/"*"/scripts/statusline.sh"*) return 0 ;;
  esac
  return 1
}

# May we manage the symlink path? Yes if it is absent, or already a symlink
# whose target lives inside a statusline plugin cache dir. A regular file
# (or a foreign symlink) means hands off.
may_manage_link() {
  if [ ! -e "$link" ] && [ ! -L "$link" ]; then return 0; fi
  if [ -L "$link" ]; then
    case "$(readlink "$link" 2>/dev/null)" in
      */statusline/*/scripts/statusline.sh) return 0 ;;
    esac
  fi
  return 1
}

# Only act when there is no statusLine yet, or the existing one is ours.
if [ -n "$current" ] && ! is_ours "$current"; then
  exit 0
fi

# 1. Point the stable symlink at the active plugin version (if we own the path).
if may_manage_link; then
  rm -f "$link" 2>/dev/null
  ln -s "$src" "$link" 2>/dev/null || exit 0
fi

# 2. Point settings.json at the stable command, if it isn't already and the
#    symlink is in place.
if [ "$current" != "$our_cmd" ] && [ -L "$link" ]; then
  tmp="$settings.tmp.$$"
  if { [ -f "$settings" ] && cat "$settings" || echo '{}'; } \
       | jq --arg cmd "$our_cmd" '.statusLine = {"type":"command","command":$cmd}' > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$settings" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
fi
