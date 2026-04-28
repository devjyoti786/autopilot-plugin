#!/bin/bash
# Usage: autopilot-backup.sh <workspace_path> <timestamp>
# Outputs: backup directory path on stdout
# Copies workspace to backup dir, excluding large/irrelevant directories.

set -euo pipefail

WORKSPACE="${1:?workspace_path required}"
TIMESTAMP="${2:?timestamp required}"
BACKUP_DIR="$HOME/.claude/autopilot-backups/$TIMESTAMP"

# Validate workspace exists
if [ ! -d "$WORKSPACE" ]; then
    echo "ERROR: workspace '$WORKSPACE' does not exist" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# Copy using rsync if available (handles excludes cleanly), else use cp
EXCLUDES=(
    "--exclude=node_modules"
    "--exclude=.git"
    "--exclude=__pycache__"
    "--exclude=.venv"
    "--exclude=venv"
    "--exclude=dist"
    "--exclude=build"
    "--exclude=.next"
    "--exclude=.cache"
    "--exclude=*.pyc"
    "--exclude=.DS_Store"
)

if command -v rsync &>/dev/null; then
    rsync -a "${EXCLUDES[@]}" "$WORKSPACE/" "$BACKUP_DIR/"
else
    # Fallback: cp -r then clean excluded patterns recursively
    cp -r "$WORKSPACE/." "$BACKUP_DIR/"
    # Remove excluded directories recursively (prune to avoid descending into them)
    for excl in node_modules .git __pycache__ .venv venv dist build .next .cache; do
        find "$BACKUP_DIR" -type d -name "$excl" -prune -exec rm -rf {} + 2>/dev/null || true
    done
    # Remove excluded file patterns
    find "$BACKUP_DIR" -name '*.pyc' -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name '.DS_Store' -delete 2>/dev/null || true
fi

# Output the backup path (captured by the skill)
echo "$BACKUP_DIR"
