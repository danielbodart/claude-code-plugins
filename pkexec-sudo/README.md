# pkexec-sudo

A Claude Code plugin that replaces `sudo` commands with `pkexec` for graphical authentication on Linux GTK desktops.

## Features

- Intercepts all Bash commands containing `sudo`
- Automatically replaces `sudo` with `pkexec`
- Shows native GNOME/Cinnamon/MATE PolicyKit authentication dialog
- Returns command output to Claude seamlessly
- No double password prompts

## Supported Desktops

- GNOME
- Cinnamon (Linux Mint)
- MATE
- Xfce (with polkit-gnome)
- Any GTK-based desktop with PolicyKit

## Requirements

- `jq` - JSON processor
- `pkexec` - PolicyKit command (pre-installed on most GTK desktops)

## How It Works

1. Claude attempts to run a command like `sudo apt update`
2. The hook intercepts it and transforms to `pkexec apt update`
3. PolicyKit shows a graphical password dialog
4. If authenticated, the command runs and output is returned to Claude
5. If cancelled, Claude receives a "blocked" message

## Limitations

- `pkexec` doesn't support all `sudo` flags (e.g., `-E` for environment preservation)
- Some commands may behave differently under pkexec vs sudo
- Requires a graphical session (won't work over pure SSH)
