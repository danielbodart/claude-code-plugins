---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git push:*), Bash(git commit:*), Bash(git rebase:*), Bash(git merge:*), Bash(git pull:*), Bash(git -C:*), Bash(git diff:*), Bash(git branch:*), Bash(git symbolic-ref:*), Bash(git worktree list:*), Bash(git worktree list), Bash(git config:*), Bash(git config --get:*), Bash(git checkout:*), Bash(gh run list:*), Bash(gh run watch:*), Bash(gh run view:*), Bash(ls:*), Bash(test:*)
description: Commit and push directly to trunk with linear history, then monitor the CI build (supports worktrees)
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Worktree list: !`git worktree list`
- GitHub Actions configs: !`ls -1 "$(git rev-parse --show-toplevel)/.github/workflows"/*.yml "$(git rev-parse --show-toplevel)/.github/workflows"/*.yaml 2>/dev/null || echo "(none)"`
- CircleCI config: !`ls -1 "$(git rev-parse --show-toplevel)/.circleci/config.yml" 2>/dev/null || echo "(none)"`

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

Requirements:
- Always use `--ff-only` for merges (ensures linear history)
- Always use `--rebase` for pulls (ensures linear history)
- Use `git -C <path>` to run commands in main repo when in a worktree
- Create meaningful commit message based on the changes
- You have the capability to call multiple tools in a single response. You MUST do the commit/push steps in a single message.

## Monitor the CI build

After the push succeeds, detect which CI/CD system the repo uses from the Context above (`GitHub Actions configs` and `CircleCI config`), then monitor the build that the push triggered.

**Which system:**
- **GitHub Actions only** (`.github/workflows/*` present, no CircleCI) → monitor via `gh`.
- **CircleCI only** (`.circleci/config.yml` present, no GitHub Actions) → monitor via CircleCI.
- **Both present** → warn the user: two CI systems are configured, which usually means a mid-transition repo where one build is disabled and the other active. Recommend removing the unused config files. Then monitor whichever build actually ran (the one that produced a run for the pushed commit).
- **Neither present** → no CI configured; report that and stop.

**GitHub Actions** — always resolve the run id first, then watch that id. NEVER run bare `gh run watch` (with no id it is interactive and hangs), and do NOT hand-roll a polling loop — `gh run watch <id>` already polls to completion.

1. Capture the exact commit you just pushed. On trunk after the merge/push, that is `HEAD`:
   `PUSHED_SHA=$(git rev-parse HEAD)` (worktree: run in the main repo, e.g. `git -C <main-repo> rev-parse HEAD`).
2. Resolve the run id for that SHA, retrying because the run registers a few seconds after push:
   ```bash
   for i in 1 2 3 4 5; do
     RUN_ID=$(gh run list -c "$PUSHED_SHA" -L 1 --json databaseId -q '.[0].databaseId')
     [ -n "$RUN_ID" ] && break
     sleep 3
   done
   ```
   If still empty after retries, the push may not have triggered a workflow (e.g. paths filter) — report that and stop, don't fall back to watching an unrelated run.
3. Watch that specific run to completion: `gh run watch "$RUN_ID" --exit-status`
   (`--exit-status` → non-zero on failure; the command polls internally, so this is the watch.)
4. On failure, surface the failing job/step: `gh run view "$RUN_ID" --log-failed`

**CircleCI:**
1. Prefer the `circleci` CLI if available. Otherwise query the API for the pipeline of the pushed commit (`https://circleci.com/api/v2/project/gh/<owner>/<repo>/pipeline`), needs `CIRCLECI_TOKEN`.
2. Poll the workflow status until it reaches a terminal state (`success` / `failed` / `error` / `canceled`).
3. On failure, report which job failed.

Report the final build status (pass/fail) to the user. On failure, summarize what broke. If the required CLI/token is missing, say so and give the URL to watch manually rather than blocking.
