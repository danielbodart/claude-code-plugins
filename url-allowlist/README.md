# url-allowlist

A Claude Code plugin that **reduces prompt fatigue** by automatically approving `WebFetch` requests for URLs discovered via `WebSearch`.

## Why This Plugin?

By default, Claude Code asks for permission every time it wants to fetch a URL. When you're researching a topic, this means clicking "Allow" repeatedly for every search result Claude wants to read.

This plugin auto-approves fetches to URLs that came from search results, eliminating repetitive permission prompts while maintaining security for arbitrary URL access.

### Trust Model

This plugin auto-approves URLs that appear in search results. Claude's WebSearch uses [Brave Search](https://search.brave.com/) as its backend.

**What Brave Search filters:**
- Adult/explicit content (via Safe Search)
- SEO spam (community-driven ranking improvements)

**What it does NOT filter:**
- Malware or phishing URLs (Brave deliberately does not censor search results)

This means the trust model is similar to clicking links in any search results—you're trusting that malicious sites generally don't rank well organically, but there's no explicit security filtering. If you need to vet every URL before Claude fetches it, don't use this plugin.

## Features

- **Auto-approves** WebFetch for URLs returned by WebSearch
- **Handles redirects** automatically (approves redirect targets)
- **Configurable expiration** (default: 30 minutes)
- **Domain mode** option to approve entire domains from search results
- **Mode-aware behavior**:
  - **Autonomous mode**: Blocks non-search URLs (for scripted/headless use)
  - **Interactive mode**: Prompts for non-search URLs (preserves manual approval)

## Use Cases

- Reduce clicking fatigue during research sessions
- Enable smoother autonomous workflows that involve web research
- Security-conscious environments where you want auditable URL access

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
