#!/usr/bin/env bash
# PostToolUse hook for WebSearch - captures URLs from search results
# Stores them in a file that the WebFetch validator can check

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPROVED_URLS_FILE="$SCRIPT_DIR/../.approved-urls.txt"
LOG_FILE="$SCRIPT_DIR/../.url-hook.log"
ENV_FILE="$SCRIPT_DIR/../.env"

# Load config from .env if present
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Read the hook input from stdin
INPUT=$(cat)

# Extract URLs from tool_response
# Format: {"results": [{"content": [{"title": "...", "url": "..."}, ...]}]}
URLS=$(echo "$INPUT" | jq -r '.tool_response.results[].content[].url // empty' 2>/dev/null)

if [ -n "$URLS" ]; then
    # Append URLs to the approved list (with timestamp for expiry)
    TIMESTAMP=$(date +%s)
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            echo "$TIMESTAMP $url" >> "$APPROVED_URLS_FILE"
        fi
    done <<< "$URLS"

    # Also log for debugging
    echo "[$(date -Iseconds)] Captured $(echo "$URLS" | wc -l) URLs from WebSearch" >> "$LOG_FILE"
fi

exit 0
