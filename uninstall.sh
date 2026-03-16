#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.claude/cc-promotion"
BACKUP_FILE="$INSTALL_DIR/statusline-backup.json"
SETTINGS="$HOME/.claude/settings.json"

echo "── cc-promotion statusline uninstaller ──"

# Restore settings.json from backup file before removing the directory
if [[ -f "$SETTINGS" ]]; then
    echo "→ Restoring $SETTINGS"
    python3 - "$SETTINGS" "${BACKUP_FILE:-}" << 'PYEOF'
import sys, json, os

settings_path = sys.argv[1]
backup_file   = sys.argv[2] if len(sys.argv) > 2 else ""

with open(settings_path) as f:
    settings = json.load(f)

restored = False
if backup_file and os.path.exists(backup_file):
    with open(backup_file) as f:
        backup = json.load(f)
    if backup is not None:
        settings["statusLine"] = backup
        print(f"  (restored previous statusLine from backup)")
        restored = True

if not restored:
    settings.pop("statusLine", None)
    print(f"  (no backup found — removed statusLine)")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF
fi

# Remove installed files
if [[ -d "$INSTALL_DIR" ]]; then
    echo "→ Removing $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

echo ""
echo "✓ Uninstalled. Reload Claude Code to apply."
