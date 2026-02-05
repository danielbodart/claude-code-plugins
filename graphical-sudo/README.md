# graphical-sudo

A Claude Code plugin that enables graphical password prompts for `sudo` commands on Linux GTK desktops.

## Features

- Intercepts all Bash commands containing `sudo`
- Shows a graphical password dialog using zenity
- Returns command output to Claude seamlessly
- Fast execution with no delays

## Supported Desktops

- GNOME
- Cinnamon (Linux Mint)
- MATE
- Xfce
- Any GTK-based desktop with zenity

## How It Works

1. Claude attempts to run a command like `sudo apt update`
2. The hook intercepts it and transforms to `sudo -A apt update` with `SUDO_ASKPASS` set
3. Zenity shows a graphical password dialog
4. If authenticated, the command runs and output is returned to Claude
5. If cancelled, Claude receives an error message

## Dependencies

- **bash** - Shell interpreter
- **jq** - JSON processor for parsing hook input
- **zenity** - GTK dialog tool for graphical password prompts (pre-installed on most GTK desktops)

Standard utilities `grep` and `sed` are also used but are available on all Linux systems.

## Installation

On Debian/Ubuntu-based systems:
```bash
sudo apt install jq zenity
```

On Fedora/RHEL-based systems:
```bash
sudo dnf install jq zenity
```

On Arch-based systems:
```bash
sudo pacman -S jq zenity
```

## Limitations

- Requires a graphical session (won't work over pure SSH)
- Password is handled by zenity, which is a standard GTK component
