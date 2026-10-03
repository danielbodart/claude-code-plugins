# graphical-sudo

A Claude Code plugin that enables graphical password prompts for `sudo` commands on Linux GTK desktops.

## Features

- Works for `sudo` anywhere in a command — pipelines, `$(...)`, loops, `xargs`, or a script the command runs
- Shows a graphical password dialog naming the command being authenticated
- Never inspects or rewrites your commands
- Returns command output to Claude seamlessly

## Supported Desktops

- GNOME
- Cinnamon (Linux Mint)
- MATE
- Xfce
- Any GTK-based desktop with zenity or galley

## How It Works

`sudo` reads the `SUDO_ASKPASS` environment variable "if no terminal is
available or if the `-A` option is specified" (`man sudo`). Claude Code's Bash
tool runs commands with no tty, so simply having that variable in the
environment is enough — no `-A` flag, and no need to touch the `sudo` call at
all.

Claude Code sets environment variables for a session and its subprocesses
through the `env` key in `settings.json`, so the whole plugin is two files:

```
~/.claude/sudo-askpass.sh      the dialog helper (galley or zenity)
~/.claude/settings.json        env.SUDO_ASKPASS -> that path
```

A SessionStart hook installs and refreshes both. Because nothing has to parse
the command, there is no command shape this can miss:

```bash
sudo apt update                                   # the simple case
echo hi | sudo tee /etc/motd                      # pipelines
VER=$(sudo dmidecode -s bios-version)             # command substitution
if sudo test -f /etc/shadow; then echo yes; fi    # conditionals
find . -name '*.log' -print0 | xargs -0 sudo rm   # xargs
for d in a b; do sudo mkdir "/opt/$d"; done       # loops
make install                                      # sudo called from a script
```

When a password is needed:

1. `sudo` runs `~/.claude/sudo-askpass.sh`
2. galley or zenity shows a dialog naming the command — the helper reads it
   from `sudo`'s own argv, since `sudo` execs it as a direct child
3. If authenticated, the command runs and output is returned to Claude
4. If cancelled, Claude receives an error message

The password goes to `sudo` on stdout and nowhere else — no log, no temp file.

### galley or zenity

[galley](https://github.com/danielbodart/galley) is a zenity-compatible
drop-in whose dialogs stack in one queue window, so a sudo prompt waits its
turn beside any other prompts rather than opening a window of its own. The
helper uses galley when it is running — its socket
`$XDG_RUNTIME_DIR/galley/sock` exists and a `galley` command is found, on
`PATH` or in a Nix profile — and zenity otherwise. The command line is the
same for both.

The choice is made before anything runs, because galley exits 1 when it
cannot reach its window, which is also what Cancel returns: a failed galley
could not be told from a refused prompt and fallen back from.

## Installation

Enable the plugin; the SessionStart hook does the rest. It is clobber-safe: if
`env.SUDO_ASKPASS` already points somewhere else, or a file you wrote already
sits at `~/.claude/sudo-askpass.sh`, the plugin leaves both alone.

To wire it up by hand instead, copy `scripts/askpass.sh` anywhere, make
it executable, and add the `env` block to any of `~/.claude/settings.json`,
`.claude/settings.json`, or `.claude/settings.local.json`:

```json
{
  "env": {
    "SUDO_ASKPASS": "/home/YOU/.claude/sudo-askpass.sh"
  }
}
```

Settings values are used **literally** — `$HOME`, `${HOME}` and `~` are *not*
expanded, so write the absolute path. A running session picks up the change
when you save the file.

Don't point it into the plugin's own cache directory
(`~/.claude/plugins/cache/.../graphical-sudo/1.0.63/...`): that path goes stale
on every plugin update. The hook copies the helper out to a stable location for
exactly this reason, and copies rather than symlinks so the helper cannot end
up dangling once the plugin is removed.

## Uninstalling

Run `./uninstall.sh` **before** removing the plugin. Once the plugin is gone its
SessionStart hook no longer runs, and a `SUDO_ASKPASS` left pointing at a
deleted helper makes `sudo` fail with `no askpass program specified` for every
password prompt — including outside Claude Code.

```bash
./uninstall.sh --dry-run   # preview
./uninstall.sh             # remove env.SUDO_ASKPASS and the helper
```

## Dependencies

- **bash** - Shell interpreter
- **jq** - JSON processor for merging the setting
- **zenity** or **galley** - dialog for the graphical password prompt. zenity is
  pre-installed on most GTK desktops; galley is used instead whenever it is
  running (see [galley or zenity](#galley-or-zenity))

Standard utilities `ps` and `cmp` are also used but are available on all Linux systems.

Install them on Debian/Ubuntu-based systems:
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

On NixOS, add `jq zenity` to `environment.systemPackages` in
`/etc/nixos/configuration.nix`, then run `sudo nixos-rebuild switch`.

## Limitations

- Requires a graphical session (won't work over pure SSH)
- Password is handled by zenity, a standard GTK component, or by galley
