# cc-promotion statusline

A Claude Code statusline for the **March 2026 doubled-usage promotion** — shows whether you're currently getting 2× usage or not, plus useful session info.

![statusline preview](https://github.com/user-attachments/assets/c767694a-2024-4075-9d19-d454ef470bc3)

```
[Sonnet 4.6]·v1.2.0  ▓▓░░░░░░░░ 23% | $0.042 | 🕐 21:14 | ⚡ 2× ON 🟢 →00:00 · 12d left
🌿 main  +12 -3  ✍️  session +87/-34  ⏱ 3m3s
```

---

## Install

### One-liner (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/alonw0/cc-promotion-statusline/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/alonw0/cc-promotion-statusline ~/.claude/cc-promotion
bash ~/.claude/cc-promotion/install.sh
```

Reload Claude Code after installing.

---

## Uninstall

```bash
bash ~/.claude/cc-promotion/uninstall.sh
```

Restores your previous `statusLine` setting if one existed.

---

## What it shows

### Line 1
| Component | Description |
|-----------|-------------|
| `[Model]·vX.Y.Z` | Current model + Claude Code version |
| `▓░░ N%` | Context window usage bar (green → yellow → red) |
| `$N.NNN` | Session cost (hidden if zero) |
| `🕐 HH:MM` | Current local time |
| `⚡ 2× ON 🟢 →HH:MM · Xd left` | Off-peak — doubled usage active |
| `⏸ 1× OFF 🔴 peak until HH:MM · Xd left` | Peak hours — normal usage |

### Line 2
| Component | Description |
|-----------|-------------|
| `🌿 branch` | Git branch + working-tree `+added/-removed` lines |
| `🌿 none` | Not a git repo |
| `✍️  session +X/-Y` | Lines added/removed by Claude this session |
| `⏱ Xm Ys` | Session uptime |

---

## Promotion rules

- **Active:** March 13–27, 2026
- **Weekdays (Mon–Fri):** 2× all hours **except** 8 AM–2 PM EDT (12:00–18:00 UTC)
- **Weekends (Sat–Sun):** 2× all day

After March 27 the promo segment disappears and the statusline shows session info only.

---

## Requirements

- macOS or Linux
- `bash` + `python3` (standard on both)
- Claude Code with statusline support
