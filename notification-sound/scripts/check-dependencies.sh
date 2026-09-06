#!/usr/bin/env bash
# Check that required system dependencies are installed
# Runs as a SessionStart hook to warn early about missing tools

# Consume stdin (SessionStart sends JSON input)
cat > /dev/null

here="$(dirname "${BASH_SOURCE[0]}")"
source "$here/lib-deps.sh"
source "$here/lib-sound.sh"

missing=()
find_sound_player &>/dev/null || missing+=("pulseaudio-utils|pulseaudio")
find_sound_file   &>/dev/null || missing+=("sound-theme-freedesktop|sound-theme-freedesktop")

report_missing "notification-sound" "${missing[@]}"
exit $?
