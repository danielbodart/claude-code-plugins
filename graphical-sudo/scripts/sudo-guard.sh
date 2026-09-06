#!/usr/bin/env bash
# Claude Code hook: graphical authentication for sudo commands
# Uses sudo -A with zenity askpass for GTK-based Linux desktops
#
# Dependencies: jq, zenity (usually pre-installed on GTK desktops)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASKPASS_SCRIPT="${SCRIPT_DIR}/zenity-askpass.sh"

# Read the JSON input from stdin
input=$(cat)

# Extract the command from the JSON
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Check if command contains sudo (but not already sudo -A)
if echo "$command" | grep -qE '(^|[;&|]\s*)sudo\s' && ! echo "$command" | grep -qE 'sudo\s+-A'; then
    # Replace 'sudo ' with 'sudo -A ' and set SUDO_ASKPASS
    modified_command=$(echo "$command" | sed -E 's/(^|[;&|]\s*)sudo\s/\1sudo -A /g')

    # Prepend the SUDO_ASKPASS environment variable
    modified_command="SUDO_ASKPASS=\"${ASKPASS_SCRIPT}\" ${modified_command}"

    # Allow with modified command - zenity will show graphical password prompt
    jq -n --arg cmd "$modified_command" '{
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "updatedInput": {
                "command": $cmd
            }
        }
    }'
    exit 0
fi

# Not a sudo command (or already using -A), allow it through normally
exit 0
