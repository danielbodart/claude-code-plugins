# commit-push-trunk

A Claude Code plugin that provides a streamlined workflow for committing and pushing directly to trunk while maintaining linear history. Supports git worktrees for feature branch development.

## Overview

This plugin is designed for trunk-based development workflows where you want to:
- Maintain a clean, linear git history (no merge commits)
- Work with git worktrees for parallel development
- Automate the commit-rebase-merge-push cycle

## Command

### `/commit-push-trunk`

Commits your changes and pushes directly to trunk, handling both main repository and worktree scenarios automatically.

**What it does:**

1. Analyzes your current git status and changes
2. Determines if you're on trunk or a feature branch (worktree)
3. Stages and commits with an appropriate message
4. Rebases and pushes while maintaining linear history

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
- **No cleanup**: Leaves worktree/branch cleanup to separate operations

## Requirements

- Git must be installed and configured
- Repository must have a remote named `origin`
- For worktree scenarios, the main repository must be accessible

## Usage

```bash
# Make your changes, then run:
/commit-push-trunk
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
/plugin install commit-push-trunk@danielbodart-plugins
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
