#!/usr/bin/env bash
# cc-promotion statusline — March 2026 doubled-usage promotion

# Read JSON from stdin
INPUT=$(cat)

# ── Parse session JSON with Python ─────────────────────────────────────────
read -r -d '' PYCODE << 'PYEOF'
import sys, json, math
from datetime import datetime, timezone, timedelta

data = json.loads(sys.argv[1]) if sys.argv[1:] else {}

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
cost_val = (data.get("cost") or {}).get("total_cost_usd")
if cost_val and cost_val > 0:
    cost = f"${cost_val:.3f}"
else:
    cost = ""

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
        # Next transition: Monday 12:00 UTC
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
        # Skip weekends
        while next_utc.weekday() >= 5:
            next_utc += timedelta(days=1)

    local_offset = now_local - now_utc.replace(tzinfo=None)
    next_local   = (next_utc.replace(tzinfo=None) + local_offset).strftime("%H:%M")
    promo_next   = next_local

print(f"MODEL='{model}'")
print(f"CTX_PCT={ctx_pct}")
print(f"COST='{cost}'")
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
BOLD='\033[1m'
RESET='\033[0m'

# ── Format each component ───────────────────────────────────────────────────
# Model
model_str="${CYAN}[${MODEL}]${RESET}"

# Context bar with color based on percentage
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

# Cost (hidden if empty)
if [[ -n "$COST" ]]; then
    cost_str="${GRAY}${COST}${RESET}"
else
    cost_str=""
fi

# Clock
clock_str="🕐 ${CLOCK}"

# Promo segment
case "$PROMO_MODE" in
    2X)
        promo_str="${GREEN}${BOLD}⚡ 2× ON 🟢 →${PROMO_NEXT} · ${PROMO_DAYS}d left${RESET}"
        ;;
    PEAK)
        promo_str="${GRAY}⏸ 1× OFF 🔴 peak until ${PROMO_NEXT} · ${PROMO_DAYS}d left${RESET}"
        ;;
    OFF|*)
        promo_str=""
        ;;
esac

# ── Git info (line 2) ────────────────────────────────────────────────────────
PURPLE='\033[35m'

git_branch=$(git branch --show-current 2>/dev/null)
if [[ -n "$git_branch" ]]; then
    # Staged + unstaged diff stats combined
    added=$(git diff --numstat HEAD 2>/dev/null | awk '{a+=$1} END {print a+0}')
    removed=$(git diff --numstat HEAD 2>/dev/null | awk '{a+=$2} END {print a+0}')

    branch_str="${PURPLE} ${git_branch}${RESET}"
    if (( added > 0 || removed > 0 )); then
        diff_str="${GREEN}+${added}${RESET} ${RED}-${removed}${RESET}"
        git_line="${branch_str}  ${diff_str}"
    else
        git_line="${branch_str}"
    fi
else
    git_line=""
fi

# ── Assemble line ───────────────────────────────────────────────────────────
line="${model_str} ${ctx_str}"
[[ -n "$cost_str" ]] && line="${line} | ${cost_str}"
line="${line} | ${clock_str}"
[[ -n "$promo_str" ]] && line="${line} | ${promo_str}"

printf "%b\n" "$line"
[[ -n "$git_line" ]] && printf "%b\n" "$git_line"
