#!/bin/bash
# Reads autopilot-state.json, logs tool calls when autopilot is active.
# Called by Claude Code as a PostToolUse hook.

STATE="$HOME/.claude/autopilot-state.json"
[ -f "$STATE" ] || exit 0

MODE=$(python3 -c "import json; d=json.load(open('$STATE')); print(d.get('mode','off'))" 2>/dev/null)
[ "$MODE" = "off" ] && exit 0
[ -z "$MODE" ] && exit 0

LOG_PATH=$(python3 -c "import json,os; d=json.load(open('$STATE')); p=d.get('sessionLog',''); print(os.path.expanduser(p))" 2>/dev/null)
[ -z "$LOG_PATH" ] && exit 0

mkdir -p "$(dirname "$LOG_PATH")"

TOOL="${CLAUDE_TOOL_NAME:-unknown}"
INPUT_PREVIEW="${CLAUDE_TOOL_INPUT:-}"
# Truncate input preview to 80 chars
INPUT_PREVIEW="${INPUT_PREVIEW:0:80}"

echo "[$(date '+%H:%M:%S')] TOOL:$TOOL | mode:$MODE | input:${INPUT_PREVIEW}" >> "$LOG_PATH"
