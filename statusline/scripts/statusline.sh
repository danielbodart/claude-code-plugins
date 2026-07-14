#!/bin/bash
# Claude Code statusLine script
#
# Reads the statusLine JSON payload on stdin. Renders, left to right:
#   <project dir (~-abbreviated)> │ <git branch> │ [context usage bar] │ <model>
#
# Installed by the "statusline" plugin (danielbodart/claude-code-plugins).
# To change it, edit the repo copy and re-run /install-statusline, or edit
# this file directly.

input=$(cat 2>/dev/null)

have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

project_dir="" cwd="" model_id="" model_name="" transcript_path=""
if [ -n "$input" ] && [ "$have_jq" -eq 1 ]; then
  eval "$(printf '%s' "$input" | jq -r '
    @sh "project_dir=\(.workspace.project_dir // "")",
    @sh "cwd=\(.cwd // "")",
    @sh "model_id=\(.model.id // "")",
    @sh "model_name=\(.model.display_name // "")",
    @sh "transcript_path=\(.transcript_path // "")"
  ' 2>/dev/null)"
fi

dir="${project_dir:-$cwd}"

# ANSI escapes as real bytes (safe to print with %s).
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

# ---------- Segment 1: directory (~-abbreviated) ----------
dir_display="$dir"
case "$dir" in
  "$HOME") dir_display="~" ;;
  "$HOME"/*) dir_display="~${dir#"$HOME"}" ;;
esac
[ -z "$dir_display" ] && dir_display="?"

# ---------- Segment 2: git branch ----------
branch=""
if [ -n "$dir" ] && [ -d "$dir" ]; then
  branch=$(git --no-optional-locks -C "$dir" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git --no-optional-locks -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$branch" = "HEAD" ] && branch=""
fi

# ---------- Segment 3: context usage bar ----------
bar_width=8
window_size=200000
printf '%s' "$model_id" | grep -qi '1m' && window_size=1000000

used_tokens=""
if [ "$have_jq" -eq 1 ] && [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  used_tokens=$(jq -r '(.message.usage // .usage // empty)
      | ((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' \
    "$transcript_path" 2>/dev/null | grep -E '^[0-9]+$' | tail -n 1)
fi

ctx_pct=""
[ -n "$used_tokens" ] && ctx_pct=$(( used_tokens * 100 / window_size ))
ctx_bar=$(make_bar "C" "$ctx_pct" "$green")

# ---------- Segment 4: subscription quota (5-hour = 5, weekly = W) ----------
# Read the cache written by quota-refresh.sh; if it's stale, kick a refresh in
# the background (non-blocking) so the next render is fresh. No daemon needed.
#
# quota-refresh.sh is found next to THIS script (works whether we were copied
# into ~/.claude or are running in place from an installed plugin). The cache
# always lives in ~/.claude — a shared, writable spot, never the plugin dir.
self_dir=$(CDPATH= cd -- "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)
quota_cache="$HOME/.claude/quota-cache.json"
refresher="$self_dir/quota-refresh.sh"
[ -x "$refresher" ] || refresher="$HOME/.claude/quota-refresh.sh"
stale_after=900          # 15 min
d_pct="" w_pct="" cache_ts=0

if [ "$have_jq" -eq 1 ] && [ -f "$quota_cache" ]; then
  eval "$(jq -r '
    @sh "cache_ts=\(.ts // 0)",
    @sh "d_pct=\((.five_hour // empty) | floor)",
    @sh "w_pct=\((.seven_day // empty) | floor)"
  ' "$quota_cache" 2>/dev/null)"
fi

now_epoch=$(date +%s 2>/dev/null || echo 0)
age=$(( now_epoch - cache_ts ))
if [ ! -f "$quota_cache" ] || [ "$age" -ge "$stale_after" ]; then
  # stale or missing -> refresh out of band, don't block the prompt
  [ -x "$refresher" ] && ( "$refresher" >/dev/null 2>&1 & ) 2>/dev/null
fi
# If the cache is far too old, treat values as unknown so we don't show stale %.
if [ "$age" -ge "$(( stale_after * 4 ))" ]; then d_pct=""; w_pct=""; fi

d_bar=$(make_bar "5" "$d_pct" "$blue")
w_bar=$(make_bar "W" "$w_pct" "$blue")

# ---------- Segment 5: model ----------
[ -z "$model_name" ] && model_name="?"

# ---------- Assemble (printf %s: no format-string interpretation of % or bytes) ----------
out="${cyan}${dir_display}${reset}"
[ -n "$branch" ] && out="${out}${sep}${green}${branch}${reset}"
out="${out}${sep}${ctx_bar}${sep}${d_bar}${sep}${w_bar}${sep}${magenta}${model_name}${reset}"
printf '%s\n' "$out"
