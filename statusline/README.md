# statusline

A Claude Code status line that shows, left to right:

```
~/Projects/foo │ main │ C:[□□□□□□□□] 0% │ 5:[■■■■□□□□] 50% │ W:[■■■■■■■■] 100% │ Opus 4.8
```

- **directory** — working dir, `~`-abbreviated
- **git branch** — current branch (hidden outside a repo)
- **`C`** — context window usage (green → yellow → red as it fills; uses the window size Claude Code reports, so 200k and 1M models are both right)
- **`5`** — rolling **5-hour** subscription quota
- **`W`** — **7-day** (weekly) subscription quota
- **model** — display name

The `C` bar uses the `context_window` object Claude Code passes to the status
line — the same figure `/context` shows — and only falls back to summing the
session transcript on old Claude Code builds that don't send it. The `5` and
`W` bars come from your Claude subscription's rate-limit usage.

## Why this isn't a "classic" plugin

A Claude Code plugin manifest can declare `hooks`, `commands`, and `agents`, but
there is **no manifest field that installs a `statusLine`** — that key lives in
`~/.claude/settings.json`. So the plugin wires it up for you: a `SessionStart`
hook sets the `statusLine` the first time you run Claude Code with the plugin
enabled.

## Install

Just enable the plugin — that's it:

```
/plugin install statusline@danielbodart-plugins
```

The `SessionStart` hook configures the status line for you and preserves
everything else in `settings.json`. It never touches a status line you set
yourself.

Already have a custom status line and want this one instead? Run
`/install-statusline --force`. And in the rare case the hook doesn't pick things
up, plain `/install-statusline` wires it up — it inspects any existing status
line first and **asks before overwriting** a custom one.

### Or install without Claude

The command just wraps a deterministic script:

```bash
./install.sh            # safe install (symlink); aborts if a DIFFERENT statusLine exists
./install.sh --force    # replace an existing statusLine
./install.sh --copy     # copy into ~/.claude instead of symlinking
./install.sh --link     # force symlink (the default)
./install.sh --dry-run  # preview, write nothing
```

`install.sh` merges the `statusLine` key into `settings.json`, **preserving all
other keys**, and never clobbers a foreign `statusLine` without `--force`.

### Linked vs copied

`settings.json` always points at one stable path, `~/.claude/statusline.sh`.
By default that's a **symlink** to the plugin's script; with `--copy` it's a
self-contained **copy** that survives the source being deleted. Either way the
installer never clobbers a foreign `statusLine` — or a real file you've placed
at that path — without `--force`.

## How the bars work

The status line is **one self-contained script** with no network access. It
reads the JSON that Claude Code passes to every status line on stdin (see the
[status line docs](https://code.claude.com/docs/en/statusline)) and uses:

- `context_window.used_percentage` for the `C` bar — the same figure `/context`
  shows, computed against the real window size for the current model.
- `rate_limits.five_hour` / `rate_limits.seven_day` for the `5` and `W` bars.
  Claude Code sends these for Claude.ai Pro and Max subscriptions.

`rate_limits` only appears after a session's first API response, so the script
keeps the last values it saw in `~/.claude/quota-cache.json` and reads them back
until fresh ones arrive. A cached window is trusted until its `resets_at` time
passes:

```json
{ "five_hour": 23, "seven_day": 81,
  "five_hour_resets": 1788346155, "seven_day_resets": 1788433155, "ts": 1788343155 }
```

Anthropic's shortest exposed window is 5-hourly (there is no daily figure), which
is why the middle bar is labelled `5`, not `D`.

## Requirements

- `jq` — JSON processor (without it every bar shows `--%`)
- A Claude.ai Pro/Max login for the `5`/`W` bars. With an `ANTHROPIC_API_KEY`
  setup instead, those two bars show `--%` and everything else still works.

## Files

| File | Role |
|------|------|
| `scripts/statusline.sh` | Self-contained renderer. |
| `scripts/auto-install.sh` | SessionStart hook — installs / self-heals the stable symlink. |
| `install.sh` | Deterministic, clobber-safe installer. |
| `uninstall.sh` | Removes statusLine from settings.json and cleans up. |
| `commands/install-statusline.md` | `/install-statusline` — wraps `install.sh` with conflict-checking. |
| `commands/uninstall-statusline.md` | `/uninstall-statusline` — wraps `uninstall.sh`. |

## Uninstall

Run `/uninstall-statusline` to remove the status line from `settings.json` and
clean up the installed script and quota cache. Or uninstall manually: remove the
`statusLine` key from `~/.claude/settings.json` and delete
`~/.claude/statusline.sh` (symlink or copy) and `~/.claude/quota-cache.json`.
