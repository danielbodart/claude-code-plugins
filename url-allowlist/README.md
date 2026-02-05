# url-allowlist

A Claude Code plugin that restricts `WebFetch` to URLs discovered via `WebSearch` results, preventing arbitrary URL access.

## Features

- Captures URLs from WebSearch results automatically
- Validates WebFetch requests against the allowlist
- Handles redirect URLs (automatically approves redirect targets)
- Mode-aware behavior:
  - **Autonomous mode**: Strictly blocks non-allowlisted URLs
  - **Interactive mode**: Prompts user to approve unknown URLs

## Use Cases

- Prevent Claude from fetching arbitrary URLs in autonomous/scripted sessions
- Ensure web access is scoped to search-discovered content
- Security-conscious environments where URL access should be auditable

## Requirements

- `jq` - JSON processor

## How It Works

1. When Claude performs a WebSearch, all result URLs are captured to an allowlist
2. When Claude attempts a WebFetch:
   - If the URL is in the allowlist → allowed
   - If not in allowlist:
     - Autonomous mode → blocked with explanation
     - Interactive mode → user prompted to approve
3. Redirect URLs are automatically added to the allowlist

## Files Created

The plugin creates these files in its directory (gitignored):
- `.approved-urls.txt` - Timestamped list of approved URLs
- `.url-hook.log` - Debug log of hook decisions
