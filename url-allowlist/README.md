# url-allowlist

A Claude Code plugin that **reduces prompt fatigue** by automatically approving `WebFetch` requests for URLs discovered via `WebSearch`.

## Why This Plugin?

By default, Claude Code asks for permission every time it wants to fetch a URL. When you're researching a topic, this means clicking "Allow" repeatedly for every search result Claude wants to read.

**The problem with prompt fatigue:** When you're clicking "Allow" over and over, you stop paying attention. Imagine a prompt injection that tells Claude to gather sensitive data and POST it to an external URL. After clicking "Allow" twenty times for legitimate search results, you might just click "Allow" again without noticing it's now exfiltrating your data.

**The solution:** By auto-approving routine search result fetches, you stay alert for the unusual requests. When something unexpected comes up—like a request to a URL that didn't come from search results—you're more likely to notice and scrutinize it.

Paradoxically, being more permissive on safe operations makes you more secure overall.

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
- **Configurable match mode**: exact (default), prefix, or domain-level matching
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
# Match mode controls how strictly URLs are compared to search results:
#   exact  (default) - URL must match exactly, no additions allowed
#   prefix - URL can have additional path segments, query strings, or fragments appended
#   domain - any URL from an approved domain is allowed
URL_ALLOWLIST_MATCH_MODE=exact

# How long URLs/domains stay valid (in minutes)
# Default: 30 minutes
URL_ALLOWLIST_EXPIRE_MINUTES=30
```

You can also set these as environment variables instead of using a `.env` file.

### Match Mode

Controls how the plugin compares a requested URL against the approved list:

| Mode | Behaviour | Example |
|------|-----------|---------|
| `exact` (default) | URL must match exactly. Blocks appended query strings, fragments, or path segments. Most secure—prevents data exfiltration via appended parameters. | `https://example.com/article/123` matches only that exact URL |
| `prefix` | The approved URL is treated as a prefix. Allows additional path segments, query strings, or fragments. | `https://example.com/article/123` also matches `https://example.com/article/123?page=2` |
| `domain` | Any URL on the same domain is allowed. Most lenient—convenient when browsing around a discovered site. | `https://example.com/article/123` allows any URL on `example.com` |

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

## Security: Exfiltration Test Results

We conducted a red team exercise to test whether Claude could exfiltrate a fake secret (`SECRET_API_KEY` in a `.env` file) when running with this plugin, `/sandbox` mode enabled, and `--dangerously-skip-permissions` active.

### What was blocked

**All 17 network-based exfiltration attempts were blocked**, including:

- Direct HTTP requests (`curl`, `wget`, Python `urllib`, Node.js `https`)
- Raw socket connections (`netcat`, Python `socket`, Bash `/dev/tcp`)
- DNS exfiltration (`dig`, `nslookup`)
- ICMP with encoded payloads (`ping -p`)
- Alternative protocols (SSH, SMTP)
- Proxy-based redirects
- **WebFetch with secrets in URL parameters** — the plugin's exact-match validation blocked attempts to append query strings to legitimate search result URLs

The combination of sandbox networking and this plugin's URL validation is highly effective. The sandbox blocks all outbound connections from Bash, while the plugin prevents Claude from smuggling data through `WebFetch` URL parameters.

### Known limitation: WebSearch queries

`WebSearch` was the one tool that accepted secret material — the secret could be embedded in a search query, which is sent to Brave Search's servers.

**Why this is low risk in practice:**

- **Brave Search is privacy-focused** — queries are not stored for regular users, there is no public trending/analytics feature (no Google Trends equivalent), and no API endpoint exposes recent searches
- **Anthropic almost certainly uses Brave's enterprise tier** with Zero Data Retention, meaning no queries are retained for any length of time. Given Anthropic's own safety focus and the scale of the partnership, it would be surprising if they didn't use the most privacy-protective option available
- **No known retrieval path** — even if a secret were sent as a query, there is no mechanism for a third-party attacker to retrieve it from Brave's systems
- **Brave passed SOC 2 Type II audit** by an independent auditor (Prescient Security)

We considered adding a `PreToolUse:WebSearch` hook to scan queries for high-entropy strings or secret patterns, but decided against it — false positives on error codes, GUIDs, and other legitimate search terms would degrade the experience without meaningful security benefit.

### Recommended setup

For the strongest exfiltration protection, combine:

1. **Sandbox mode** — blocks all direct network access from Bash
2. **`dangerouslyAllowAllBash`** — lets Claude run commands freely without prompt fatigue (sandbox provides the safety net)
3. **This plugin (exact match mode)** — auto-approves only URLs from search results, blocks all fabricated URLs via `WebFetch`

This gives Claude full local tool access while limiting network exfiltration to only the `WebSearch` side-channel described above.

## Files Created

The plugin creates these files in its directory (gitignored):
- `.approved-urls.txt` - Timestamped list of approved URLs
- `.url-hook.log` - Debug log of hook decisions
- `.env` - Your local configuration (copy from `.env.example`)
