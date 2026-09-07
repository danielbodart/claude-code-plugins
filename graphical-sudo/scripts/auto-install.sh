#!/usr/bin/env bash
# Auto-install / self-heal the graphical sudo askpass helper on session start.
# Runs via the SessionStart hook.
#
# sudo(8) reads SUDO_ASKPASS "if no terminal is available or if the -A option
# is specified". Claude Code's Bash tool runs commands with no tty, so putting
# the variable in Claude Code's own `env` block is enough on its own -- sudo
# then finds the helper no matter where the call sits in the command: in a
# pipeline, in $(...), behind xargs, inside a loop, or in a script the command
# runs. Nothing has to inspect or rewrite the command, so there is no shape of
# command this can fail to cover.
#
# Two things get installed:
#
#     ~/.claude/sudo-askpass.sh          the helper, at a STABLE path
#     ~/.claude/settings.json            env.SUDO_ASKPASS -> that path
#
# The helper is COPIED rather than symlinked, which is where this departs from
# the statusline plugin's pattern. A dangling SUDO_ASKPASS breaks sudo for the
# whole account, including outside Claude Code, and once the plugin is gone its
# SessionStart hook is no longer around to repair the link. A copy cannot dangle.
# It is refreshed here whenever the plugin's version differs, so it still tracks
# plugin updates.
#
# Settings values are used literally -- $HOME, ${HOME} and ~ are NOT expanded --
# so the absolute path is resolved here and written out in full.
#
# Clobber-safe on two fronts:
#   * the helper path -- we only write ~/.claude/sudo-askpass.sh when it is
#     absent or already carries our marker line. A file someone else put there
#     is never overwritten.
#   * settings.json -- we only touch env.SUDO_ASKPASS when it is unset or
#     already points at our stable path. An askpass helper configured to
#     anything else is left completely alone.

set -u

# Consume stdin (SessionStart sends JSON input)
cat > /dev/null

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$claude_dir/settings.json"
helper="$claude_dir/sudo-askpass.sh"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null 2>&1 && pwd)}"
src="$plugin_root/scripts/zenity-askpass.sh"
marker='# graphical-sudo: askpass helper -- MANAGED FILE'

command -v jq >/dev/null 2>&1 || exit 0
[ -f "$src" ] || exit 0
[ -d "$claude_dir" ] || mkdir -p "$claude_dir" 2>/dev/null || exit 0

# --- 1. Put the helper at the stable path, if we own that path --------------
may_manage_helper() {
    [ ! -e "$helper" ] && [ ! -L "$helper" ] && return 0
    [ -f "$helper" ] && [ ! -L "$helper" ] && head -n 5 "$helper" 2>/dev/null | grep -qF "$marker" && return 0
    return 1
}

if may_manage_helper; then
    if ! cmp -s "$src" "$helper" 2>/dev/null; then
        tmp="$helper.tmp.$$"
        if cp "$src" "$tmp" 2>/dev/null && chmod +x "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$helper" 2>/dev/null || rm -f "$tmp"
        else
            rm -f "$tmp"
        fi
    fi
else
    # Someone else owns that path; leave their settings alone too.
    exit 0
fi

[ -x "$helper" ] || exit 0

# --- 2. Point env.SUDO_ASKPASS at it, if nothing else claims the key --------
current=$(jq -r '.env.SUDO_ASKPASS // empty' "$settings" 2>/dev/null)

[ -n "$current" ] && [ "$current" != "$helper" ] && exit 0
[ "$current" = "$helper" ] && exit 0

tmp="$settings.tmp.$$"
if { [ -f "$settings" ] && cat "$settings" || echo '{}'; } \
     | jq --arg path "$helper" '.env.SUDO_ASKPASS = $path' > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$settings" 2>/dev/null || rm -f "$tmp"
else
    rm -f "$tmp"
fi
