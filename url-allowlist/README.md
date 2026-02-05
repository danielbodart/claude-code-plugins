# url-allowlist

A Claude Code plugin that restricts `WebFetch` to URLs discovered via `WebSearch` results, preventing arbitrary URL access.

## Features

- Captures URLs from WebSearch results automatically
- Validates WebFetch requests against the allowlist
- Handles redirect URLs (automatically approves redirect targets)
- Configurable URL expiration (default: 30 minutes)
- Optional domain-level matching (approve entire domains, not just exact URLs)
- Mode-aware behavior:
  - **Autonomous mode**: Strictly blocks non-allowlisted URLs
  - **Interactive mode**: Prompts user to approve unknown URLs

## Use Cases

- Prevent Claude from fetching arbitrary URLs in autonomous/scripted sessions
- Ensure web access is scoped to search-discovered content
- Security-conscious environments where URL access should be auditable

## Requirements

- `jq` - JSON processor

## Configuration

Copy `.env.example` to `.env` and customize:

```bash
# Domain mode: if "true", allow any URL from domains seen in search results
# If "false" (default), only exact URLs from search results are allowed
URL_ALLOWLIST_DOMAIN_MODE=false

# How long URLs/domains stay valid (in minutes)
# Default: 30 minutes
URL_ALLOWLIST_EXPIRE_MINUTES=30
```

You can also set these as environment variables instead of using a `.env` file.

### Domain Mode

When `URL_ALLOWLIST_DOMAIN_MODE=true`, a search result from `https://example.com/article/123` will allow fetching any URL from `example.com`, not just that specific article. This is more lenient but convenient when you want to browse around a discovered site.

### Expiration

URLs automatically expire after `URL_ALLOWLIST_EXPIRE_MINUTES` (default 30). This prevents stale search results from being used indefinitely. Set to a higher value for longer sessions, or lower for stricter security.

## How It Works

1. When Claude performs a WebSearch, all result URLs are captured to an allowlist with timestamps
2. When Claude attempts a WebFetch:
   - If the URL (or domain in domain mode) is in the allowlist and not expired → allowed
   - If not in allowlist or expired:
     - Autonomous mode → blocked with explanation
     - Interactive mode → user prompted to approve
3. Redirect URLs are automatically added to the allowlist

## Files Created

The plugin creates these files in its directory (gitignored):
- `.approved-urls.txt` - Timestamped list of approved URLs
- `.url-hook.log` - Debug log of hook decisions
- `.env` - Your local configuration (copy from `.env.example`)
