#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
swift "$SCRIPT_DIR/interaction-smoke.swift" --prepare
pkill -x Scene 2>/dev/null || true
attempt=0
while pgrep -x Scene >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -ge 30 ]]; then
    echo "interaction-smoke: old Scene process did not exit" >&2
    exit 1
  fi
  sleep 0.1
done
open -g /Applications/Scene.app --args hidden interaction-smoke
attempt=0
until pgrep -x Scene >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -ge 30 ]]; then
    echo "interaction-smoke: Scene did not start" >&2
    exit 1
  fi
  sleep 0.1
done
# LaunchServices can report the process before AppKit has finished installing
# the Carbon hot key and edge sensors. Give the background app a bounded,
# deterministic readiness window before exercising those inputs.
sleep 2
swift "$SCRIPT_DIR/interaction-smoke.swift"
