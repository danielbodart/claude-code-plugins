# commit-push-trunk

A Claude Code plugin that provides a streamlined workflow for committing and pushing directly to trunk while maintaining linear history. Supports git worktrees for feature branch development.

## Overview

This plugin is designed for trunk-based development workflows where you want to:
- Maintain a clean, linear git history (no merge commits)
- Work with git worktrees for parallel development
- Automate the commit-rebase-merge-push cycle

## Command

### `/commit-commands:commit-push-trunk`

Commits your changes and pushes directly to trunk, handling both main repository and worktree scenarios automatically.

> **Note:** This plugin uses the `commit-commands` namespace to appear alongside the official `commit-commands` plugin from `anthropics/claude-plugins-official` (which provides `/commit-commands:commit`, `/commit-commands:commit-push-pr`, etc.).

**What it does:**

1. Analyzes your current git status and changes
2. Determines if you're on trunk or a feature branch (worktree)
3. Stages and commits with an appropriate message
4. Rebases and pushes while maintaining linear history
5. Detects the repo's CI/CD system and monitors the triggered build to completion

## Scenarios

### Scenario A: Working directly on trunk

When you're already on the main branch (trunk/main/master):

1. Stages relevant changes
2. Creates commit with appropriate message
3. Pulls with rebase to incorporate any upstream changes
4. Pushes to remote

```
git add <files>
git commit -m "message"
git pull --rebase
git push
```

### Scenario B: Working in a worktree (feature branch)

When you're on a feature branch in a git worktree:

1. Stages relevant changes
2. Creates commit with appropriate message
3. Rebases onto the default branch
4. Fast-forward merges into the main repo
5. Pulls with rebase in main repo
6. Pushes from main repo

```
git add <files>
git commit -m "message"
git rebase <default-branch>
git -C <main-repo> merge --ff-only <branch>
git -C <main-repo> pull --rebase
git -C <main-repo> push
```

## Key Features

- **Linear history**: Always uses `--ff-only` for merges and `--rebase` for pulls
- **Worktree support**: Automatically detects worktrees and handles cross-repo operations
- **Smart commits**: Generates meaningful commit messages based on your changes
- **CI monitoring**: Detects GitHub Actions or CircleCI and watches the triggered build to completion, reporting pass/fail
- **No cleanup**: Leaves worktree/branch cleanup to separate operations

## CI/CD Monitoring

After pushing, the command detects the repo's CI system by looking for config files at the repo root:

- `.github/workflows/*.yml` → **GitHub Actions** (watched via `gh run watch --exit-status`)
- `.circleci/config.yml` → **CircleCI** (polled via the `circleci` CLI or API)

If **both** are present, the command warns you — that usually means a repo mid-transition between CI systems, where one build is disabled and the other active. Recommended fix: remove the unused config. It then monitors whichever build actually ran.

If **neither** is present, it reports that no CI is configured and stops. Missing CLI/token → it gives you the URL to watch manually instead of blocking.

## Requirements

- Git must be installed and configured
- Repository must have a remote named `origin`
- For worktree scenarios, the main repository must be accessible

## Usage

```bash
# Make your changes, then run:
/commit-commands:commit-push-trunk
```

The command will automatically detect your situation and handle the appropriate workflow.

## Why Linear History?

Linear history (no merge commits) provides:
- **Cleaner git log**: Easy to read and understand
- **Simpler bisecting**: `git bisect` works more predictably
- **Better blame**: `git blame` shows actual changes, not merge commits
- **Easier reverts**: Each commit is independent and can be reverted cleanly

## Trunk-Based Development

This plugin supports trunk-based development where:
- All developers commit to a single branch (trunk)
- Feature branches are short-lived
- Changes are integrated frequently
- Linear history is maintained via rebasing

## Installation

1. Add the marketplace:
```
/plugin marketplace add danielbodart/claude-code-plugins
```

2. Install the plugin:
```
/plugin install commit-commands@danielbodart-plugins
```

## Local Testing

Test the plugin locally before publishing:
```bash
claude --plugin-dir ./commit-push-trunk
```

## Author

Daniel Worthington-Bodart (dan@bodar.com)

## License

MIT
