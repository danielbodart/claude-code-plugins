#!/usr/bin/env bash
# statusline plugin — installer (deterministic engine)
#
# Merges a statusLine key into ~/.claude/settings.json, preserving all other
# keys, and makes statusline.sh available at the STABLE path
# ~/.claude/statusline.sh. settings.json always points there, so the path in
# settings never changes — even as the plugin updates. Two modes control what
# lives at that stable path:
#
#   link   (default): ~/.claude/statusline.sh is a SYMLINK to the plugin's
#          scripts/statusline.sh. The SessionStart hook re-points it at the
#          active plugin version, so the status line auto-updates with no drift.
#
#   copy   (--copy): ~/.claude/statusline.sh is a COPY. Self-contained; survives
#          the source being deleted, but does not auto-update.
#
# The status line is one self-contained script that only reads the JSON
# Claude Code passes it on stdin — there is no second file and no network.
#
# Clobber-safe: if settings.json already has a statusLine pointing somewhere
# ELSE, the installer refuses and exits 3, leaving your config untouched —
# unless you pass --force. Pointing at what's already configured is a no-op.
#
# Usage:
#   ./install.sh            # default (symlink); abort on foreign statusLine
#   ./install.sh --copy     # copy into ~/.claude instead of symlinking
#   ./install.sh --link     # force symlink (the default)
#   ./install.sh --force    # replace an existing (foreign) statusLine
#   ./install.sh --dry-run  # show what would change, write nothing

set -u

force=0 dry=0 mode="link"
for a in "$@"; do
  case "$a" in
    --force)   force=1 ;;
    --dry-run) dry=1 ;;
    --copy)    mode="copy" ;;
    --link)    mode="link" ;;
    -h|--help) grep '^#' "$0" | sed '1d;s/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option '$a'" >&2; exit 2 ;;
  esac
done

# CDPATH in the user's environment makes `cd` echo the target dir to stdout,
# which would corrupt this capture — force it off and silence cd.
src_dir=$(CDPATH= cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)
scripts="$src_dir/scripts"
claude_dir="$HOME/.claude"
settings="$claude_dir/settings.json"
link="$claude_dir/statusline.sh"

command -v jq >/dev/null 2>&1 || { echo "install.sh: jq is required on PATH" >&2; exit 1; }
[ -f "$scripts/statusline.sh" ] || { echo "install.sh: missing $scripts/statusline.sh" >&2; exit 1; }

# settings.json always points at the stable path, regardless of mode.
our_cmd='bash "$HOME/.claude/statusline.sh"'

say() { printf '%s\n' "$*"; }
run() { if [ "$dry" -eq 1 ]; then say "[dry-run] $*"; else eval "$*"; fi; }

# --- 1. Put statusline.sh at the stable path (symlink or copy) ---------------
run "mkdir -p \"$claude_dir\""
if [ "$mode" = "copy" ]; then
  run "cp \"$scripts/statusline.sh\" \"$link\""
  run "chmod +x \"$link\""
  say "mode: copy → $link"
else
  # Replace any existing entry at the stable path with a fresh symlink.
  run "rm -f \"$link\""
  run "ln -s \"$scripts/statusline.sh\" \"$link\""
  say "mode: link → $link → $scripts/statusline.sh"
fi

# --- 2. Merge statusLine into settings.json (clobber-safe) -------------------
existing_cmd=""
if [ -f "$settings" ]; then
  jq empty "$settings" 2>/dev/null || { echo "install.sh: $settings is not valid JSON; aborting" >&2; exit 1; }
  existing_cmd=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null)
fi

if [ "$existing_cmd" = "$our_cmd" ]; then
  say "✓ settings.json already points here (no change)"
  exit 0
fi

if [ -n "$existing_cmd" ]; then
  if [ "$force" -ne 1 ]; then
    say ""
    say "⚠  settings.json already defines a different statusLine:"
    say "      $existing_cmd"
    say "   Not overwriting. Re-run with --force to replace it, or merge by hand."
    exit 3
  fi
  say "… overwriting existing statusLine (--force): $existing_cmd"
fi

new_json=$(
  if [ -f "$settings" ]; then cat "$settings"; else echo '{}'; fi \
  | jq --arg cmd "$our_cmd" '.statusLine = {"type":"command","command":$cmd}'
) || { echo "install.sh: failed to build merged settings" >&2; exit 1; }

if [ "$dry" -eq 1 ]; then
  say "[dry-run] would write statusLine to $settings:"
  printf '%s\n' "$new_json" | jq '.statusLine'
else
  tmp="$settings.tmp.$$"
  printf '%s\n' "$new_json" > "$tmp" && mv -f "$tmp" "$settings" || { rm -f "$tmp"; echo "install.sh: write failed" >&2; exit 1; }
  jq empty "$settings" 2>/dev/null || { echo "install.sh: post-write validation failed" >&2; exit 1; }
  say "✓ statusLine merged into $settings"
fi

say ""
say "Done. The status line appears on your next Claude Code render."
