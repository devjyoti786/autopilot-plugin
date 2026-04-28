#!/bin/bash
# Outputs [AP:MODE] when autopilot is active, nothing when off.
# Used as a statusLine component in Claude Code settings.

STATE="$HOME/.claude/autopilot-state.json"
[ -f "$STATE" ] || exit 0

MODE=$(python3 -c "
import json, sys
try:
    d = json.load(open('$STATE'))
    m = d.get('mode', 'off')
    print(m if m != 'off' else '', end='')
except:
    pass
" 2>/dev/null)

if [ -n "$MODE" ]; then
    echo -n "[AP:${MODE^^}]"
fi
exit 0
