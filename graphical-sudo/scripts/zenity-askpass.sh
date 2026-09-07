#!/usr/bin/env bash
# graphical-sudo: askpass helper -- MANAGED FILE, local edits are overwritten.
#
# sudo runs this to collect a password when it has no terminal. It execs us as
# its own direct child, so sudo's argv names the command being authorised and
# we can read it out of the process table. Nothing has to pass it in, which is
# how the dialog stays descriptive without anything ever inspecting or
# rewriting the command Claude ran.
#
# The password is written to stdout for sudo and nowhere else -- never to a
# log, a temp file, or stderr.

set -u

prompt=${1:-Password:}

# "[sudo] password for dan: " -> "Password for dan"
field=${prompt#\[sudo\] }
field=${field%%:*}
field=${field:-Password}
field="${field^}"

# sudo's own argv, with the absolute path to the sudo binary trimmed off:
# "/nix/store/...-sudo-1.9.17p2/bin/sudo apt update" -> "sudo apt update"
cmd=$(ps -o args= -p "$PPID" 2>/dev/null | tr '\n' ' ')
cmd=${cmd%"${cmd##*[![:space:]]}"}
if [ -n "$cmd" ]; then
    head=${cmd%% *}
    cmd="${head##*/}${cmd#"$head"}"
    [ ${#cmd} -gt 240 ] && cmd="${cmd:0:240}…"
fi

# zenity runs --text through g_strcompress() and then sets it as a mnemonic
# label, so a backslash in the command would be read as an escape sequence and
# an underscore would be swallowed as an accelerator. Both survive doubled.
# The text is not markup here (--entry uses gtk_label_set_text_with_mnemonic),
# so < and & need no escaping.
escape_label() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//_/__}
    printf '%s' "$s"
}

if [ -n "$cmd" ]; then
    text="Authenticate to run as root:

    $(escape_label "$cmd")

$(escape_label "$field"):"
else
    text="Authenticate to run as root.

$(escape_label "$field"):"
fi

# --entry --hide-text, not --forms --add-password: only --entry calls
# gtk_entry_set_activates_default(), so Enter accepts the dialog instead of
# doing nothing. Both mask the input and both can carry body text naming the
# command; --forms would just cost a mouse click on every prompt.
exec zenity --entry \
            --hide-text \
            --title="Authentication Required" \
            --text="$text" 2>/dev/null
