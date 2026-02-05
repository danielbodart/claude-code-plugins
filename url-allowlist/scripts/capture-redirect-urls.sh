#!/bin/bash
# PostToolUse hook for WebFetch - captures redirect URLs from responses
# Adds them to the approved list so following redirects works

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPROVED_URLS_FILE="$SCRIPT_DIR/../.approved-urls.txt"
LOG_FILE="$SCRIPT_DIR/../.url-hook.log"

# Read the hook input from stdin
INPUT=$(cat)

# Look for redirect URL in the response
# The response contains text like: "Redirect URL: https://..."
RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty' 2>/dev/null)

if [ -z "$RESPONSE" ]; then
    exit 0
fi

# Extract redirect URL - it appears after "Redirect URL: "
# Stop at newline, space, or common terminators
REDIRECT_URL=$(echo "$RESPONSE" | grep -oP 'Redirect URL: \K[^\s\\]+' | head -1)

if [ -n "$REDIRECT_URL" ]; then
    TIMESTAMP=$(date +%s)
    echo "$TIMESTAMP $REDIRECT_URL" >> "$APPROVED_URLS_FILE"
    echo "[$(date -Iseconds)] Captured redirect URL: $REDIRECT_URL" >> "$LOG_FILE"
fi

exit 0
