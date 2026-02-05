#!/bin/bash
# Claude Code hook: replace sudo with pkexec (graphical authentication)
# Works on GNOME, Cinnamon, MATE, and other GTK-based Linux desktops
#
# Dependencies: jq, pkexec (usually pre-installed on GTK desktops)

# Read the JSON input from stdin
input=$(cat)

# Extract the command from the JSON
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Check if command contains sudo
if echo "$command" | grep -qE '(^|[;&|]\s*)sudo\s'; then
    # Replace sudo with pkexec
    modified_command=$(echo "$command" | sed -E 's/(^|[;&|]\s*)sudo\s/\1pkexec /g')

    # Run the modified command with pkexec (graphical auth prompt)
    output=$(bash -c "$modified_command" 2>&1)
    exit_code=$?

    # Block the original command but return the output from our pkexec version
    # This way Claude sees the result without running sudo again
    if [ $exit_code -eq 0 ]; then
        jq -n --arg output "$output" \
            '{"decision": "block", "reason": ("[pkexec] Command executed successfully with graphical authentication.\n\nOutput:\n" + $output)}'
    else
        jq -n --arg output "$output" --argjson code "$exit_code" \
            '{"decision": "block", "reason": ("[pkexec] Command failed (exit " + ($code|tostring) + ").\n\nOutput:\n" + $output)}'
    fi
    exit 0
fi

# Not a sudo command, allow it through normally
echo '{"decision": "allow"}'
exit 0
