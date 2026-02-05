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

## Requirements

- `jq` - JSON processor
- `zenity` - GTK dialog tool (pre-installed on most GTK desktops)

## How It Works

1. Claude attempts to run a command like `sudo apt update`
2. The hook intercepts it and transforms to `sudo -A apt update` with `SUDO_ASKPASS` set
3. Zenity shows a graphical password dialog
4. If authenticated, the command runs and output is returned to Claude
5. If cancelled, Claude receives an error message

## Why Not pkexec?

We originally tried using `pkexec` (PolicyKit), but for unknown reasons it has a ~60 second delay when run from Claude Code. The `sudo -A` with zenity askpass approach works instantly.

## Limitations

- Requires a graphical session (won't work over pure SSH)
- Password is handled by zenity, which is a standard GTK component
