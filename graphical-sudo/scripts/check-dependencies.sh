#!/usr/bin/env bash
# Check that required system dependencies are installed
# Runs as a SessionStart hook to warn early about missing tools

# Consume stdin (SessionStart sends JSON input)
cat > /dev/null

source "$(dirname "${BASH_SOURCE[0]}")/lib-deps.sh"

missing=()
command -v jq     &>/dev/null || missing+=("jq|jq")
# Either dialog will do: the askpass helper prefers galley when it is running
# and falls back to zenity. zenity is the one suggested, being the one every
# distro packages.
command -v galley &>/dev/null || command -v zenity &>/dev/null \
    || missing+=("zenity|zenity")

report_missing "graphical-sudo" "${missing[@]}"
exit $?
