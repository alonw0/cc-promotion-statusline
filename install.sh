#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/alonw0/cc-promotion-statusline/main"
INSTALL_DIR="$HOME/.claude/cc-promotion"
SCRIPT_PATH="$INSTALL_DIR/statusline.sh"
BACKUP_FILE="$INSTALL_DIR/statusline-backup.json"
SETTINGS="$HOME/.claude/settings.json"

echo "── cc-promotion statusline installer ──"

# Download script
mkdir -p "$INSTALL_DIR"
echo "→ Downloading statusline.sh to $INSTALL_DIR"
curl -fsSL "$REPO_URL/statusline.sh" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# Update settings.json
if [[ ! -f "$SETTINGS" ]]; then
    echo "→ Creating $SETTINGS"
    echo '{}' > "$SETTINGS"
fi

echo "→ Updating $SETTINGS"
python3 - "$SETTINGS" "$SCRIPT_PATH" "$BACKUP_FILE" << 'PYEOF'
import sys, json

settings_path = sys.argv[1]
script_path   = sys.argv[2]
backup_file   = sys.argv[3]

with open(settings_path) as f:
    settings = json.load(f)

# Save existing statusLine to a dedicated backup file
existing = settings.get("statusLine")
if existing and existing.get("command") != f"bash {script_path}":
    with open(backup_file, "w") as f:
        json.dump(existing, f, indent=2)
    print(f"  (backed up previous statusLine to {backup_file})")
elif not existing:
    # Write a sentinel so uninstall knows there was nothing to restore
    with open(backup_file, "w") as f:
        json.dump(None, f)

settings["statusLine"] = {
    "type": "command",
    "command": f"bash {script_path}"
}

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF

echo ""
echo "✓ Installed! Reload Claude Code to see the statusline."
echo "  Script:  $SCRIPT_PATH"
echo "  Backup:  $BACKUP_FILE"
echo "  To uninstall: bash $INSTALL_DIR/uninstall.sh"
