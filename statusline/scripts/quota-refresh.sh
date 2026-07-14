#!/bin/bash
# Claude Code quota refresher
#
# Fetches subscription rate-limit utilization from the Anthropic OAuth usage
# endpoint and caches it to ~/.claude/quota-cache.json for statusline.sh.
#
# Writes: { "five_hour": <pct>, "seven_day": <pct>,
#           "five_hour_resets": <iso|null>, "seven_day_resets": <iso|null>,
#           "ts": <epoch-seconds> }
#
# Fails silently (leaves any existing cache untouched) on missing token,
# network error, non-200, or unparseable body. The OAuth token is only ever
# passed to curl via a header — it is never printed.
#
# Installed by the "statusline" plugin (danielbodart/claude-code-plugins).

set -u
creds="$HOME/.claude/.credentials.json"
cache="$HOME/.claude/quota-cache.json"
tmp="$cache.tmp.$$"

command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
[ -f "$creds" ] || exit 0

tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
[ -z "$tok" ] && exit 0

body="$tmp.body"
code=$(curl -sS -m 15 -o "$body" -w '%{http_code}' \
  -H "Authorization: Bearer $tok" \
  -H "anthropic-beta: oauth-2025-04-20" \
  https://api.anthropic.com/api/oauth/usage 2>/dev/null)
unset tok

if [ "$code" != "200" ] || [ ! -s "$body" ]; then
  rm -f "$body"
  exit 0
fi

# now() is passed in via arg so the script is deterministic to call; default to date.
now=$(date +%s)

if ! jq -e \
  --argjson ts "$now" \
  '{
     five_hour:        ((.five_hour.utilization // null)),
     seven_day:        ((.seven_day.utilization // null)),
     five_hour_resets: (.five_hour.resets_at // null),
     seven_day_resets: (.seven_day.resets_at // null),
     ts: $ts
   }' "$body" > "$tmp" 2>/dev/null; then
  rm -f "$body" "$tmp"
  exit 0
fi

rm -f "$body"
mv -f "$tmp" "$cache" 2>/dev/null || rm -f "$tmp"
