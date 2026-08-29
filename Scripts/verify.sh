#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

swift test --disable-sandbox
bash Scripts/make-app.sh
plutil -lint dist/Scene.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 dist/Scene.app

BOOKS_DIR="${SCENE_BOOKS_DIR:-$HOME/Documents/Knowledge/Books/real}"
if [[ -d "$BOOKS_DIR" ]]; then
  before="$(find "$BOOKS_DIR" -maxdepth 1 -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256)"
  catalog="$(dist/Scene.app/Contents/MacOS/Scene catalog)"
  after="$(find "$BOOKS_DIR" -maxdepth 1 -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256)"
  [[ "$before" == "$after" ]]
  [[ -n "$catalog" ]]
fi

if rg -n 'Timer|sleep\(|while true|DispatchSourceTimer' Sources; then
  echo "error: an idle polling primitive entered Scene sources" >&2
  exit 1
fi
echo "SCENE VERDICT: PASS"
