#!/bin/bash
# Check that required system dependencies are installed
# Runs as a SessionStart hook to warn early about missing tools
#
# Note: Cannot use jq here since jq itself is a dependency we're checking

# Consume stdin (SessionStart sends JSON input)
cat > /dev/null

missing=()

command -v jq &>/dev/null || missing+=("jq")
command -v zenity &>/dev/null || missing+=("zenity")

[ ${#missing[@]} -eq 0 ] && exit 0

# Build comma-separated list
list=$(IFS=", "; echo "${missing[*]}")

# Cannot use jq to build JSON since jq may be the missing dependency
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"graphical-sudo plugin: missing dependencies: ${list}. Install with: sudo apt install ${missing[*]}"}}
EOF
exit 2
