# statusline

A Claude Code status line that shows, left to right:

```
~/Projects/foo │ main │ C:[□□□□□□□□] 0% │ 5:[■■■■□□□□] 50% │ W:[■■■■■■■■] 100% │ Opus 4.8
```

- **directory** — working dir, `~`-abbreviated
- **git branch** — current branch (hidden outside a repo)
- **`C`** — context window usage (green → yellow → red as it fills; 1M-aware)
- **`5`** — rolling **5-hour** subscription quota
- **`W`** — **7-day** (weekly) subscription quota
- **model** — display name

The `C` bar is read from the session transcript. The `5` and `W` bars come from
your Claude subscription's rate-limit usage.

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

## How the quota bars work

The status line is **one self-contained script**. When
`~/.claude/quota-cache.json` is older than 15 minutes, the render path kicks a
refresh in the background (no daemon, no cron, no second file) by re-invoking
**itself** — `statusline.sh refresh-quota` — so the next render is fresh. The
refresh calls the Anthropic OAuth usage endpoint using the token already in
`~/.claude/.credentials.json` — the token is only ever passed to `curl` as a
header, never printed — and writes:

```json
{ "five_hour": 0.0, "seven_day": 100.0,
  "five_hour_resets": null, "seven_day_resets": "…Z", "ts": 1784020664 }
```

Anthropic's shortest exposed window is 5-hourly (there is no daily figure), which
is why the middle bar is labelled `5`, not `D`.

## Requirements

- `jq` — JSON processor (status line degrades to a blank quota bar without it)
- `curl` — for the quota refresher
- An OAuth / subscription login (token in `~/.claude/.credentials.json`). With an
  `ANTHROPIC_API_KEY` setup instead, the `5`/`W` bars show `--%` and everything
  else still works.

## Files

| File | Role |
|------|------|
| `scripts/statusline.sh` | Self-contained renderer + quota refresher (`refresh-quota` subcommand). |
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
