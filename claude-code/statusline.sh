#!/bin/bash
#
# Claude Code status line, tuned for AI-driven engineering.
#
#   ~/dev/my-project main +910 -198 3new
#   opus[1m] 211K/1M|5h 47% →00:00|7d 8%|1h33m(実作業 58m)
#
#   Line 1  cwd (under $HOME shown as ~, everything else absolute so WSL
#           /mnt/c/... stays recognisable) + git branch + diff vs the base
#           branch, counting committed + staged + unstaged + untracked work.
#   Line 2  model[context window], context used / total, the 5h & 7d rate
#           limits, and session elapsed time with idle time excluded.
#           Every number escalates green -> yellow -> orange -> bold red.
#
# Install: save this file, then in ~/.claude/settings.json
#   "statusLine": { "type": "command", "command": "bash \"$HOME/.claude/statusline.sh\"" }
#
# Requires: bash, git, awk, sed, grep, coreutils.
#   jq is optional but recommended - without it the script falls back to a
#   grep/sed JSON parser and the session-time segment is omitted (measuring it
#   means parsing the transcript JSONL, which needs a real JSON parser).
#
# See README.md for how each number is derived and why.

input=$(cat)

# ---- Tunables ----
# Thresholds (%) at which a number turns yellow / orange / bold red.
SL_WARN=${SL_WARN:-50}
SL_HIGH=${SL_HIGH:-75}
SL_CRIT=${SL_CRIT:-90}
# Label for the idle-excluded working time. Set to "active" for an English UI.
SL_ACTIVE_LABEL=${SL_ACTIVE_LABEL:-実作業}
# Max untracked files whose line counts are summed into the +N figure.
SL_UNTRACKED_SCAN=${SL_UNTRACKED_SCAN:-200}

# ---- Colors ----
RESET=$'\033[0m'
BOLD=$'\033[1m'
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
GREEN=$'\033[32m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
GRAY=$'\033[90m'
ORANGE=$'\033[38;5;208m'
BOLD_RED=$'\033[1;31m'

# ---- Minimal JSON helpers ----
# jstr <key> <text>  -> first string value for key
jstr() {
  printf '%s' "$2" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n1 |
    sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"$//"
}
# jnum <key> <text>  -> first numeric value for key
jnum() {
  printf '%s' "$2" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*-?[0-9]+(\.[0-9]+)?" | head -n1 |
    sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*//"
}
# slice_after <key> <text> -> everything from that key's value onward, so nested
# lookups (e.g. used_percentage, which also exists under rate_limits) stay scoped
slice_after() {
  case "$2" in
    *"\"$1\":"*) printf '%s' "${2#*\"$1\":}" ;;
    *) printf '%s' "$2" ;;
  esac
}

# format_num 986000 -> 986K ; 1000000 -> 1M ; 1500000 -> 1.5M
format_num() {
  awk -v n="$1" 'BEGIN{
    if (n=="" || n=="null") { printf "0"; exit }
    n=n+0
    if (n>=1000000) {
      v=n/1000000
      if (v==int(v)) printf "%dM", v; else printf "%.1fM", v
    } else if (n>=1000) {
      printf "%dK", int(n/1000+0.5)
    } else {
      printf "%d", n
    }
  }'
}

# fmt_dur <ms> -> 42s / 54m / 1h28m
fmt_dur() {
  awk -v ms="$1" 'BEGIN{
    s=int(ms/1000); if (s<0) s=0
    h=int(s/3600); m=int((s%3600)/60)
    if (h>0) printf "%dh%02dm", h, m
    else if (m>0) printf "%dm", m
    else printf "%ds", s
  }'
}

# pct_color <percent> -> escalate green -> yellow -> orange -> bold red
pct_color() {
  if   [ "${1:-0}" -ge "$SL_CRIT" ]; then printf '%s' "$BOLD_RED"
  elif [ "${1:-0}" -ge "$SL_HIGH" ]; then printf '%s' "$ORANGE"
  elif [ "${1:-0}" -ge "$SL_WARN" ]; then printf '%s' "$YELLOW"
  else                                    printf '%s' "$GREEN"
  fi
}

# ---- Extract fields (one jq call when available, grep/sed fallback otherwise) ----
cwd=""; model_id=""; window_size=""; used_tokens=""; used_pct=""
sess_id=""; transcript=""; rl5=""; rl5_reset=""; rl7=""; rl7_reset=""; effort_level=""
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1
if [ "$HAVE_JQ" -eq 1 ]; then
  # NOTE: deliberately not @tsv/IFS=$'\t' - bash's `read` collapses runs of IFS
  # *whitespace* (tab included) into one delimiter even when IFS is a single
  # tab, so any empty field (e.g. a blank session_id) shifts every field after
  # it left by one. \x1f (unit separator) is not whitespace, so `read` never
  # collapses it and empty fields round-trip correctly.
  IFS=$'\x1f' read -r cwd model_id window_size used_tokens used_pct \
                    sess_id transcript rl5 rl5_reset rl7 rl7_reset effort_level <<<"$(
    printf '%s' "$input" | jq -r '[
      (.workspace.current_dir // .cwd // ""),
      (.model.id // .model.display_name // ""),
      (.context_window.context_window_size // 0),
      (.context_window.total_input_tokens // 0),
      (.context_window.used_percentage // 0),
      (.session_id // ""),
      (.transcript_path // ""),
      (.rate_limits.five_hour.used_percentage // -1),
      (.rate_limits.five_hour.resets_at // 0),
      (.rate_limits.seven_day.used_percentage // -1),
      (.rate_limits.seven_day.resets_at // 0),
      (.effort.level // "")
    ] | join("")' 2>/dev/null
  )"
fi
if [ -z "$model_id" ]; then   # jq missing or failed -> parse without it
  cwd=$(jstr current_dir "$input"); [ -z "$cwd" ] && cwd=$(jstr cwd "$input")
  model_obj=$(slice_after model "$input")
  model_id=$(jstr id "$model_obj")
  [ -z "$model_id" ] && model_id=$(jstr display_name "$model_obj")
  ctx_obj=$(slice_after context_window "$input")
  window_size=$(jnum context_window_size "$ctx_obj")
  used_tokens=$(jnum total_input_tokens "$ctx_obj")
  used_pct=$(jnum used_percentage "$ctx_obj")
  sess_id=$(jstr session_id "$input")
  transcript=$(jstr transcript_path "$input")
  rl_obj=$(slice_after rate_limits "$input")
  h5=$(slice_after five_hour "$rl_obj"); rl5=$(jnum used_percentage "$h5"); rl5_reset=$(jnum resets_at "$h5")
  d7=$(slice_after seven_day "$rl_obj"); rl7=$(jnum used_percentage "$d7"); rl7_reset=$(jnum resets_at "$d7")
  effort_obj=$(slice_after effort "$input"); effort_level=$(jstr level "$effort_obj")
fi
[ -z "$model_id" ] && model_id="unknown"
: "${window_size:=0}" "${used_tokens:=0}" "${used_pct:=0}"

# ---- Rate-limit persistence ----
# The statusline payload doesn't always include `rate_limits` (it appears tied
# to recent API activity, not every redraw), which made the 5h/7d segments
# flicker in and out. Rate limits are account-wide, not per-session, so cache
# the last known value globally and fall back to it whenever the live payload
# omits the field. Each of 5h/7d is cached independently so a payload with
# only one of them doesn't clobber the other's cached value.
rl_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
mkdir -p "$rl_cache_dir" 2>/dev/null
rl5_cache="$rl_cache_dir/rate-limit-5h"
rl7_cache="$rl_cache_dir/rate-limit-7d"

if [ "${rl5:--1}" -ge 0 ] 2>/dev/null; then
  printf '%s %s\n' "$rl5" "${rl5_reset:-0}" > "$rl5_cache" 2>/dev/null
elif [ -f "$rl5_cache" ]; then
  read -r rl5 rl5_reset < "$rl5_cache" 2>/dev/null
fi

if [ "${rl7:--1}" -ge 0 ] 2>/dev/null; then
  printf '%s %s\n' "$rl7" "${rl7_reset:-0}" > "$rl7_cache" 2>/dev/null
elif [ -f "$rl7_cache" ]; then
  read -r rl7 rl7_reset < "$rl7_cache" 2>/dev/null
fi

# ================= Line 1: cwd + git =================
[ -z "$cwd" ] && cwd=$PWD

# Home -> ~ ; WSL Windows mounts (/mnt/c/...) and everything else stay absolute
case "$cwd" in
  "$HOME") display_path="~" ;;
  "$HOME"/*) display_path="~${cwd#"$HOME"}" ;;
  *) display_path="$cwd" ;;
esac

line1="${CYAN}${display_path}${RESET}"

if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    short=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    branch=${short:+detached@$short}
  fi
  [ -z "$branch" ] && branch="no-commits"

  # Base branch: origin/HEAD -> main -> master
  base_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [ -z "$base_branch" ]; then
    for b in main master; do
      git -C "$cwd" --no-optional-locks show-ref --verify --quiet "refs/heads/$b" 2>/dev/null && { base_branch=$b; break; }
    done
  fi

  diff_ref=""
  if [ -n "$base_branch" ] && [ "$branch" != "$base_branch" ]; then
    diff_ref=$(git -C "$cwd" --no-optional-locks merge-base "$base_branch" HEAD 2>/dev/null)
  fi
  # On the base branch (or no base found): fall back to HEAD => uncommitted changes only
  [ -z "$diff_ref" ] && diff_ref="HEAD"

  additions=0; deletions=0; new_files=0; del_files=0

  # numstat covers committed-since-base + staged + unstaged in one pass
  while IFS=$'\t' read -r a d _rest; do
    [ -z "$a" ] && continue
    [ "$a" = "-" ] && continue          # binary file
    additions=$((additions + a))
    deletions=$((deletions + d))
  done < <(git -C "$cwd" --no-optional-locks diff --numstat "$diff_ref" -- 2>/dev/null)

  while IFS= read -r st; do
    case "$st" in
      A*) new_files=$((new_files + 1)) ;;
      D*) del_files=$((del_files + 1)) ;;
    esac
  done < <(git -C "$cwd" --no-optional-locks diff --name-status "$diff_ref" -- 2>/dev/null)

  # Untracked files are uncommitted work too: count them, plus their lines (text only, capped)
  n=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    new_files=$((new_files + 1))
    n=$((n + 1))
    [ "$n" -gt "$SL_UNTRACKED_SCAN" ] && continue
    [ -f "$cwd/$f" ] || continue
    if grep -Iq . "$cwd/$f" 2>/dev/null; then
      lines=$(wc -l < "$cwd/$f" 2>/dev/null)
      additions=$((additions + ${lines:-0}))
    fi
  done < <(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null)

  git_part=" ${MAGENTA}${BOLD}${branch}${RESET}"
  if [ $((additions + deletions + new_files + del_files)) -gt 0 ]; then
    git_part="${git_part} ${GREEN}+${additions}${RESET} ${RED}-${deletions}${RESET}"
    [ "$new_files" -gt 0 ] && git_part="${git_part} ${BLUE}${new_files}new${RESET}"
    [ "$del_files" -gt 0 ] && git_part="${git_part} ${GRAY}${del_files}del${RESET}"
  fi
  line1="${line1}${git_part}"
fi

# ================= Line 2: model + context usage =================
model_name=${model_id%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]}   # drop -YYYYMMDD suffix
model_name=${model_name#claude-}                                   # drop claude- prefix
model_name=$(printf '%s' "$model_name" | sed -E 's/-[0-9].*$//')   # drop trailing version numbers (e.g. sonnet-4-5 -> sonnet)

used_pct_int=${used_pct%%.*}
[ -z "$used_pct_int" ] && used_pct_int=0

window_short=$(format_num "$window_size")
used_short=$(format_num "$used_tokens")
window_tag=$(printf '%s' "$window_short" | tr 'A-Z' 'a-z')

usage_color=$(pct_color "$used_pct_int")   # escalates toward the auto-compact threshold

effort_part=""
[ -n "$effort_level" ] && effort_part=" ${GRAY}${effort_level}${RESET}"

line2="${BOLD}${model_name}${RESET}${GRAY}[${window_tag}]${RESET}${effort_part} ${usage_color}${used_short}${RESET}${GRAY}/${RESET}${usage_color}${window_short}${RESET}"

# ---- Rate limits (5h / 7d) ----
rl_part=""
if [ "${rl5:--1}" -ge 0 ] 2>/dev/null; then
  c5=$(pct_color "$rl5")
  rl_part="${GRAY}|${RESET}${GRAY}5h${RESET} ${c5}${rl5}%${RESET}"
  if [ "${rl5_reset:-0}" -gt 0 ]; then
    r5=$(date -d "@$rl5_reset" '+%H:%M' 2>/dev/null)
    [ -n "$r5" ] && rl_part="${rl_part} ${GRAY}→${r5}${RESET}"
  fi
fi
if [ "${rl7:--1}" -ge 0 ] 2>/dev/null; then
  c7=$(pct_color "$rl7")
  rl_part="${rl_part}${GRAY}|${RESET}${GRAY}7d${RESET} ${c7}${rl7}%${RESET}"
fi
line2="${line2}${rl_part}"

# ---- Session elapsed / active (user prompt -> last assistant reply) ----
# Incremental: only transcript lines not seen before are parsed, state cached per session.
if [ "$HAVE_JQ" -eq 1 ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
  cache="$cache_dir/${sess_id:-unknown}.state"
  if [ ! -d "$cache_dir" ]; then
    mkdir -p "$cache_dir" 2>/dev/null
    # prune stale sessions once, when the cache dir is first created for this session
    find "$cache_dir" -maxdepth 1 -name '*.state' -mtime +7 -delete 2>/dev/null
  fi

  c_lines=0; c_t0=0; c_act=0; c_cu=0; c_ca=0
  [ -f "$cache" ] && read -r c_lines c_t0 c_act c_cu c_ca < "$cache" 2>/dev/null
  : "${c_lines:=0}" "${c_t0:=0}" "${c_act:=0}" "${c_cu:=0}" "${c_ca:=0}"

  total_lines=$(wc -l < "$transcript" 2>/dev/null)
  : "${total_lines:=0}"
  # transcript replaced/rotated -> rebuild from scratch
  [ "$total_lines" -lt "$c_lines" ] && { c_lines=0; c_t0=0; c_act=0; c_cu=0; c_ca=0; }

  if [ "$total_lines" -gt "$c_lines" ]; then
    # Emit "U|A|X <epoch_ms>" per new line, then fold into (t0, active, open turn).
    # U = human prompt (string content, not a tool_result); A = assistant reply.
    new_state=$(tail -n +$((c_lines + 1)) "$transcript" 2>/dev/null | head -n $((total_lines - c_lines)) |
      jq -Rr '
        (fromjson? // empty) as $e
        | ($e.timestamp // "") as $ts
        | select($ts != "")
        | ((($ts[0:19] + "Z") | fromdateiso8601) * 1000) as $m
        | if ($e.type == "user" and $e.isMeta != true and $e.isSidechain != true
               and ($e.message.content | type) == "string") then "U \($m)"
          elif ($e.type == "assistant" and $e.isSidechain != true) then "A \($m)"
          else "X \($m)" end
      ' 2>/dev/null |
      awk -v t0="$c_t0" -v act="$c_act" -v cu="$c_cu" -v ca="$c_ca" '
        { m = $2 + 0
          if (t0 == 0) t0 = m
          if ($1 == "U") {
            if (cu > 0 && ca > cu) act += ca - cu   # close the previous turn
            cu = m; ca = 0
          } else if ($1 == "A") {
            if (cu > 0 && m >= cu && m > ca) ca = m
          }
        }
        END { printf "%d %d %d %d", t0, act, cu, ca }
      ')
    if [ -n "$new_state" ]; then
      read -r c_t0 c_act c_cu c_ca <<<"$new_state"
      c_lines=$total_lines
      printf '%s %s %s %s %s\n' "$c_lines" "$c_t0" "$c_act" "$c_cu" "$c_ca" > "$cache" 2>/dev/null
    fi
  fi

  if [ "${c_t0:-0}" -gt 0 ]; then
    now_ms=$(( $(date +%s) * 1000 ))
    elapsed=$(( now_ms - c_t0 ))
    active=$c_act
    # include the turn still in flight
    [ "${c_ca:-0}" -gt "${c_cu:-0}" ] && active=$(( active + c_ca - c_cu ))
    line2="${line2}${GRAY}|${RESET}${CYAN}$(fmt_dur "$elapsed")${RESET}${GRAY}(${SL_ACTIVE_LABEL} ${RESET}${BOLD}$(fmt_dur "$active")${RESET}${GRAY})${RESET}"
  fi
fi

printf '%s\n%s' "$line1" "$line2"
