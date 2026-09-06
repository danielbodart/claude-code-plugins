#!/usr/bin/env bash
# Notification hook: play a short sound when Claude Code needs attention.
#
# Resolves both the player and the sound file at runtime rather than hardcoding
# an FHS path, so this works on Debian/Ubuntu and on NixOS alike.

# Consume stdin (the Notification hook sends JSON input).
cat > /dev/null

source "$(dirname "${BASH_SOURCE[0]}")/lib-sound.sh"

player=$(find_sound_player) || exit 0

# canberra-gtk-play looks up the sound by theme event id, so it needs no file.
if [ "$player" = "canberra-gtk-play" ]; then
    canberra-gtk-play -i complete &>/dev/null
    exit 0
fi

sound=$(find_sound_file) || exit 0

case "$player" in
    paplay)  paplay "$sound" &>/dev/null ;;
    pw-play) pw-play "$sound" &>/dev/null ;;
    ffplay)  ffplay -nodisp -autoexit -loglevel quiet "$sound" &>/dev/null ;;
esac

# Never fail the hook over a sound that would not play.
exit 0
