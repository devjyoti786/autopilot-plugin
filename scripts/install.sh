#!/bin/bash
# Claude Code Autopilot Plugin — Install Script
# Runs on plugin install via: claude plugin install

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
STATUSLINE_CMD="bash $PLUGIN_DIR/scripts/autopilot-statusline.sh"

echo "Installing Claude Code Autopilot plugin..."

# 1. Create required directories
mkdir -p "$HOME/.claude/autopilot-backups"
mkdir -p "$HOME/.claude/autopilot-sessions"

# 2. Initialize state file if it doesn't exist
STATE="$HOME/.claude/autopilot-state.json"
if [ ! -f "$STATE" ]; then
    echo '{"mode":"off"}' > "$STATE"
fi

# 3. Patch statusLine in settings.json
if [ -f "$SETTINGS" ]; then
    python3 - "$SETTINGS" "$STATUSLINE_CMD" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
new_cmd = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

existing = settings.get("statusLine", {}).get("command", "")

if new_cmd in existing:
    print("statusLine already patched, skipping.")
elif existing:
    settings["statusLine"]["command"] = existing + " && " + new_cmd
    print(f"Appended autopilot to existing statusLine.")
else:
    settings["statusLine"] = {"type": "command", "command": new_cmd}
    print("Set autopilot as statusLine command.")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
else
    echo "Warning: $SETTINGS not found. StatusLine not patched."
fi

# 4. Make all scripts executable
chmod +x "$PLUGIN_DIR/scripts/"*.sh
chmod +x "$PLUGIN_DIR/hooks/"*.sh

echo "✓ Autopilot plugin installed."
echo "  Use /autopilot [strict|normal|yolo] to activate."
echo "  Use /autopilot-help for full documentation."
