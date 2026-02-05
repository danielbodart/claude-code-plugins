---
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git blame:*), Bash(git show:*), Bash(git rev-parse:*), Bash(git branch:*)
description: Code review local uncommitted or unpushed changes (trunk-based alternative to /code-review)
---

Provide a code review for local changes.

First, ask the user which changes to review:

**Options:**
1. **Uncommitted changes** (default) - Review all staged and unstaged changes not yet committed
2. **Unpushed commits** - Review all commits on the current branch that haven't been pushed to origin

## Context

- Current git status: !`git status --short`
- Current branch: !`git branch --show-current`
- Unpushed commits (if any): !`git log --oneline @{upstream}..HEAD 2>/dev/null || echo "No upstream or no unpushed commits"`

Based on the user's choice, proceed with the review:

---

## Review Process

Follow these steps precisely:

1. **Check if review is needed**: Use a Haiku agent to check if there are actually changes to review. If there are no changes (empty diff), inform the user and stop.

2. **Gather CLAUDE.md files**: Use a Haiku agent to find all relevant CLAUDE.md files:
   - The root CLAUDE.md file (if one exists)
   - Any CLAUDE.md files in directories containing modified files
   Return just the file paths, not contents.

3. **Summarize the changes**: Use a Haiku agent to view the diff and return a brief summary of what changed.

4. **Launch parallel review agents**: Launch 5 parallel Sonnet agents to independently review the changes. Each agent should return a list of issues with the reason each was flagged:

   a. **Agent #1 (CLAUDE.md compliance)**: Audit changes against CLAUDE.md guidelines. Note that CLAUDE.md is guidance for Claude, so not all instructions apply during review.

   b. **Agent #2 (Bug scanner)**: Shallow scan for obvious bugs in the changes only. Focus on large bugs, avoid nitpicks. Ignore false positives.

   c. **Agent #3 (History context)**: Read git blame and history of modified code to identify bugs in light of historical context.

   d. **Agent #4 (Comment compliance)**: Read code comments in modified files and ensure changes comply with any guidance in the comments.

   e. **Agent #5 (Pattern consistency)**: Check that changes follow existing patterns in the codebase (naming conventions, error handling, etc.)

5. **Score each issue**: For each issue found, launch a parallel Haiku agent to score confidence (0-100). Give this rubric verbatim:

   - **0**: Not confident at all. False positive that doesn't stand up to scrutiny, or pre-existing issue.
   - **25**: Somewhat confident. Might be real, but may be false positive. If stylistic, not explicitly in CLAUDE.md.
   - **50**: Moderately confident. Real issue but might be a nitpick or rare in practice. Not very important relative to other changes.
   - **75**: Highly confident. Double-checked and very likely real. Will be hit in practice. Existing approach is insufficient. Important and directly impacts functionality, or directly mentioned in CLAUDE.md.
   - **100**: Absolutely certain. Confirmed real issue that will happen frequently. Evidence directly confirms this.

6. **Filter issues**: Keep only issues with score >= 80. If no issues meet this threshold, report that no significant issues were found.

7. **Present the review**: Output the review directly to the user (do not write to any files).

---

## Output Format

Present your review in this format:

```
## Code Review

**Changes reviewed:** [uncommitted changes | N unpushed commits]
**Files affected:** [list of files]

### Summary
[Brief description of what the changes do]

### Issues Found

[If issues with score >= 80 exist:]

1. **[Issue title]** (confidence: [score])

   [Description of the issue]

   File: [path/to/file.ext] (lines [start]-[end])
   Reason: [CLAUDE.md says "..." | bug due to ... | violates comment guidance | etc.]

2. ...

[If no issues >= 80:]

No significant issues found. Checked for:
- CLAUDE.md compliance
- Obvious bugs
- Historical context issues
- Code comment compliance
- Pattern consistency
```

---

## False Positives to Avoid

Do NOT flag these as issues:

- Pre-existing issues not introduced in these changes
- Something that looks like a bug but isn't
- Pedantic nitpicks a senior engineer wouldn't mention
- Issues linters/typecheckers/compilers would catch (imports, types, formatting)
- General quality issues (test coverage, documentation) unless in CLAUDE.md
- Issues called out in CLAUDE.md but silenced with lint ignore comments
- Intentional functionality changes related to the broader work
- Issues on lines not modified in the changes being reviewed

---

## Notes

- Do NOT attempt to build, typecheck, or run tests - assume these run separately
- Make a todo list first to track progress
- For "unpushed commits" mode, use: `git diff @{upstream}..HEAD`
- For "uncommitted changes" mode, use: `git diff HEAD` (includes staged and unstaged)
- Always cite the specific file and line numbers for each issue
