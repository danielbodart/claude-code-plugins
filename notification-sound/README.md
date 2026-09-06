# notification-sound

A Claude Code plugin that plays a notification sound on any Claude Code notification.

## Features

- Plays a sound on any notification from Claude Code
- Uses the standard freedesktop completion chime
- Resolves the player and sound file at runtime, so it works on both FHS
  distros (Ubuntu/Debian) and NixOS

## How It Works

1. Claude Code fires a `Notification` event
2. `scripts/play-notification.sh` finds an available player and the freedesktop
   `complete.oga` sound, then plays it

Neither the player nor the sound path is hardcoded. The sound is looked up
through `XDG_DATA_DIRS` (falling back to the Nix profile paths and `/usr/share`),
because NixOS has no `/usr/share` at all. The first available player of
`paplay`, `pw-play`, `canberra-gtk-play`, `ffplay` is used.

If nothing suitable is found the hook exits quietly with status 0 — a missing
sound never fails the hook.

## Dependencies

- **A player** — `paplay` (from `pulseaudio-utils` on Debian/Ubuntu, `pulseaudio`
  on NixOS) is preferred; `pw-play`, `canberra-gtk-play` or `ffplay` also work.
  `paplay` works on PipeWire via `pipewire-pulse` compatibility.
- **sound-theme-freedesktop** — standard sound theme providing
  `sounds/freedesktop/stereo/complete.oga` (pre-installed on most desktop Linux)

The `SessionStart` hook checks for these and reports an install command matching
your distro.

## Installation

Both dependencies are pre-installed on standard Ubuntu/Debian desktop systems.
If missing:

```bash
sudo apt install pulseaudio-utils sound-theme-freedesktop
```

On NixOS, add to `environment.systemPackages` in `/etc/nixos/configuration.nix`:

```nix
pulseaudio               # provides the paplay client (leave services.pulseaudio.enable = false)
sound-theme-freedesktop
```

then run `sudo nixos-rebuild switch`.

## Configuration

Set `NOTIFICATION_SOUND_FILE` to an absolute path to override the sound:

```bash
export NOTIFICATION_SOUND_FILE=/path/to/your.oga
```

## Limitations

- Requires a running PulseAudio or PipeWire audio server
- Won't work over pure SSH without audio forwarding
