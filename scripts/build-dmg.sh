#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Aigeon.app"
APP_PATH="$ROOT_DIR/$APP_NAME"
OUTPUT_DMG="$ROOT_DIR/Aigeon_0.1.0_x64.dmg"
TMP_DIR="$(mktemp -d /tmp/aigeon-dmg.XXXXXX)"
STAGE_DIR="$TMP_DIR/stage"
RW_DMG="$TMP_DIR/Aigeon-rw.dmg"
FINAL_DMG="$TMP_DIR/Aigeon-final.dmg"
MOUNT_POINT="/Volumes/Aigeon"
VOLUME_NAME="Aigeon"
WINDOW_BOUNDS="{260, 180, 780, 500}"
APP_POSITION="{170, 150}"
APPLICATIONS_POSITION="{330, 150}"
ICON_SIZE="96"

cleanup() {
  if mount | grep -q "on ${MOUNT_POINT} "; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
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

if mount | grep -q "on ${MOUNT_POINT} "; then
  hdiutil detach "$MOUNT_POINT" -quiet || true
fi

hdiutil create -quiet -ov -fs HFS+ -format UDRW -srcfolder "$STAGE_DIR" -volname "$VOLUME_NAME" "$RW_DMG"
ATTACH_OUTPUT="$(hdiutil attach -noverify -noautoopen "$RW_DMG")"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | sed -n 's#.*\(/Volumes/.*\)$#\1#p' | head -n 1)"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Failed to determine mounted DMG path" >&2
  printf '%s\n' "$ATTACH_OUTPUT" >&2
  exit 1
fi

osascript - "$VOLUME_NAME" "$WINDOW_BOUNDS" "$APP_POSITION" "$APPLICATIONS_POSITION" "$ICON_SIZE" <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv
  set windowBounds to run script (item 2 of argv)
  set appPosition to run script (item 3 of argv)
  set applicationsPosition to run script (item 4 of argv)
  set iconSizeValue to (item 5 of argv) as integer

  tell application "Finder"
    activate
    tell disk volumeName
      open
      delay 1
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to windowBounds
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to iconSizeValue
      set text size of viewOptions to 12
      set position of item "Aigeon.app" to appPosition
      set position of item "Applications" to applicationsPosition
      delay 2
      close
      open
      delay 1
      close
    end tell
  end tell
end run
APPLESCRIPT

sync
sleep 2
hdiutil detach "$MOUNT_POINT" -quiet
hdiutil convert "$RW_DMG" -quiet -format UDZO -o "$FINAL_DMG"
mv "$FINAL_DMG" "$OUTPUT_DMG"

echo "Built $OUTPUT_DMG"
