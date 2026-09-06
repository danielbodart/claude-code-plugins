#!/usr/bin/env bash
# Check that required system dependencies are installed
# Runs as a SessionStart hook to warn early about missing tools

# Consume stdin (SessionStart sends JSON input)
cat > /dev/null

source "$(dirname "${BASH_SOURCE[0]}")/lib-deps.sh"

missing=()
command -v jq &>/dev/null || missing+=("jq|jq")

report_missing "url-allowlist" "${missing[@]}"
exit $?
