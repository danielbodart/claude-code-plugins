#!/usr/bin/env bash
# Shared helpers for locating and playing the notification sound.
#
# Sourced by check-dependencies.sh and play-notification.sh so both agree on
# where the sound lives. Nothing here is FHS-specific: NixOS has no /usr/share,
# so the file is resolved through XDG_DATA_DIRS plus the Nix profile paths.

# Sound files to try, in order of preference, relative to a data directory.
SOUND_CANDIDATES=(
    "sounds/freedesktop/stereo/complete.oga"
    "sounds/freedesktop/stereo/bell.oga"
    "sounds/freedesktop/stereo/message.oga"
)

# Print the data directories to search, one per line, most specific first.
sound_data_dirs() {
    local IFS=:
    # XDG_DATA_DIRS is the standard answer and is set correctly on NixOS.
    for dir in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
        [ -n "$dir" ] && printf '%s\n' "$dir"
    done
    # Explicit fallbacks for when the hook runs without a desktop environment
    # having exported XDG_DATA_DIRS (systemd units, bare ssh sessions).
    printf '%s\n' \
        /run/current-system/sw/share \
        "${HOME:-/nonexistent}/.nix-profile/share" \
        /usr/local/share \
        /usr/share
}

# Print the path to a usable notification sound, or return 1 if none exists.
find_sound_file() {
    # An explicit override always wins.
    if [ -n "${NOTIFICATION_SOUND_FILE:-}" ]; then
        [ -f "$NOTIFICATION_SOUND_FILE" ] && { printf '%s\n' "$NOTIFICATION_SOUND_FILE"; return 0; }
        return 1
    fi

    local dir rel
    while IFS= read -r dir; do
        for rel in "${SOUND_CANDIDATES[@]}"; do
            if [ -f "$dir/$rel" ]; then
                printf '%s\n' "$dir/$rel"
                return 0
            fi
        done
    done < <(sound_data_dirs)
    return 1
}

# Print the name of an available audio player, or return 1 if none exists.
find_sound_player() {
    local player
    for player in paplay pw-play canberra-gtk-play ffplay; do
        if command -v "$player" &>/dev/null; then
            printf '%s\n' "$player"
            return 0
        fi
    done
    return 1
}
