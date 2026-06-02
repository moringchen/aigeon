# Aigeon DMG Finder Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a branded drag-to-install `Aigeon_0.1.0_x64.dmg` that opens with a Finder window showing `Aigeon.app` on the left, `Applications` on the right, and bilingual installation guidance.

**Architecture:** Keep release packaging inside the public asset repo by adding a repo-local DMG background source asset and a single shell build script. The script prepares a staging volume, rasterizes the background source into a PNG, mounts a writable DMG, applies Finder layout via AppleScript, waits for `.DS_Store` persistence, then converts the result into the final compressed DMG.

**Tech Stack:** macOS shell (`bash`), `hdiutil`, `osascript`, `qlmanage`, Finder AppleScript, Markdown docs

---

## File Structure

- Create: `dmg-assets/background.svg`
- Create: `scripts/build-dmg.sh`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Output: `Aigeon_0.1.0_x64.dmg`

Responsibilities:

- `dmg-assets/background.svg`: canonical DMG background source with bilingual guidance and clean brand styling
- `scripts/build-dmg.sh`: repeatable DMG packaging pipeline, including staging, rasterization, Finder layout, compression, and cleanup
- `README.md`: English install wording for drag-to-Applications flow
- `README.zh-CN.md`: Chinese install wording for drag-to-Applications flow

### Task 1: Add The Branded DMG Background Source

**Files:**
- Create: `dmg-assets/background.svg`
- Test: `qlmanage` thumbnail generation from `dmg-assets/background.svg`

- [ ] **Step 1: Create the DMG background source asset**

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="960" height="540" viewBox="0 0 960 540">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f7fbff" />
      <stop offset="58%" stop-color="#dce9ff" />
      <stop offset="100%" stop-color="#cfdfff" />
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#275df5" flood-opacity="0.12" />
    </filter>
  </defs>

  <rect width="960" height="540" fill="url(#bg)" />
  <circle cx="132" cy="108" r="124" fill="#ffffff" opacity="0.30" />
  <circle cx="840" cy="438" r="132" fill="#ffffff" opacity="0.22" />

  <text x="84" y="104" fill="#173066" font-size="42" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="700">
    Aigeon
  </text>
  <text x="84" y="152" fill="#4f6796" font-size="24" font-family="Helvetica Neue, Helvetica, Arial, sans-serif">
    Drag Aigeon to Applications
  </text>
  <text x="84" y="188" fill="#4f6796" font-size="24" font-family="PingFang SC, Hiragino Sans GB, Microsoft YaHei, sans-serif">
    拖动 Aigeon 到 Applications
  </text>

  <g filter="url(#shadow)">
    <rect x="128" y="250" rx="34" ry="34" width="164" height="164" fill="#ffffff" stroke="#c7d6f7" stroke-width="2" />
    <text x="210" y="334" text-anchor="middle" fill="#275df5" font-size="28" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="700">
      Aigeon
    </text>
    <text x="210" y="368" text-anchor="middle" fill="#7a8db8" font-size="18" font-family="Helvetica Neue, Helvetica, Arial, sans-serif">
      App
    </text>
  </g>

  <text x="472" y="345" text-anchor="middle" fill="#5c78ba" font-size="64" font-family="Helvetica Neue, Helvetica, Arial, sans-serif">
    →
  </text>

  <g filter="url(#shadow)">
    <rect x="668" y="250" rx="34" ry="34" width="164" height="164" fill="#ffffff" stroke="#c7d6f7" stroke-width="2" />
    <text x="750" y="334" text-anchor="middle" fill="#2d4e90" font-size="26" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="700">
      Applications
    </text>
  </g>
</svg>
```

- [ ] **Step 2: Verify macOS can rasterize the SVG**

Run:

```bash
mkdir -p /tmp/aigeon-dmg-preview
qlmanage -t -s 960 -o /tmp/aigeon-dmg-preview dmg-assets/background.svg
ls -lh /tmp/aigeon-dmg-preview/background.svg.png
```

Expected:

```text
-rw-r--r--  ... /tmp/aigeon-dmg-preview/background.svg.png
```

- [ ] **Step 3: Commit the background source**

```bash
git add dmg-assets/background.svg
git commit -m "assets: add dmg background source"
```

### Task 2: Add The Repeatable DMG Build Script

**Files:**
- Create: `scripts/build-dmg.sh`
- Test: local `bash` execution of the script

- [ ] **Step 1: Create the DMG build script**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Aigeon.app"
APP_PATH="$ROOT_DIR/$APP_NAME"
OUTPUT_DMG="$ROOT_DIR/Aigeon_0.1.0_x64.dmg"
ASSET_SVG="$ROOT_DIR/dmg-assets/background.svg"
TMP_DIR="$(mktemp -d /tmp/aigeon-dmg.XXXXXX)"
STAGE_DIR="$TMP_DIR/stage"
BG_DIR="$STAGE_DIR/.background"
RASTER_DIR="$TMP_DIR/raster"
RW_DMG="$TMP_DIR/Aigeon-rw.dmg"
MOUNT_POINT="/Volumes/Aigeon"
VOLUME_NAME="Aigeon"
WINDOW_BOUNDS="{120, 120, 1080, 660}"
APP_POSITION="{180, 320}"
APPLICATIONS_POSITION="{780, 320}"
ICON_SIZE=128

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

if [[ ! -f "$ASSET_SVG" ]]; then
  echo "Missing DMG background source: $ASSET_SVG" >&2
  exit 1
fi

mkdir -p "$BG_DIR" "$RASTER_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/$APP_NAME"
ln -s /Applications "$STAGE_DIR/Applications"

qlmanage -t -s 960 -o "$RASTER_DIR" "$ASSET_SVG" >/dev/null 2>&1
cp "$RASTER_DIR/background.svg.png" "$BG_DIR/background.png"

hdiutil create -quiet -ov -fs HFS+ -srcfolder "$STAGE_DIR" -volname "$VOLUME_NAME" "$RW_DMG"
hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$MOUNT_POINT" "$RW_DMG"

osascript <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv
  set mountPoint to item 2 of argv
  set windowBounds to item 3 of argv
  set appPosition to item 4 of argv
  set applicationsPosition to item 5 of argv
  set iconSizeValue to (item 6 of argv) as integer

  tell application "Finder"
    activate
    tell disk volumeName
      open
      delay 1
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to run script windowBounds
      tell icon view options of container window
        set arrangement to not arranged
        set icon size to iconSizeValue
        set text size to 14
        set background picture to file ".background:background.png"
      end tell
      set position of item "Aigeon.app" to run script appPosition
      set position of item "Applications" to run script applicationsPosition
      close
      open
      delay 2
      close
    end tell
  end tell
end run
APPLESCRIPT
"$VOLUME_NAME" "$MOUNT_POINT" "$WINDOW_BOUNDS" "$APP_POSITION" "$APPLICATIONS_POSITION" "$ICON_SIZE"

sync
sleep 2
hdiutil detach "$MOUNT_POINT" -quiet
hdiutil convert "$RW_DMG" -quiet -format UDZO -o "$OUTPUT_DMG"

echo "Built $OUTPUT_DMG"
```

- [ ] **Step 2: Make the script executable and run it to surface the first failure**

Run:

```bash
chmod +x scripts/build-dmg.sh
bash scripts/build-dmg.sh
```

Expected:

```text
Built /Users/moringchen/workspace/ai/tools/aigeon/Aigeon_0.1.0_x64.dmg
```

If it fails, capture the exact failing command and update the script before moving on.

- [ ] **Step 3: Harden the script for mount-point reuse and Finder timing**

Update the script with these minimal hardening changes:

```bash
if mount | grep -q "on ${MOUNT_POINT} "; then
  hdiutil detach "$MOUNT_POINT" -quiet || true
fi

mkdir -p "$STAGE_DIR" "$BG_DIR" "$RASTER_DIR"

hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$MOUNT_POINT" "$RW_DMG"
sleep 1
```

And replace the raster-copy section with:

```bash
qlmanage -t -s 960 -o "$RASTER_DIR" "$ASSET_SVG" >/dev/null 2>&1
BACKGROUND_PNG="$RASTER_DIR/$(basename "$ASSET_SVG").png"
if [[ ! -f "$BACKGROUND_PNG" ]]; then
  echo "Failed to rasterize DMG background from $ASSET_SVG" >&2
  exit 1
fi
cp "$BACKGROUND_PNG" "$BG_DIR/background.png"
```

- [ ] **Step 4: Re-run the script and verify the final DMG exists**

Run:

```bash
bash scripts/build-dmg.sh
ls -lh Aigeon_0.1.0_x64.dmg
```

Expected:

```text
Built /Users/moringchen/workspace/ai/tools/aigeon/Aigeon_0.1.0_x64.dmg
-rw-r--r--  ... Aigeon_0.1.0_x64.dmg
```

- [ ] **Step 5: Commit the build script**

```bash
git add scripts/build-dmg.sh
git commit -m "build: add branded dmg packaging script"
```

### Task 3: Update Install Docs To Match The Drag-To-Applications Flow

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Test: `rg "drag|拖动"` on both README files

- [ ] **Step 1: Update the English install section**

Insert this paragraph immediately after the download links paragraph in `README.md`:

```md
Open the DMG and drag `Aigeon.app` into `Applications`.
```

- [ ] **Step 2: Update the Chinese install section**

Insert this paragraph immediately after the download links paragraph in `README.zh-CN.md`:

```md
打开 DMG 后，将 `Aigeon.app` 拖动到 `Applications`。
```

- [ ] **Step 3: Verify the install wording is present**

Run:

```bash
rg -n 'drag `Aigeon.app`|拖动到 `Applications`' README.md README.zh-CN.md
```

Expected:

```text
README.md:...:Open the DMG and drag `Aigeon.app` into `Applications`.
README.zh-CN.md:...:打开 DMG 后，将 `Aigeon.app` 拖动到 `Applications`。
```

- [ ] **Step 4: Commit the doc updates**

```bash
git add README.md README.zh-CN.md
git commit -m "docs: describe dmg drag install flow"
```

### Task 4: Verify The Finder Presentation End-To-End

**Files:**
- Output: `Aigeon_0.1.0_x64.dmg`
- Verify: mounted `/Volumes/Aigeon`

- [ ] **Step 1: Mount the rebuilt DMG**

Run:

```bash
hdiutil attach -nobrowse -readonly Aigeon_0.1.0_x64.dmg
```

Expected:

```text
/Volumes/Aigeon
```

- [ ] **Step 2: Verify the DMG contains the expected installer items**

Run:

```bash
find /Volumes/Aigeon -maxdepth 2 -mindepth 1 | sort
```

Expected:

```text
/Volumes/Aigeon/Aigeon.app
/Volumes/Aigeon/Applications
```

- [ ] **Step 3: Verify the app bundle inside the DMG still has the icon declaration**

Run:

```bash
plutil -p /Volumes/Aigeon/Aigeon.app/Contents/Info.plist | rg "CFBundleIconFile|icon.icns"
find /Volumes/Aigeon/Aigeon.app/Contents/Resources -maxdepth 1 -type f | sort
```

Expected:

```text
"CFBundleIconFile" => "icon.icns"
/Volumes/Aigeon/Aigeon.app/Contents/Resources/icon.icns
```

- [ ] **Step 4: Visually verify Finder layout**

Manual check:

```text
Open the mounted volume in Finder and verify:
1. The window opens in icon view.
2. The branded background is visible.
3. "Drag Aigeon to Applications" and "拖动 Aigeon 到 Applications" are visible.
4. Aigeon.app is on the left.
5. Applications is on the right.
6. The layout reads naturally as a drag-to-install flow.
```

- [ ] **Step 5: Detach the mounted volume**

Run:

```bash
hdiutil detach /Volumes/Aigeon
```

Expected:

```text
"Aigeon" ejected.
```

- [ ] **Step 6: Commit the rebuilt installer**

```bash
git add Aigeon_0.1.0_x64.dmg
git commit -m "build: refresh branded dmg installer"
```

## Self-Review

Spec coverage check:

- background asset: Task 1
- repeatable build script: Task 2
- Finder/AppleScript post-processing: Task 2
- branded bilingual drag layout: Tasks 1, 2, 4
- keep final filename stable: Tasks 2, 4
- document drag install usage: Task 3
- verify corrected app icon remains in bundle: Task 4

Placeholder scan:

- no `TODO`, `TBD`, or unresolved references remain

Type and naming consistency:

- final DMG filename is consistently `Aigeon_0.1.0_x64.dmg`
- volume name is consistently `Aigeon`
- background source path is consistently `dmg-assets/background.svg`
- build script path is consistently `scripts/build-dmg.sh`
