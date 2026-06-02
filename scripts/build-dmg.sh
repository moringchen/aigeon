#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Aigeon.app"
APP_PATH="$ROOT_DIR/$APP_NAME"
OUTPUT_DMG="$ROOT_DIR/Aigeon_0.1.0_x64.dmg"
TMP_DIR="$(mktemp -d /tmp/aigeon-dmg.XXXXXX)"
STAGE_DIR="$TMP_DIR/stage"
VOLUME_NAME="Aigeon"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/$APP_NAME"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create -quiet -ov -fs HFS+ -format UDZO -srcfolder "$STAGE_DIR" -volname "$VOLUME_NAME" "$OUTPUT_DMG"

echo "Built $OUTPUT_DMG"
