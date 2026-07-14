# statusline

A Claude Code status line that shows, left to right:

```
~/Projects/foo │ main │ C:[■□□□□□□□] 12% │ 5:[□□□□□□□□] 0% │ W:[■■■■■■■■] 100% │ Opus 4.8
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
`~/.claude/settings.json`. So enabling the plugin alone does nothing; you run the
`/install-statusline` command (or `install.sh`) once to wire it up.

## Install

Enable the plugin, then run the command:

```
/plugin install statusline@danielbodart-plugins
/install-statusline
```

`/install-statusline` inspects any existing status line first and **asks before
overwriting** a custom one.

### Or install without Claude

The command just wraps a deterministic script:

```bash
./install.sh            # safe install; aborts if a DIFFERENT statusLine exists
./install.sh --force    # replace an existing statusLine
./install.sh --copy     # force copy-into-~/.claude
./install.sh --link     # force point-at-source
./install.sh --dry-run  # preview, write nothing
```

`install.sh` merges the `statusLine` key into `settings.json`, **preserving all
other keys**, and never clobbers a foreign `statusLine` without `--force`.

### Linked vs copied

The installer auto-picks how the scripts are referenced:

- **Linked (auto when installed as a marketplace plugin).** The plugin already
  lives under `~/.claude/plugins/…`, so `settings.json` points straight at the
  plugin's own `scripts/statusline.sh`. **The status line auto-updates when the
  plugin updates** — nothing is copied. It deliberately will *not* link to a path
  outside `~/.claude` (e.g. a dev checkout) unless you pass `--link`.
- **Copied (auto when run as a bare script).** `scripts/statusline.sh` and
  `scripts/quota-refresh.sh` are copied into `~/.claude/`. Self-contained and
  survives the source being deleted, but repo edits need a re-run to apply.

Either way the quota cache lives at `~/.claude/quota-cache.json`, and
`statusline.sh` finds `quota-refresh.sh` as its own sibling.

## How the quota bars work

`statusline.sh` reads `~/.claude/quota-cache.json`. When that cache is older than
15 minutes, the status line fires its sibling `quota-refresh.sh` in the
background (no daemon, no cron) so the next render is fresh. The refresher calls
the Anthropic OAuth usage endpoint using the token already in
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
| `scripts/statusline.sh` | The status line renderer (referenced by settings.json). |
| `scripts/quota-refresh.sh` | Fetches subscription quota → `quota-cache.json`. |
| `install.sh` | Deterministic, clobber-safe installer. |
| `commands/install-statusline.md` | `/install-statusline` — wraps `install.sh` with conflict-checking. |

## Uninstall

Remove the `statusLine` key from `~/.claude/settings.json` and delete
`~/.claude/statusline.sh`, `~/.claude/quota-refresh.sh`, `~/.claude/quota-cache.json`.
