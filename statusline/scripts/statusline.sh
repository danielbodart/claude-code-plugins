#!/bin/bash
# Claude Code statusLine — self-contained (one file, no siblings).
#
# Two modes, selected by the first argument:
#   (none)         render the status line (reads the statusLine JSON on stdin)
#   refresh-quota  fetch subscription quota → ~/.claude/quota-cache.json
#
# Renders, left to right:
#   <project dir (~-abbreviated)> [(worktree)] │ <git branch> │
#   [context bar] │ [5-hour bar] │ [weekly bar] │ <model>
#
# Installed by the "statusline" plugin (danielbodart/claude-code-plugins).
# The render path kicks the quota refresh by re-invoking THIS script with
# `refresh-quota`, so a single symlink is enough to install it and it always
# self-updates with the plugin — there is no second file to keep in sync.

# ANSI escapes as real bytes (safe to print with %s). Globals so both the
# renderer and make_bar can see them.
esc=$'\033'; reset="${esc}[0m"; dim="${esc}[2m"
cyan="${esc}[36m"; green="${esc}[92m"; yellow="${esc}[33m"; red="${esc}[31m"; magenta="${esc}[38;5;141m"
blue="${esc}[38;5;39m"
sep=" ${dim}│${reset} "

# ---------- Helper: render a labelled percentage bar ----------
# usage: make_bar LABEL PCT DEFAULT_COLOR   (echoes the coloured segment)
# PCT empty -> greyed-out placeholder. Colour ramps green<50<yellow<80<red,
# unless a fixed DEFAULT_COLOR is passed for the <50 band.
make_bar() {
  local label="$1" p="$2" base="${3:-$green}" w=8
  if [ -z "$p" ]; then
    printf '%s' "${dim}${label}:[--------] --%${reset}"
    return
  fi
  [ "$p" -gt 100 ] 2>/dev/null && p=100
  [ "$p" -lt 0 ] 2>/dev/null && p=0
  local filled=$(( p * w / 100 )) empty c
  local e=$(( w - filled ))
  if   [ "$p" -ge 80 ]; then c="$red"
  elif [ "$p" -ge 50 ]; then c="$yellow"
  else c="$base"; fi
  local fs="" es="" i=0
  while [ "$i" -lt "$filled" ]; do fs="${fs}■"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$e" ]; do es="${es}□"; i=$((i+1)); done
  printf '%s' "${c}${label}:[${fs}${dim}${es}${c}] ${p}%${reset}"
}

# ============================ quota refresh =================================
# Fetches subscription rate-limit utilization from the Anthropic OAuth usage
# endpoint and caches it to ~/.claude/quota-cache.json for the renderer.
# Fails silently (leaving any existing cache untouched) on missing token,
# network error, non-200, or unparseable body. The OAuth token is only ever
# passed to curl via a header — it is never printed.
refresh_quota() {
  local creds="$HOME/.claude/.credentials.json"
  local cache="$HOME/.claude/quota-cache.json"
  local tmp="$cache.tmp.$$"
  local tok="" keychain_json="" body="$tmp.body" code now

  command -v jq   >/dev/null 2>&1 || return 0
  command -v curl >/dev/null 2>&1 || return 0

  # Try credentials file first (Linux), then macOS Keychain.
  if [ -f "$creds" ]; then
    tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
  elif command -v security >/dev/null 2>&1; then
    keychain_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || true
    if [ -n "$keychain_json" ]; then
      tok=$(printf '%s' "$keychain_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
    keychain_json=""
  fi
  [ -z "$tok" ] && return 0

  code=$(curl -sS -m 15 -o "$body" -w '%{http_code}' \
    -H "Authorization: Bearer $tok" \
    -H "anthropic-beta: oauth-2025-04-20" \
    https://api.anthropic.com/api/oauth/usage 2>/dev/null)
  tok=""

  if [ "$code" != "200" ] || [ ! -s "$body" ]; then
    rm -f "$body"
    return 0
  fi

  now=$(date +%s)
  if ! jq -e \
    --argjson ts "$now" \
    '{
       five_hour:        (.five_hour.utilization // null),
       seven_day:        (.seven_day.utilization // null),
       five_hour_resets: (.five_hour.resets_at // null),
       seven_day_resets: (.seven_day.resets_at // null),
       ts: $ts
     }' "$body" > "$tmp" 2>/dev/null; then
    rm -f "$body" "$tmp"
    return 0
  fi

  rm -f "$body"
  mv -f "$tmp" "$cache" 2>/dev/null || rm -f "$tmp"
}

# =============================== renderer ===================================
render() {
  local input; input=$(cat 2>/dev/null)

  local have_jq=0
  command -v jq >/dev/null 2>&1 && have_jq=1

  local project_dir="" cwd="" model_id="" model_name="" transcript_path=""
  local ctx_pct="" window_size="" used_tokens=""
  if [ -n "$input" ] && [ "$have_jq" -eq 1 ]; then
    # context_window.* is what Claude Code itself uses for /context and the
    # auto-compact warning: the real window size for the current model (200k,
    # 1M, …) and a pre-computed used %. Any field that is absent or null simply
    # leaves the variable empty (empty interpolation drops the whole @sh line).
    eval "$(printf '%s' "$input" | jq -r '
      @sh "project_dir=\(.workspace.project_dir // "")",
      @sh "cwd=\(.cwd // "")",
      @sh "model_id=\(.model.id // "")",
      @sh "model_name=\(.model.display_name // "")",
      @sh "transcript_path=\(.transcript_path // "")",
      @sh "ctx_pct=\(.context_window.used_percentage // empty | floor)",
      @sh "window_size=\(.context_window.context_window_size // empty)",
      @sh "used_tokens=\(.context_window.total_input_tokens // empty)"
    ' 2>/dev/null)"
  fi

  local dir="${project_dir:-$cwd}"

  # ---------- Segment 1: directory (~-abbreviated) ----------
  # Detect Claude Code worktrees: .claude/worktrees/<name> → show project root
  local is_worktree=0 dir_display="$dir"
  case "$dir" in
    */.claude/worktrees/*)
      is_worktree=1
      dir_display="${dir%%/.claude/worktrees/*}"
      ;;
  esac
  case "$dir_display" in
    "$HOME") dir_display="~" ;;
    "$HOME"/*) dir_display="~${dir_display#"$HOME"}" ;;
  esac
  [ -z "$dir_display" ] && dir_display="?"

  # ---------- Segment 2: git branch ----------
  local branch=""
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    branch=$(git --no-optional-locks -C "$dir" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git --no-optional-locks -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ "$branch" = "HEAD" ] && branch=""
  fi
  # In a worktree, strip the "worktree-" prefix — the (worktree) label covers it
  if [ "$is_worktree" -eq 1 ]; then
    branch="${branch#worktree-}"
  fi

  # ---------- Segment 3: context usage bar ----------
  # Preferred source is context_window.used_percentage (parsed above). The
  # fallbacks below only matter on Claude Code builds that predate that field:
  #   1. total_input_tokens / context_window_size if only the % is missing
  #   2. sum the last usage entry in the transcript, dividing by the reported
  #      window size or, failing that, a guess from the model id — the guess
  #      is the least reliable step (ids don't reliably encode the window).
  if [ -z "$ctx_pct" ]; then
    if [ -z "$used_tokens" ] && [ "$have_jq" -eq 1 ] && [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
      used_tokens=$(jq -r '(.message.usage // .usage // empty)
          | ((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' \
        "$transcript_path" 2>/dev/null | grep -E '^[0-9]+$' | tail -n 1)
    fi
    if ! [ "$window_size" -gt 0 ] 2>/dev/null; then
      window_size=200000
      printf '%s' "$model_id" | grep -qi '1m' && window_size=1000000
    fi
    [ -n "$used_tokens" ] && ctx_pct=$(( used_tokens * 100 / window_size ))
  fi
  local ctx_bar; ctx_bar=$(make_bar "C" "$ctx_pct" "$green")

  # ---------- Segment 4: subscription quota (5-hour = 5, weekly = W) ----------
  # Read the cache written by `refresh-quota`; if it's stale, kick a refresh in
  # the background (non-blocking) by re-invoking THIS script, so the next render
  # is fresh. No daemon and no sibling file needed. The cache always lives in
  # ~/.claude — a shared, writable spot, never the plugin dir.
  local self="${BASH_SOURCE[0]:-$0}"
  local quota_cache="$HOME/.claude/quota-cache.json"
  local stale_after=900          # 15 min
  local d_pct="" w_pct="" cache_ts=0

  if [ "$have_jq" -eq 1 ] && [ -f "$quota_cache" ]; then
    eval "$(jq -r '
      @sh "cache_ts=\(.ts // 0)",
      @sh "d_pct=\((.five_hour // empty) | floor)",
      @sh "w_pct=\((.seven_day // empty) | floor)"
    ' "$quota_cache" 2>/dev/null)"
  fi

  local now_epoch age
  now_epoch=$(date +%s 2>/dev/null || echo 0)
  age=$(( now_epoch - cache_ts ))
  if [ ! -f "$quota_cache" ] || [ "$age" -ge "$stale_after" ]; then
    # stale or missing -> refresh out of band, don't block the prompt
    ( bash "$self" refresh-quota >/dev/null 2>&1 & ) 2>/dev/null
  fi
  # If the cache is far too old, treat values as unknown so we don't show stale %.
  if [ "$age" -ge "$(( stale_after * 4 ))" ]; then d_pct=""; w_pct=""; fi

  local d_bar w_bar
  d_bar=$(make_bar "5" "$d_pct" "$cyan")
  w_bar=$(make_bar "W" "$w_pct" "$magenta")

  # ---------- Segment 5: model ----------
  [ -z "$model_name" ] && model_name="?"

  # ---------- Assemble (printf %s: no format-string interpretation of % or bytes) ----------
  local out="${cyan}${dir_display}${reset}"
  [ "$is_worktree" -eq 1 ] && out="${out} ${dim}(worktree)${reset}"
  [ -n "$branch" ] && out="${out}${sep}${green}${branch}${reset}"
  out="${out}${sep}${ctx_bar}${sep}${d_bar}${sep}${w_bar}${sep}${magenta}${model_name}${reset}"
  printf '%s\n' "$out"
}

# =============================== dispatch ===================================
case "${1:-}" in
  refresh-quota) refresh_quota ;;
  *)             render ;;
esac
