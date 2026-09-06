#!/usr/bin/env bash
# Shared dependency-reporting helper for SessionStart hooks.
#
# A copy lives in each plugin because plugins install independently and cannot
# reference each other's files. Keep the copies in sync.
#
# Note: this deliberately builds JSON by hand rather than with jq, because jq
# is itself one of the dependencies these checkers look for.

# Print the distro family: nixos, debian, or unknown.
distro_family() {
    local os_release="${OS_RELEASE_FILE:-/etc/os-release}"
    [ -r "$os_release" ] || { printf 'unknown\n'; return; }
    # Read in a subshell so the sourced variables do not leak to the caller.
    (
        # shellcheck disable=SC1091
        . "$os_release"
        case "${ID:-}" in
            nixos)
                printf 'nixos\n'; return ;;
        esac
        case "${ID:-} ${ID_LIKE:-}" in
            *debian*|*ubuntu*)
                printf 'debian\n'; return ;;
        esac
        printf 'unknown\n'
    )
}

# report_missing <plugin-name> [entry...]
#
# Each entry is "debian-package|nixos-package". Emits the SessionStart JSON
# describing what is missing and how to install it on this host.
# Returns 0 when nothing is missing, 2 when something is.
report_missing() {
    local plugin=$1; shift
    [ $# -eq 0 ] && return 0

    local family names=() entry
    family=$(distro_family)

    for entry in "$@"; do
        if [ "$family" = "nixos" ]; then
            names+=("${entry#*|}")
        else
            names+=("${entry%|*}")
        fi
    done

    local list hint
    list=$(printf '%s, ' "${names[@]}"); list=${list%, }

    case "$family" in
        nixos)
            hint="add ${names[*]} to environment.systemPackages in /etc/nixos/configuration.nix, then run sudo nixos-rebuild switch"
            ;;
        debian)
            hint="install with: sudo apt install ${names[*]}"
            ;;
        *)
            hint="install these with your system package manager: ${names[*]}"
            ;;
    esac

    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s plugin: missing dependencies: %s. To fix, %s."}}\n' \
        "$plugin" "$list" "$hint"
    return 2
}
