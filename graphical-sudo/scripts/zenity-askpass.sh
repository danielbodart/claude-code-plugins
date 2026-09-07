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

# Long commands are folded the way a shell command is written out in
# documentation: broken at argument boundaries, each line but the last ending
# in a backslash, continuations indented under the first line.
WRAP_WIDTH=80
FIRST_INDENT='    '
CONT_INDENT='        '
MAX_LINES=8

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
fi

# Pack the command into indented lines no wider than WRAP_WIDTH, leaving room
# on every line but the last for the " \" continuation marker. Words are kept
# whole where they fit and split mid-token only when one is too long to fit on
# a line of its own. Past MAX_LINES the rest is dropped and the last line ends
# in an ellipsis -- capping lines rather than characters keeps the dialog the
# same height whatever the width and however the arguments happen to break.
wrap_command() {
    local cmd=$1
    local -a words lines=()
    local pad=$FIRST_INDENT line=$FIRST_INDENT
    local limit=$((WRAP_WIDTH - 2))
    local word sep chunk i out truncated=0

    read -ra words <<<"$cmd"
    for word in "${words[@]}"; do
        while :; do
            sep=' '
            [ "$line" = "$pad" ] && sep=''
            if [ $((${#line} + ${#sep} + ${#word})) -le $limit ]; then
                line="$line$sep$word"
                break
            fi
            if [ "$line" != "$pad" ]; then
                # Flush and retry the whole word on a fresh line.
                lines+=("$line")
            else
                # Too long even alone: take what fits and carry the rest.
                chunk=${word:0:$((limit - ${#line}))}
                # Pathological only if the indent alone fills the line.
                [ -z "$chunk" ] && chunk=$word
                lines+=("$line$chunk")
                word=${word:${#chunk}}
            fi
            pad=$CONT_INDENT
            line=$pad
            if [ ${#lines[@]} -ge $MAX_LINES ]; then
                truncated=1
                break 2
            fi
            [ -z "$word" ] && break
        done
    done

    if [ $truncated -eq 1 ]; then
        # Room for this is already there: lines are packed to WRAP_WIDTH - 2
        # and the last one carries no continuation marker.
        lines[$((${#lines[@]} - 1))]+='…'
    elif [ "$line" != "$pad" ] || [ ${#lines[@]} -eq 0 ]; then
        lines+=("$line")
    fi

    out=''
    for ((i = 0; i < ${#lines[@]} - 1; i++)); do
        out+="${lines[i]} \\"$'\n'
    done
    printf '%s' "$out${lines[${#lines[@]} - 1]}"
}

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

$(escape_label "$(wrap_command "$cmd")")

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
