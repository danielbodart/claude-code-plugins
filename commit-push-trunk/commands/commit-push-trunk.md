---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git push:*), Bash(git commit:*), Bash(git rebase:*), Bash(git merge:*), Bash(git pull:*), Bash(git -C:*), Bash(git diff:*), Bash(git branch:*), Bash(git symbolic-ref:*), Bash(git worktree list:*), Bash(git worktree list), Bash(git config:*), Bash(git config --get:*), Bash(git worktree remove:*), Bash(git checkout:*)
description: Commit and push directly to trunk with linear history (supports worktrees)
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Worktree list: !`git worktree list`

Note: Default branch is typically `master` or `main`. Check the worktree list - the main repo's branch is the default.

## Your task

Commit changes and push directly to trunk maintaining linear history.

Determine the scenario based on whether current branch equals the default branch:

**Scenario A - Already on trunk (current branch = default branch):**
1. Stage relevant changes: `git add <files>`
2. Commit with appropriate message
3. `git pull --rebase`
4. `git push`

**Scenario B - On feature branch (worktree):**
1. Stage relevant changes: `git add <files>`
2. Commit with appropriate message
3. `git -C <main-repo-directory> pull --rebase` (update trunk FIRST so rebase uses latest)
4. `git rebase <default-branch>` (replay feature commits on updated trunk)
5. `git -C <main-repo-directory> merge --ff-only <current-branch>`
6. `git -C <main-repo-directory> push`
7. Ask the user what to do with this worktree (use AskUserQuestion):
   - **"Delete worktree"** — Remove the worktree and delete the branch:
     1. `git worktree remove <worktree-directory>`
     2. `git -C <main-repo-directory> branch -d <current-branch>`
   - **"Keep worktree"** — Update the worktree to match trunk so it's ready for new work:
     1. `git rebase <default-branch>` (fast-forwards the branch to trunk HEAD)

Requirements:
- Always use `--ff-only` for merges (ensures linear history)
- Always use `--rebase` for pulls (ensures linear history)
- Use `git -C <path>` to run commands in main repo when in a worktree
- Create meaningful commit message based on the changes
- You have the capability to call multiple tools in a single response. You MUST do steps 1-6 in a single message. Then ask the user about the worktree (step 7) and execute their choice.
