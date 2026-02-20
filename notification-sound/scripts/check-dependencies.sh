#!/bin/bash
# Check that required system dependencies are installed
# Runs as a SessionStart hook to warn early about missing tools

# Consume stdin (SessionStart sends JSON input)
cat > /dev/null

missing=()

command -v paplay &>/dev/null || missing+=("pulseaudio-utils")
[ -f /usr/share/sounds/freedesktop/stereo/complete.oga ] || missing+=("sound-theme-freedesktop")

[ ${#missing[@]} -eq 0 ] && exit 0

# Build comma-separated list
list=$(IFS=", "; echo "${missing[*]}")

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"notification-sound plugin: missing dependencies: ${list}. Install with: sudo apt install ${missing[*]}"}}
EOF
exit 2
