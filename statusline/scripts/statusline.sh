#!/usr/bin/env bash
# Claude Code statusLine — one file, no siblings, no network.
#
# Reads the statusLine JSON Claude Code passes on stdin
# (https://code.claude.com/docs/en/statusline) and renders, left to right:
#   <project dir (~-abbreviated)> [(worktree)] │ <git branch> │
#   [context bar] │ [5-hour bar] │ [weekly bar] │ <model> [effort] [fast]
#
# The only thing touched on disk is ~/.claude/quota-cache.json: a copy of the
# last `rate_limits` seen, so the quota bars are populated from the first
# prompt of a new session instead of waiting for its first API response.
#
# Installed by the "statusline" plugin (danielbodart/claude-code-plugins).

# ANSI escapes as real bytes (safe to print with %s). Globals so both the
# renderer and make_bar can see them.
esc=$'\033'; reset="${esc}[0m"; dim="${esc}[2m"
cyan="${esc}[36m"; green="${esc}[92m"; yellow="${esc}[33m"; red="${esc}[31m"; magenta="${esc}[38;5;141m"
sep=" ${dim}│${reset} "

# ---------- Helper: render a labelled percentage bar ----------
# usage: make_bar LABEL PCT DEFAULT_COLOR   (echoes the coloured segment)
# PCT empty -> greyed-out placeholder. Colour ramps green<50<yellow<80<red,
# unless a fixed DEFAULT_COLOR is passed for the <50 band.
make_bar() {
  local label="$1" p="$2" base="${3:-$green}" w=5
  if [ -z "$p" ]; then
    printf '%s' "${dim}${label} □□□□□ --%${reset}"
    return
  fi
  [ "$p" -gt 100 ] 2>/dev/null && p=100
  [ "$p" -lt 0 ] 2>/dev/null && p=0
  local filled=$(( p * w / 100 )) c
  local e=$(( w - filled ))
  if   [ "$p" -ge 80 ]; then c="$red"
  elif [ "$p" -ge 50 ]; then c="$yellow"
  else c="$base"; fi
  local fs="" es="" i=0
  while [ "$i" -lt "$filled" ]; do fs="${fs}■"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$e" ]; do es="${es}□"; i=$((i+1)); done
  printf '%s' "${c}${label} ${fs}${dim}${es}${c} ${p}%${reset}"
}

# =============================== renderer ===================================
render() {
  local input; input=$(cat 2>/dev/null)
  command -v jq >/dev/null 2>&1 || { printf '%s\n' "${dim}statusline: jq not found${reset}"; return; }

  # One jq pass pulls every field we use. A field that is absent or null
  # leaves its variable empty: an empty interpolation drops the whole @sh line.
  #   context_window.used_percentage — what /context shows, against the real
  #                                    window size for the current model.
  #   rate_limits.*                  — subscription 5-hour / 7-day usage, 0–100.
  #                                    Pro/Max only, only after the session's
  #                                    first API response; a window vanishes
  #                                    once it resets.
  #   worktree.*                     — present only inside a worktree session.
  #   effort.level / fast_mode       — live /effort and /fast state.
  local project_dir="" cwd="" model_name="" ctx_pct="" effort="" fast_mode=""
  local d_pct="" w_pct="" d_resets="" w_resets="" wt_orig=""
  [ -n "$input" ] && eval "$(printf '%s' "$input" | jq -r '
    @sh "project_dir=\(.workspace.project_dir // "")",
    @sh "cwd=\(.cwd // "")",
    @sh "model_name=\(.model.display_name // "")",
    @sh "ctx_pct=\(.context_window.used_percentage // empty | floor)",
    @sh "d_pct=\(.rate_limits.five_hour.used_percentage // empty | floor)",
    @sh "w_pct=\(.rate_limits.seven_day.used_percentage // empty | floor)",
    @sh "d_resets=\(.rate_limits.five_hour.resets_at // empty | floor)",
    @sh "w_resets=\(.rate_limits.seven_day.resets_at // empty | floor)",
    @sh "wt_orig=\(.worktree.original_cwd // "")",
    @sh "effort=\(.effort.level // "")",
    @sh "fast_mode=\(.fast_mode // false)"
  ' 2>/dev/null)"

  local dir="${project_dir:-$cwd}"

  # ---------- Segment 1: directory (~-abbreviated) ----------
  # Inside a worktree session show where the user came from, not the worktree.
  local is_worktree=0 dir_display="$dir"
  if [ -n "$wt_orig" ]; then
    is_worktree=1
    dir_display="$wt_orig"
  fi
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
  [ "$is_worktree" -eq 1 ] && branch="${branch#worktree-}"

  # ---------- Segment 3: context usage bar ----------
  local ctx_bar; ctx_bar=$(make_bar "ctx" "$ctx_pct" "$green")

  # ---------- Segment 4: subscription quota (5h = 5-hour, 7d = weekly) ----------
  # Persist rate_limits when present; otherwise read the last values back,
  # trusting each window until its resets_at passes.
  local quota_cache="$HOME/.claude/quota-cache.json"
  local now_epoch; now_epoch=$(date +%s)

  if [ -n "$d_pct$w_pct" ]; then
    local tmp="$quota_cache.tmp.$$"
    printf '{"five_hour":%s,"seven_day":%s,"five_hour_resets":%s,"seven_day_resets":%s}\n' \
      "${d_pct:-null}" "${w_pct:-null}" "${d_resets:-null}" "${w_resets:-null}" \
      > "$tmp" 2>/dev/null && mv -f "$tmp" "$quota_cache" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  elif [ -f "$quota_cache" ]; then
    local c_d="" c_w="" c_dr=0 c_wr=0
    eval "$(jq -r '
      @sh "c_d=\(.five_hour // empty)",
      @sh "c_w=\(.seven_day // empty)",
      @sh "c_dr=\(.five_hour_resets // 0)",
      @sh "c_wr=\(.seven_day_resets // 0)"
    ' "$quota_cache" 2>/dev/null)"
    [ -n "$c_d" ] && [ "$now_epoch" -lt "$c_dr" ] 2>/dev/null && d_pct="$c_d"
    [ -n "$c_w" ] && [ "$now_epoch" -lt "$c_wr" ] 2>/dev/null && w_pct="$c_w"
  fi

  local d_bar w_bar
  d_bar=$(make_bar "5h" "$d_pct" "$cyan")
  w_bar=$(make_bar "7d" "$w_pct" "$magenta")

  # ---------- Segment 5: model, effort level, fast mode ----------
  [ -z "$model_name" ] && model_name="?"
  local model_seg="${magenta}${model_name}${reset}"
  [ -n "$effort" ] && model_seg="${model_seg} ${dim}${effort}${reset}"
  [ "$fast_mode" = "true" ] && model_seg="${model_seg} ${yellow}fast${reset}"

  # ---------- Assemble (printf %s: no format-string interpretation of % or bytes) ----------
  local out="${cyan}${dir_display}${reset}"
  [ "$is_worktree" -eq 1 ] && out="${out} ${dim}(worktree)${reset}"
  [ -n "$branch" ] && out="${out}${sep}${green}${branch}${reset}"
  out="${out}${sep}${ctx_bar}${sep}${d_bar}${sep}${w_bar}${sep}${model_seg}"
  printf '%s\n' "$out"
}

render
