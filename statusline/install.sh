#!/bin/bash
# statusline plugin — installer (deterministic engine)
#
# Merges a statusLine key into ~/.claude/settings.json, preserving all other
# keys, and makes statusline.sh available. Two modes:
#
#   linked (default when run from an installed marketplace plugin, i.e. this
#           script already lives under ~/.claude/): settings.json points
#           directly at the plugin's own scripts/statusline.sh, so the status
#           line auto-updates whenever the plugin updates. Nothing is copied.
#
#   copy   (fallback, or forced with --copy): copies statusline.sh +
#           quota-refresh.sh into ~/.claude and points settings.json there.
#           Self-contained; survives the source being deleted.
#
# Clobber-safe: if settings.json already has a statusLine pointing somewhere
# ELSE, the installer refuses and exits 3, leaving your config untouched —
# unless you pass --force. Pointing at what's already configured is a no-op.
#
# Usage:
#   ./install.sh            # auto-detect mode; abort on foreign statusLine
#   ./install.sh --copy     # force copy-into-~/.claude
#   ./install.sh --link     # force point-at-source (needs a stable source path)
#   ./install.sh --force    # replace an existing (foreign) statusLine
#   ./install.sh --dry-run  # show what would change, write nothing

set -u

force=0 dry=0 mode=""
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

command -v jq >/dev/null 2>&1 || { echo "install.sh: jq is required on PATH" >&2; exit 1; }
[ -f "$scripts/statusline.sh" ]    || { echo "install.sh: missing $scripts/statusline.sh" >&2; exit 1; }
[ -f "$scripts/quota-refresh.sh" ] || { echo "install.sh: missing $scripts/quota-refresh.sh" >&2; exit 1; }

# --- Decide mode -------------------------------------------------------------
# Auto: link when the source already lives under ~/.claude (an installed
# marketplace plugin), else copy. Never link to a path outside ~/.claude
# (e.g. a dev checkout) unless the user explicitly asks with --link.
canon_claude=$(CDPATH= cd -- "$claude_dir" >/dev/null 2>&1 && pwd)
if [ -z "$mode" ]; then
  case "$src_dir/" in
    "$canon_claude"/*) mode="link" ;;
    *) mode="copy" ;;
  esac
fi

say() { printf '%s\n' "$*"; }
run() { if [ "$dry" -eq 1 ]; then say "[dry-run] $*"; else eval "$*"; fi; }

# The command settings.json will run, and where scripts end up, depend on mode.
if [ "$mode" = "link" ]; then
  target_script="$scripts/statusline.sh"
  our_cmd="bash \"$target_script\""
  say "mode: link → $target_script"
else
  target_script="$claude_dir/statusline.sh"
  # Keep the tidy $HOME-relative form for the copied location.
  our_cmd='bash "$HOME/.claude/statusline.sh"'
  say "mode: copy → $claude_dir"
fi

# --- 1. Make the scripts available -------------------------------------------
run "mkdir -p \"$claude_dir\""
if [ "$mode" = "copy" ]; then
  run "cp \"$scripts/statusline.sh\"    \"$claude_dir/statusline.sh\""
  run "cp \"$scripts/quota-refresh.sh\" \"$claude_dir/quota-refresh.sh\""
  run "chmod +x \"$claude_dir/statusline.sh\" \"$claude_dir/quota-refresh.sh\""
  say "✓ scripts installed to $claude_dir"
else
  # Linked: statusline.sh finds quota-refresh.sh as its own sibling, so there
  # is nothing to copy. Just make sure they are executable in place.
  run "chmod +x \"$scripts/statusline.sh\" \"$scripts/quota-refresh.sh\""
  say "✓ using plugin scripts in place (auto-updates with the plugin)"
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
