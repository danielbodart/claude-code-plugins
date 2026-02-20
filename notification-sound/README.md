# notification-sound

A Claude Code plugin that plays a notification sound on any Claude Code notification.

## Features

- Plays a sound on any notification from Claude Code
- Uses the standard freedesktop completion chime

## How It Works

1. Claude Code fires a `Notification` event
2. `paplay` plays the freedesktop `complete.oga` sound

## Dependencies

- **paplay** - PulseAudio playback tool (from `pulseaudio-utils`, pre-installed on Ubuntu/Debian desktops). Works on PipeWire via `pipewire-pulse` compatibility.
- **sound-theme-freedesktop** - Standard sound theme providing `/usr/share/sounds/freedesktop/stereo/complete.oga` (pre-installed on most desktop Linux)

## Installation

Both dependencies are pre-installed on standard Ubuntu/Debian desktop systems. If missing:

```bash
sudo apt install pulseaudio-utils sound-theme-freedesktop
```

## Limitations

- Requires a running PulseAudio or PipeWire audio server
- Won't work over pure SSH without audio forwarding
