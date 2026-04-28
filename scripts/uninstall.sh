#!/bin/bash
# Claude Code Autopilot Plugin — Uninstall Script

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$HOME/.claude/settings.json"
STATUSLINE_CMD="bash $PLUGIN_DIR/scripts/autopilot-statusline.sh"

echo "Uninstalling Claude Code Autopilot plugin..."

# 1. Deactivate autopilot if active
STATE="$HOME/.claude/autopilot-state.json"
if [ -f "$STATE" ]; then
    MODE=$(python3 -c "import json; d=json.load(open('$STATE')); print(d.get('mode','off'))" 2>/dev/null)
    if [ "$MODE" != "off" ]; then
        echo "Warning: Autopilot is currently active (mode: $MODE). Deactivating..."
        BACKUP=$(python3 -c "import json; d=json.load(open('$STATE')); print(d.get('backupPath',''))" 2>/dev/null)
        if [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then
            echo "Backup exists at: $BACKUP — NOT deleted. You may restore manually."
        fi
    fi
    echo '{"mode":"off"}' > "$STATE"
fi

# 2. Ask about saved sudo password
SUDO_CONF="$HOME/.claude/autopilot-sudo.conf"
if [ -f "$SUDO_CONF" ]; then
    read -rp "Delete saved sudo password (~/.claude/autopilot-sudo.conf)? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -f "$SUDO_CONF"
        echo "Sudo password deleted."
    else
        echo "Sudo password kept at $SUDO_CONF"
    fi
fi

# 3. Remove statusLine patch from settings.json
if [ -f "$SETTINGS" ]; then
    python3 - "$SETTINGS" "$STATUSLINE_CMD" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
cmd_to_remove = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

existing = settings.get("statusLine", {}).get("command", "")

if cmd_to_remove in existing:
    cleaned = existing.replace(" && " + cmd_to_remove, "").replace(cmd_to_remove + " && ", "").replace(cmd_to_remove, "").strip()
    if cleaned:
        settings["statusLine"]["command"] = cleaned
    else:
        del settings["statusLine"]
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("Removed autopilot statusLine component.")
else:
    print("StatusLine not patched, nothing to remove.")
PYEOF
fi

# 4. Remove autopilot-logger hook from settings.json
if [ -f "$SETTINGS" ]; then
    python3 - "$SETTINGS" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
post = hooks.get("PostToolUse", [])
filtered = [
    entry for entry in post
    if not any("autopilot-logger.sh" in h.get("command", "") for h in entry.get("hooks", []))
]

if len(filtered) < len(post):
    hooks["PostToolUse"] = filtered
    settings["hooks"] = hooks
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("Removed autopilot-logger hook.")
else:
    print("autopilot-logger hook not found, nothing to remove.")
PYEOF
fi

echo "✓ Autopilot plugin uninstalled."
echo "  Orphaned backups (if any) remain in: $HOME/.claude/autopilot-backups/"
echo "  Session logs remain in: $HOME/.claude/autopilot-sessions/"
