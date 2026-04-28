#!/bin/bash
# Usage: autopilot-restore.sh <backup_path> <workspace_path>
# Copies backup back to workspace. cp -r only, never mv.

set -euo pipefail

BACKUP="${1:?backup_path required}"
WORKSPACE="${2:?workspace_path required}"

if [ ! -d "$BACKUP" ]; then
    echo "ERROR: backup directory '$BACKUP' does not exist" >&2
    exit 1
fi

if [ ! -d "$WORKSPACE" ]; then
    echo "ERROR: workspace '$WORKSPACE' does not exist" >&2
    exit 1
fi

echo "Restoring from $BACKUP to $WORKSPACE..."
cp -r "$BACKUP/." "$WORKSPACE/"
echo "Restore complete."
