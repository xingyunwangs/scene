#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="$ROOT_DIR/dist/Scene.app"
DESTINATION="/Applications/Scene.app"
BACKUP_DIR="$HOME/Library/Application Support/Scene/Install Backups/$(date -u +%Y%m%dT%H%M%SZ)"

pkill -x Scene 2>/dev/null || true
attempt=0
while pgrep -x Scene >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  [[ "$attempt" -lt 30 ]] || { echo "Scene did not exit" >&2; exit 1; }
  sleep 0.1
done
if [[ -e "$DESTINATION" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$DESTINATION" "$BACKUP_DIR/Scene.app"
fi
ditto "$SOURCE" "$DESTINATION"
codesign --verify --deep --strict --verbose=2 "$DESTINATION"
echo "Installed Scene.app without launching it."
