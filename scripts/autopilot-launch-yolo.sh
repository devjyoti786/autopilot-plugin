#!/bin/bash
# autopilot-launch-yolo.sh — open new terminal with claude --dangerously-skip-permissions
# Usage: bash autopilot-launch-yolo.sh <workspace_path>

set -euo pipefail

WS="${1:-$PWD}"
CMD="cd '$WS' && claude --dangerously-skip-permissions; exec bash"

launch_terminal() {
    if command -v xdg-terminal-exec &>/dev/null; then
        xdg-terminal-exec bash -c "$CMD" &
        return 0
    fi
    if command -v x-terminal-emulator &>/dev/null; then
        x-terminal-emulator -e bash -c "$CMD" &
        return 0
    fi
    if command -v gnome-terminal &>/dev/null; then
        gnome-terminal -- bash -c "$CMD" &
        return 0
    fi
    if command -v sensible-terminal &>/dev/null; then
        sensible-terminal -- bash -c "$CMD" &
        return 0
    fi
    if command -v kitty &>/dev/null; then
        kitty bash -c "$CMD" &
        return 0
    fi
    if command -v alacritty &>/dev/null; then
        alacritty -e bash -c "$CMD" &
        return 0
    fi
    if command -v xterm &>/dev/null; then
        xterm -e bash -c "$CMD" &
        return 0
    fi
    if command -v konsole &>/dev/null; then
        konsole -e bash -c "$CMD" &
        return 0
    fi
    if command -v warp-terminal &>/dev/null; then
        warp-terminal &
        echo "WARP_FALLBACK"
        return 1
    fi
    return 1
}

if launch_terminal 2>/dev/null; then
    echo "LAUNCHED"
else
    echo "MANUAL"
    echo "cd '$WS' && claude --dangerously-skip-permissions"
fi
