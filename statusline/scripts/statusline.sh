#!/bin/bash
# Claude Code statusLine — self-contained (one file, no siblings, no network).
#
# Reads the statusLine JSON that Claude Code passes on stdin and renders,
# left to right:
#   <project dir (~-abbreviated)> [(worktree)] │ <git branch> │
#   [context bar] │ [5-hour bar] │ [weekly bar] │ <model>
#
# Everything comes from that JSON payload (see
# https://code.claude.com/docs/en/statusline): the context bar from
# `context_window`, the quota bars from `rate_limits`. The only thing this
# script touches on disk is ~/.claude/quota-cache.json, a copy of the last
# `rate_limits` seen, so the quota bars are populated from the first prompt
# of a new session instead of waiting for its first API response.
#
# Installed by the "statusline" plugin (danielbodart/claude-code-plugins).

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

# =============================== renderer ===================================
render() {
  local input; input=$(cat 2>/dev/null)

  local have_jq=0
  command -v jq >/dev/null 2>&1 && have_jq=1

  # One jq pass pulls every field we use. A field that is absent or null
  # leaves its variable empty: an empty interpolation drops the whole @sh line.
  #   context_window.*  — what /context shows: real window size for the model
  #                       (200k, 1M, …) and a pre-computed used %.
  #   rate_limits.*     — subscription 5-hour / 7-day usage, 0–100. Only sent
  #                       for Pro/Max logins and only after the session's first
  #                       API response; a window vanishes once it resets.
  #   worktree.*        — present only inside a Claude Code worktree session.
  local project_dir="" cwd="" model_id="" model_name="" transcript_path=""
  local ctx_pct="" window_size="" used_tokens=""
  local d_pct="" w_pct="" d_resets="" w_resets="" wt_orig=""
  if [ -n "$input" ] && [ "$have_jq" -eq 1 ]; then
    eval "$(printf '%s' "$input" | jq -r '
      @sh "project_dir=\(.workspace.project_dir // "")",
      @sh "cwd=\(.cwd // "")",
      @sh "model_id=\(.model.id // "")",
      @sh "model_name=\(.model.display_name // "")",
      @sh "transcript_path=\(.transcript_path // "")",
      @sh "ctx_pct=\(.context_window.used_percentage // empty | floor)",
      @sh "window_size=\(.context_window.context_window_size // empty)",
      @sh "used_tokens=\(.context_window.total_input_tokens // empty)",
      @sh "d_pct=\(.rate_limits.five_hour.used_percentage // empty | floor)",
      @sh "w_pct=\(.rate_limits.seven_day.used_percentage // empty | floor)",
      @sh "d_resets=\(.rate_limits.five_hour.resets_at // empty | floor)",
      @sh "w_resets=\(.rate_limits.seven_day.resets_at // empty | floor)",
      @sh "wt_orig=\(.worktree.original_cwd // "")"
    ' 2>/dev/null)"
  fi

  local dir="${project_dir:-$cwd}"

  # ---------- Segment 1: directory (~-abbreviated) ----------
  # Inside a Claude Code worktree show the project root, not the worktree
  # path. Prefer the .claude/worktrees/<name> layout (gives the exact root);
  # otherwise fall back to the payload's worktree.original_cwd, which also
  # covers hook-based worktrees living elsewhere.
  local is_worktree=0 dir_display="$dir"
  case "$dir" in
    */.claude/worktrees/*)
      is_worktree=1
      dir_display="${dir%%/.claude/worktrees/*}"
      ;;
    *)
      if [ -n "$wt_orig" ]; then
        is_worktree=1
        dir_display="$wt_orig"
      fi
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
  # rate_limits only arrives after the first API response of a session, so
  # keep the last values seen in ~/.claude/quota-cache.json and read them back
  # while the payload has none. A cached window is trusted until its
  # resets_at passes (or for an hour if no reset time was recorded).
  local quota_cache="$HOME/.claude/quota-cache.json"
  local now_epoch; now_epoch=$(date +%s 2>/dev/null || echo 0)

  if [ -n "$d_pct$w_pct" ]; then
    local tmp="$quota_cache.tmp.$$"
    printf '{"five_hour":%s,"seven_day":%s,"five_hour_resets":%s,"seven_day_resets":%s,"ts":%s}\n' \
      "${d_pct:-null}" "${w_pct:-null}" "${d_resets:-null}" "${w_resets:-null}" "$now_epoch" \
      > "$tmp" 2>/dev/null && mv -f "$tmp" "$quota_cache" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  elif [ "$have_jq" -eq 1 ] && [ -f "$quota_cache" ]; then
    local c_d="" c_w="" c_dr="" c_wr="" c_ts=0
    eval "$(jq -r '
      @sh "c_d=\(.five_hour // empty | numbers | floor)",
      @sh "c_w=\(.seven_day // empty | numbers | floor)",
      @sh "c_dr=\(.five_hour_resets // empty | numbers | floor)",
      @sh "c_wr=\(.seven_day_resets // empty | numbers | floor)",
      @sh "c_ts=\(.ts // 0 | numbers)"
    ' "$quota_cache" 2>/dev/null)"
    local fresh_until=$(( c_ts + 3600 ))
    if [ -n "$c_d" ] && [ "$now_epoch" -lt "${c_dr:-$fresh_until}" ]; then d_pct="$c_d"; fi
    if [ -n "$c_w" ] && [ "$now_epoch" -lt "${c_wr:-$fresh_until}" ]; then w_pct="$c_w"; fi
  fi

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

# `refresh-quota` was the pre-rate_limits subcommand; accept and ignore it so
# a stale caller (or an old cached copy kicking it in the background) is a no-op.
case "${1:-}" in
  refresh-quota) exit 0 ;;
  *)             render ;;
esac
