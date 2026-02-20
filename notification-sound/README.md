# notification-sound

A Claude Code plugin that plays a notification sound when Claude has been waiting for your input for over a minute.

## Features

- Plays a sound after ~60 seconds of idle waiting
- Uses the standard freedesktop completion chime
- No notification during active conversation — only when you've been away

## How It Works

1. Claude finishes responding and waits for your input
2. After ~60 seconds of idle, the `Notification` hook fires with `idle_prompt`
3. `paplay` plays the freedesktop `complete.oga` sound

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
- The idle timeout (~60 seconds) is not configurable — it's set by Claude Code
