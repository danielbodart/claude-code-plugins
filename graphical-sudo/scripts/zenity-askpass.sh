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

# --text is Pango markup, so the command has to be escaped before it goes in.
# The backslashes are required: since bash 5.2 an unquoted & in a substitution
# replacement stands for the matched text, which would mangle every entity.
escape_markup() {
    local s=$1
    s=${s//&/\&amp;}
    s=${s//</\&lt;}
    s=${s//>/\&gt;}
    printf '%s' "$s"
}

if [ -n "$cmd" ]; then
    text="Authenticate to run as root:

<tt>$(escape_markup "$cmd")</tt>"
else
    text="Authenticate to run as root."
fi

# --forms is the only zenity dialogue that pairs a password field with body
# text, so it is what names the command. Older builds lack it; ask zenity
# rather than falling back on a non-zero exit, because cancelling the dialogue
# also exits non-zero and must not pop a second one.
if zenity --help-forms 2>/dev/null | grep -qF -- '--add-password'; then
    exec zenity --forms \
                --title="Authentication Required" \
                --text="$text" \
                --add-password="$field" 2>/dev/null
fi

exec zenity --password --title="Authentication Required" 2>/dev/null
