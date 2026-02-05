# code-review-local

Automated code review for local changes using multiple specialized agents with confidence-based scoring. Designed for trunk-based development workflows where you review changes before committing or pushing.

## Overview

This plugin reviews your local changes before they leave your machine. Unlike PR-based review tools, it works with:

- **Uncommitted changes**: All staged and unstaged modifications
- **Unpushed commits**: Local commits not yet pushed to origin

It uses the same multi-agent approach as PR review tools, with confidence scoring to filter out false positives and surface only high-quality, actionable feedback.

## Command

### `/code-review:code-review-local`

Reviews local changes using multiple specialized agents running in parallel.

> **Note:** This plugin uses the `code-review` namespace to appear alongside the official `code-review` plugin from `anthropics/claude-plugins-official` (which provides `/code-review:code-review` for PR reviews).

**What it does:**

1. Asks which changes to review (uncommitted or unpushed)
2. Checks if there are actually changes to review
3. Gathers relevant CLAUDE.md guideline files
4. Summarizes the changes
5. Launches 5 parallel agents to independently review:
   - **Agent #1**: CLAUDE.md compliance
   - **Agent #2**: Obvious bug detection
   - **Agent #3**: Git history context analysis
   - **Agent #4**: Code comment compliance
   - **Agent #5**: Pattern consistency
6. Scores each issue 0-100 for confidence
7. Filters out issues below 80 threshold
8. Outputs review directly to terminal

**Usage:**

```bash
/code-review:code-review-local
```

## Review Modes

### Uncommitted Changes (Default)

Reviews all modifications not yet committed:
- Staged changes (`git add`ed files)
- Unstaged changes (modified but not staged)

Best for: Reviewing your work before making a commit.

```bash
# Make changes to your code
/code-review:code-review-local
# Select "Uncommitted changes"
# Review feedback, fix issues
# Then commit
```

### Unpushed Commits

Reviews all commits on current branch not yet pushed to origin:
- Multiple local commits
- Micro-commits made during development

Best for: Final review before pushing, especially with trunk-based development.

```bash
# Make several local commits
git commit -m "Add feature"
git commit -m "Fix edge case"
git commit -m "Add tests"

# Review all commits before pushing
/code-review:code-review-local
# Select "Unpushed commits"
# Review feedback
# Then push
```

## Confidence Scoring

Each issue is independently scored 0-100:

| Score | Meaning |
|-------|---------|
| 0 | False positive, doesn't hold up to scrutiny |
| 25 | Might be real, could be false positive |
| 50 | Real but minor, nitpick, or rare |
| 75 | Very likely real, important, will be hit in practice |
| 100 | Definitely real, frequent, evidence confirms |

**Only issues scoring 80+ are reported.**

## What Gets Filtered Out

The review automatically ignores:

- Pre-existing issues (not introduced in your changes)
- False alarms that look like bugs but aren't
- Pedantic nitpicks
- Issues linters/compilers catch (types, imports, formatting)
- General quality issues (unless specified in CLAUDE.md)
- Code with lint ignore comments
- Intentional functionality changes
- Issues on unmodified lines

## Output Format

```
## Code Review

**Changes reviewed:** uncommitted changes
**Files affected:** src/auth.ts, src/utils.ts

### Summary
Added OAuth error handling and refactored utility functions.

### Issues Found

1. **Missing null check** (confidence: 85)

   The OAuth callback doesn't handle the case where state is undefined.

   File: src/auth.ts (lines 67-72)
   Reason: bug due to missing defensive check before accessing state.token

2. **Inconsistent error format** (confidence: 82)

   Error messages use different formats than existing code.

   File: src/utils.ts (lines 23-28)
   Reason: CLAUDE.md says "Use consistent error message format: 'Action failed: reason'"
```

## Integration with Trunk-Based Development

This plugin complements the `commit-push-trunk` workflow:

```bash
# 1. Make changes
# 2. Review before committing
/code-review:code-review-local

# 3. Fix any issues found
# 4. Commit and push
/commit-push-trunk
```

Or with micro-commits:

```bash
# 1. Make changes in small commits
git commit -m "Step 1"
git commit -m "Step 2"

# 2. Review all commits before pushing
/code-review:code-review-local
# Select "Unpushed commits"

# 3. Fix issues if needed
# 4. Push to trunk
/commit-push-trunk
```

## Requirements

- Git repository
- CLAUDE.md files (optional but recommended for guideline checking)

## Installation

1. Add the marketplace:
```
/plugin marketplace add danielbodart/claude-code-plugins
```

2. Install the plugin:
```
/plugin install code-review@danielbodart-plugins
```

## Local Testing

```bash
claude --plugin-dir ./code-review-local
```

## Comparison with PR Review

| Feature | PR Review | Local Review |
|---------|-----------|--------------|
| Reviews | Pull requests | Local changes |
| Output | GitHub comment | Terminal output |
| Requires | GitHub CLI, PR | Git only |
| Timing | After PR created | Before commit/push |
| Workflow | Branch-based | Trunk-based |

## Tips

- **Review early**: Check uncommitted changes before they become commits
- **Review often**: Small reviews are faster and more accurate
- **Trust the threshold**: Issues below 80 are filtered for a reason
- **Maintain CLAUDE.md**: Clear guidelines improve review quality
- **Use with micro-commits**: Review unpushed commits as a final check

## Credits

Based on the official Claude Code [code-review plugin](https://github.com/anthropics/claude-code/tree/main/plugins/code-review) by Boris Cherny at Anthropic. Adapted for local/trunk-based workflows.

## Author

Daniel Worthington-Bodart (dan@bodar.com)

## License

MIT
