#!/usr/bin/env bash
# cc-promotion statusline — March 2026 doubled-usage promotion

# Read JSON from stdin
INPUT=$(cat)

# ── Parse session JSON with Python ─────────────────────────────────────────
read -r -d '' PYCODE << 'PYEOF'
import sys, json, math
from datetime import datetime, timezone, timedelta

data = json.loads(sys.argv[1]) if sys.argv[1:] else {}

# Version
version = data.get("version", "")
version_str = f"v{version}" if version else ""

# Model name
model_raw = (data.get("model") or {}).get("display_name", "")
if "Sonnet" in model_raw:
    model = "Sonnet 4.6"
elif "Opus" in model_raw:
    model = "Opus 4.6"
elif "Haiku" in model_raw:
    model = "Haiku 4.5"
else:
    model = model_raw or "Claude"

# Context bar
ctx_pct = int((data.get("context_window") or {}).get("used_percentage") or 0)

# Cost
cost_obj = data.get("cost") or {}
cost_val = cost_obj.get("total_cost_usd")
cost = f"${cost_val:.3f}" if cost_val and cost_val > 0 else ""

# Session lines edited by Claude
sess_added   = int(cost_obj.get("total_lines_added") or 0)
sess_removed = int(cost_obj.get("total_lines_removed") or 0)

# Session duration
duration_ms = cost_obj.get("total_duration_ms") or 0
duration_s  = int(duration_ms / 1000)
if duration_s >= 3600:
    duration_str = f"{duration_s // 3600}h{(duration_s % 3600) // 60}m"
elif duration_s >= 60:
    duration_str = f"{duration_s // 60}m{duration_s % 60}s"
elif duration_s > 0:
    duration_str = f"{duration_s}s"
else:
    duration_str = ""

# Vim mode
vim_mode = (data.get("vim") or {}).get("mode", "")

# ── Promotion time logic ────────────────────────────────────────────────────
PROMO_END_UTC = datetime(2026, 3, 28, 6, 59, 59, tzinfo=timezone.utc)
PEAK_START_H  = 12   # 8 AM EDT = UTC-4
PEAK_END_H    = 18   # 2 PM EDT = UTC-4

now_utc   = datetime.now(timezone.utc)
now_local = datetime.now()
clock     = now_local.strftime("%H:%M")

in_promo   = now_utc < PROMO_END_UTC
is_weekend = now_utc.weekday() >= 5
in_peak    = (not is_weekend) and (PEAK_START_H <= now_utc.hour < PEAK_END_H)

if not in_promo:
    promo_mode  = "OFF"
    promo_next  = ""
    promo_days  = "0"
else:
    days_left = max(0, (PROMO_END_UTC.date() - now_utc.date()).days)
    promo_days = str(days_left)

    if is_weekend:
        promo_mode = "2X"
        days_to_mon = (7 - now_utc.weekday()) % 7 or 7
        next_utc = (now_utc + timedelta(days=days_to_mon)).replace(
            hour=PEAK_START_H, minute=0, second=0, microsecond=0)
    elif in_peak:
        promo_mode = "PEAK"
        next_utc = now_utc.replace(hour=PEAK_END_H, minute=0, second=0, microsecond=0)
        if next_utc <= now_utc:
            next_utc += timedelta(days=1)
    else:
        promo_mode = "2X"
        next_utc = now_utc.replace(hour=PEAK_START_H, minute=0, second=0, microsecond=0)
        if next_utc <= now_utc:
            next_utc += timedelta(days=1)
        while next_utc.weekday() >= 5:
            next_utc += timedelta(days=1)

    local_offset = now_local - now_utc.replace(tzinfo=None)
    next_local   = (next_utc.replace(tzinfo=None) + local_offset).strftime("%H:%M")
    promo_next   = next_local

print(f"VERSION='{version_str}'")
print(f"MODEL='{model}'")
print(f"CTX_PCT={ctx_pct}")
print(f"COST='{cost}'")
print(f"SESS_ADDED={sess_added}")
print(f"SESS_REMOVED={sess_removed}")
print(f"DURATION='{duration_str}'")
print(f"VIM_MODE='{vim_mode}'")
print(f"CLOCK='{clock}'")
print(f"PROMO_MODE='{promo_mode}'")
print(f"PROMO_NEXT='{promo_next}'")
print(f"PROMO_DAYS='{promo_days}'")
PYEOF

# Run Python, parse key=value output
eval "$(python3 -c "$PYCODE" "$INPUT" 2>/dev/null)"

# ── Build context bar ───────────────────────────────────────────────────────
build_bar() {
    local pct=$1
    local filled=$(( pct * 10 / 100 ))
    local bar=""
    for ((i=0; i<10; i++)); do
        if (( i < filled )); then
            bar="${bar}▓"
        else
            bar="${bar}░"
        fi
    done
    echo "$bar"
}

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'
CYAN='\033[36m'
PURPLE='\033[35m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Line 1 components ────────────────────────────────────────────────────────

# Model + version
if [[ -n "$VERSION" ]]; then
    model_str="${CYAN}[${MODEL}]${GRAY}·${VERSION}${RESET}"
else
    model_str="${CYAN}[${MODEL}]${RESET}"
fi

# Vim mode badge (before context bar if active)
if [[ "$VIM_MODE" == "NORMAL" ]]; then
    vim_str="${YELLOW}${BOLD} N ${RESET}"
elif [[ "$VIM_MODE" == "INSERT" ]]; then
    vim_str="${GREEN}${BOLD} I ${RESET}"
else
    vim_str=""
fi

# Context bar
CTX_PCT=${CTX_PCT:-0}
BAR=$(build_bar "$CTX_PCT")
if (( CTX_PCT < 50 )); then
    bar_color="$GREEN"
elif (( CTX_PCT < 80 )); then
    bar_color="$YELLOW"
else
    bar_color="$RED"
fi
ctx_str="${bar_color}${BAR}${RESET} ${CTX_PCT}%"

# Cost
[[ -n "$COST" ]] && cost_str="${GRAY}${COST}${RESET}" || cost_str=""

# Clock
clock_str="🕐 ${CLOCK}"

# Promo
case "$PROMO_MODE" in
    2X)   promo_str="${GREEN}${BOLD}⚡ 2× ON 🟢 →${PROMO_NEXT} · ${PROMO_DAYS}d left${RESET}" ;;
    PEAK) promo_str="${GRAY}⏸ 1× OFF 🔴 peak until ${PROMO_NEXT} · ${PROMO_DAYS}d left${RESET}" ;;
    *)    promo_str="" ;;
esac

# ── Line 2 components ────────────────────────────────────────────────────────

# Git branch + working-tree diff
git_branch=$(git branch --show-current 2>/dev/null)
if [[ -n "$git_branch" ]]; then
    git_added=$(git diff --numstat HEAD 2>/dev/null | awk '{a+=$1} END {print a+0}')
    git_removed=$(git diff --numstat HEAD 2>/dev/null | awk '{a+=$2} END {print a+0}')
    branch_str="${PURPLE}🌿 ${git_branch}${RESET}"
    if (( git_added > 0 || git_removed > 0 )); then
        branch_str="${branch_str}  ${GREEN}+${git_added}${RESET} ${RED}-${git_removed}${RESET}"
    fi
else
    branch_str="${GRAY}🌿 none${RESET}"
fi

# Session lines edited by Claude
if (( SESS_ADDED > 0 || SESS_REMOVED > 0 )); then
    sess_str="${GRAY}✍️  session ${GREEN}+${SESS_ADDED}${RESET}${GRAY}/${RED}-${SESS_REMOVED}${RESET}"
else
    sess_str=""
fi

# Session duration
[[ -n "$DURATION" ]] && dur_str="${GRAY}⏱ ${DURATION}${RESET}" || dur_str=""

# ── Assemble ─────────────────────────────────────────────────────────────────
line1="${model_str}"
[[ -n "$vim_str" ]] && line1="${line1} ${vim_str}"
line1="${line1} ${ctx_str}"
[[ -n "$cost_str" ]] && line1="${line1} | ${cost_str}"
line1="${line1} | ${clock_str}"
[[ -n "$promo_str" ]] && line1="${line1} | ${promo_str}"

line2="${branch_str}"
[[ -n "$sess_str" ]] && line2="${line2}  ${sess_str}"
[[ -n "$dur_str"  ]] && line2="${line2}  ${dur_str}"

printf "%b\n" "$line1"
printf "%b\n" "$line2"
