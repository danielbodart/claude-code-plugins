#!/bin/bash
# PreToolUse hook for WebFetch - validates URL came from a recent WebSearch
#
# Behavior depends on permission mode:
#   - bypassPermissions/dontAsk: Strictly block non-search URLs (for autonomous mode)
#   - default/other: Prompt user to approve non-search URLs (for interactive mode)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPROVED_URLS_FILE="$SCRIPT_DIR/../.approved-urls.txt"
LOG_FILE="$SCRIPT_DIR/../.url-hook.log"

# Read the hook input from stdin
INPUT=$(cat)

# Extract the URL being fetched and permission mode
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty')
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // "default"')

# Determine if we're in strict mode (autonomous) or interactive mode
STRICT_MODE=false
if [ "$PERMISSION_MODE" = "bypassPermissions" ] || [ "$PERMISSION_MODE" = "dontAsk" ]; then
    STRICT_MODE=true
fi

# Helper function to deny or ask based on mode
deny_or_ask() {
    local reason="$1"
    if [ "$STRICT_MODE" = true ]; then
        # In autonomous mode: strictly deny
        jq -n --arg reason "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason
            }
        }'
    else
        # In interactive mode: ask the user
        jq -n --arg reason "$reason" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: $reason
            }
        }'
    fi
}

if [ -z "$URL" ]; then
    # No URL found, allow (might be malformed input)
    exit 0
fi

# Check if approved URLs file exists
if [ ! -f "$APPROVED_URLS_FILE" ]; then
    # No searches have been done yet
    echo "[$(date -Iseconds)] [$PERMISSION_MODE] URL not from a recent search (no searches recorded): $URL" >> "$LOG_FILE"
    deny_or_ask "URL must come from a WebSearch result. No searches have been performed yet."
    exit 0
fi

# Check if URL is in the approved list
FOUND=false
while IFS=' ' read -r timestamp url_entry; do
    if [ -z "$url_entry" ]; then
        continue
    fi

    # Check if URL matches (exact match or starts with approved URL)
    if [ "$URL" = "$url_entry" ] || [[ "$URL" == "$url_entry"* ]]; then
        FOUND=true
        break
    fi
done < "$APPROVED_URLS_FILE"

if [ "$FOUND" = true ]; then
    # URL is approved - allow
    echo "[$(date -Iseconds)] [$PERMISSION_MODE] Allowed fetch to: $URL" >> "$LOG_FILE"
    exit 0
else
    # URL not approved
    echo "[$(date -Iseconds)] [$PERMISSION_MODE] Not in search results: $URL" >> "$LOG_FILE"
    deny_or_ask "URL not found in recent WebSearch results. Please search for this URL first."
    exit 0
fi
