#!/usr/bin/env bash
# cc-promotion statusline — March 2026 doubled-usage promotion
# Cross-platform (Windows/Linux/macOS) with timezone-aware promo tracking

INPUT=$(cat)

PY=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PY" ]; then echo "2x promo | python not found"; exit 0; fi

eval "$("$PY" - "$INPUT" << 'PYEOF'
import sys, json
from datetime import datetime, timezone, timedelta

data = json.loads(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].strip() else {}

version = data.get("version", "")
print(f"VERSION='v{version}'" if version else "VERSION=''")

model_raw = (data.get("model") or {}).get("display_name", "")
model = "Sonnet 4.6" if "Sonnet" in model_raw else "Opus 4.6" if "Opus" in model_raw else "Haiku 4.5" if "Haiku" in model_raw else model_raw or "Claude"
print(f"MODEL='{model}'")

ctx_pct = int((data.get("context_window") or {}).get("used_percentage") or 0)
print(f"CTX_PCT={ctx_pct}")

cost_obj = data.get("cost") or {}
cost_val = cost_obj.get("total_cost_usd")
print(f"COST='${cost_val:.3f}'" if cost_val and cost_val > 0 else "COST=''")
print(f"SESS_ADDED={int(cost_obj.get('total_lines_added') or 0)}")
print(f"SESS_REMOVED={int(cost_obj.get('total_lines_removed') or 0)}")

ds = int((cost_obj.get("total_duration_ms") or 0) / 1000)
dur = f"{ds//3600}h{(ds%3600)//60}m" if ds >= 3600 else f"{ds//60}m{ds%60}s" if ds >= 60 else f"{ds}s" if ds > 0 else ""
print(f"DURATION='{dur}'")

vim_mode = (data.get("vim") or {}).get("mode", "")
print(f"VIM_MODE='{vim_mode}'")

# ── Timezone-aware promo logic (all in UTC) ──
now = datetime.now(timezone.utc)
PROMO_END = datetime(2026, 3, 28, 7, 0, 0, tzinfo=timezone.utc)
PEAK_S, PEAK_E = 12, 18  # 8AM-2PM EDT in UTC

# Israel display time (auto DST: Mar 27+ = UTC+3, else UTC+2)
m, d = now.month, now.day
il_off = 3 if (m > 3 or (m == 3 and d >= 27)) and (m < 10 or (m == 10 and d < 25)) else 2
il = now + timedelta(hours=il_off)
print(f"IL_TIME='{il.strftime('%H:%M')}'")

in_promo = now < PROMO_END and int(now.strftime('%Y%m%d')) >= 20260313
is_wknd = now.weekday() >= 5
in_peak = (not is_wknd) and (PEAK_S <= now.hour < PEAK_E)

mode, ml = "OFF", 0
if in_promo:
    days_left = max(0, (PROMO_END.date() - now.date()).days)
    if is_wknd:
        mode = "2X"
        dtm = (7 - now.weekday()) % 7 or 7
        nxt = (now + timedelta(days=dtm)).replace(hour=PEAK_S, minute=0, second=0, microsecond=0)
        ml = int((nxt - now).total_seconds() / 60)
    elif in_peak:
        mode = "PEAK"
        nxt = now.replace(hour=PEAK_E, minute=0, second=0, microsecond=0)
        if nxt <= now: nxt += timedelta(days=1)
        ml = int((nxt - now).total_seconds() / 60)
    else:
        mode = "2X"
        nxt = now.replace(hour=PEAK_S, minute=0, second=0, microsecond=0)
        if nxt <= now: nxt += timedelta(days=1)
        while nxt.weekday() >= 5: nxt += timedelta(days=1)
        ml = int((nxt - now).total_seconds() / 60)
else:
    days_left = 0

h, rm = divmod(ml, 60)
fmt = f"{h}h {rm:02d}m" if h > 0 else f"{rm}m"

if mode == "2X":
    bg = "38;5;16;48;5;46" if ml > 180 else "38;5;16;48;5;220" if ml > 60 else "38;5;255;48;5;124"
else:
    bg = "2;48;5;236"

print(f"PROMO_MODE='{mode}'")
print(f"PROMO_FMT='{fmt}'")
print(f"PROMO_DAYS='{days_left}'")
print(f"PROMO_BG='{bg}'")
PYEOF
)"

# ── Context bar ──
build_bar() {
    local pct=$1 filled=$(( pct * 10 / 100 )) bar=""
    for ((i=0; i<10; i++)); do
        (( i < filled )) && bar="${bar}▓" || bar="${bar}░"
    done
    echo "$bar"
}

# ── Colors ──
GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; GRAY='\033[90m'
CYAN='\033[36m'; PURPLE='\033[35m'; BOLD='\033[1m'; DIM='\033[2m'; RST='\033[0m'

# ── Line 1 ──
[[ -n "$VERSION" ]] && ms="${CYAN}[${MODEL}]${GRAY}·${VERSION}${RST}" || ms="${CYAN}[${MODEL}]${RST}"
vs=""
[[ "$VIM_MODE" == "NORMAL" ]] && vs="${YELLOW}${BOLD} N ${RST}"
[[ "$VIM_MODE" == "INSERT" ]] && vs="${GREEN}${BOLD} I ${RST}"

CTX_PCT=${CTX_PCT:-0}
BAR=$(build_bar "$CTX_PCT")
(( CTX_PCT < 50 )) && bc="$GREEN" || { (( CTX_PCT < 80 )) && bc="$YELLOW" || bc="$RED"; }
cs="${bc}${BAR}${RST} ${CTX_PCT}%"
[[ -n "$COST" ]] && co="${GRAY}${COST}${RST}" || co=""
cl="${DIM}${IL_TIME}${RST}"

case "$PROMO_MODE" in
    2X)   ps="\033[${PROMO_BG}m${BOLD} 2x ACTIVE \033[0m \033[${PROMO_BG}m ${PROMO_FMT} left \033[0m ${GRAY}${PROMO_DAYS}d${RST}" ;;
    PEAK) ps="\033[${PROMO_BG}m PEAK \033[0m \033[38;5;87m2x returns in ${PROMO_FMT}\033[0m ${GRAY}${PROMO_DAYS}d${RST}" ;;
    *)    ps="" ;;
esac

# ── Line 2 ──
gb=$(git branch --show-current 2>/dev/null)
bs=""
if [[ -n "$gb" ]]; then
    ga=$(git diff --numstat HEAD 2>/dev/null | awk '{a+=$1}END{print a+0}')
    gr=$(git diff --numstat HEAD 2>/dev/null | awk '{a+=$2}END{print a+0}')
    bs="${PURPLE}${gb}${RST}"
    (( ga > 0 || gr > 0 )) && bs="${bs}  ${GREEN}+${ga}${RST} ${RED}-${gr}${RST}"
fi
(( SESS_ADDED > 0 || SESS_REMOVED > 0 )) && ss="${GRAY}session ${GREEN}+${SESS_ADDED}${RST}${GRAY}/${RED}-${SESS_REMOVED}${RST}" || ss=""
[[ -n "$DURATION" ]] && ds="${GRAY}${DURATION}${RST}" || ds=""

# ── Output ──
L1="${ms}"
[[ -n "$vs" ]] && L1="${L1} ${vs}"
L1="${L1} ${cs}"
[[ -n "$co" ]] && L1="${L1} | ${co}"
L1="${L1} | ${cl}"
[[ -n "$ps" ]] && L1="${L1} | ${ps}"
L2="${bs}"
[[ -n "$ss" ]] && L2="${L2}  ${ss}"
[[ -n "$ds" ]] && L2="${L2}  ${ds}"
printf "%b\n" "$L1"
[[ -n "$L2" ]] && printf "%b\n" "$L2"
