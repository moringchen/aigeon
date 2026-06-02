# Aigeon DMG Finder Layout Design

## Goal

Produce a polished macOS DMG installer for the public `aigeon` release repo that opens as a drag-to-install window instead of a plain file container.

The DMG must:

- show `Aigeon.app` on the left
- show the `Applications` shortcut on the right
- present bilingual guidance:
  - `Drag Aigeon to Applications`
  - `拖动 Aigeon 到 Applications`
- use the approved visual direction:
  - clean brand style
  - not screenshot-heavy
- continue to output the final installer as `Aigeon_0.1.0_x64.dmg`

## Scope

This design covers only release packaging and public-facing installer presentation in the current release repo.

In scope:

- add a DMG background asset
- add a repeatable DMG build script
- use Finder and AppleScript to apply window presentation after mounting a staging DMG
- regenerate the final `Aigeon_0.1.0_x64.dmg`
- document drag-to-install usage in release docs if needed

Out of scope:

- app source code changes
- signing
- notarization
- switching to a different DMG tool such as `create-dmg`
- cross-platform packaging

## Constraints

- The repo currently acts as a public asset/release repo and must not expose source code.
- The user explicitly chose Finder/AppleScript post-processing over external packaging tools.
- The solution should work on the current macOS machine even if it is less portable than a dedicated DMG packager.
- Existing release filenames should stay stable so published download links do not change.

## Options Considered

### Option 1: Plain `hdiutil` only

Generate a DMG from a folder containing `Aigeon.app` and an `Applications` symlink.

Rejected because it cannot reliably produce the polished visual layout the user requested.

### Option 2: Dedicated DMG packager

Use a purpose-built tool such as `create-dmg` to manage background, icon coordinates, and window settings.

Rejected because the user chose not to introduce this path.

### Option 3: Finder/AppleScript post-processing

Create a writable staging DMG, mount it, apply Finder window settings and icon placement with AppleScript, then convert to the final compressed DMG.

Accepted because it matches the requested implementation path and can deliver the requested drag-to-install presentation on the current machine.

## Selected Design

### Build Flow

The DMG build process will be split into deterministic packaging steps:

1. Prepare a staging folder containing:
   - `Aigeon.app`
   - `Applications` symlink
   - hidden background asset directory
2. Create a writable temporary DMG from the staging folder.
3. Mount the temporary DMG.
4. Use AppleScript against Finder to:
   - open the mounted volume
   - switch to icon view
   - hide toolbar and status bar
   - set window bounds
   - set icon size
   - set background picture
   - position `Aigeon.app`
   - position `Applications`
5. Close the Finder window and give Finder enough time to persist `.DS_Store`.
6. Detach the temporary volume.
7. Convert the writable DMG into the final compressed `UDZO` image named `Aigeon_0.1.0_x64.dmg`.

### Visual Layout

The Finder window should present a clean, branded layout:

- background: a static branded image
- left item: `Aigeon.app`
- right item: `Applications`
- centered visual flow from left to right
- bilingual instruction embedded in the background image:
  - `Drag Aigeon to Applications`
  - `拖动 Aigeon 到 Applications`

The design should avoid product screenshots and instead use a simple branded composition with clear whitespace and directionality.

### Asset Strategy

One new background image asset will be added to the release repo for DMG presentation.

Requirements for the asset:

- sized for the chosen Finder window bounds
- includes the bilingual instruction text
- visually compatible with the current Aigeon release branding
- static image only, no generated runtime dependency

### Script Strategy

A dedicated build script will be added to the repo instead of relying on manual command history.

The script will own:

- staging directory preparation
- symlink creation
- background asset placement
- temporary DMG creation
- Finder/AppleScript layout application
- conversion to final compressed DMG
- cleanup of temporary artifacts

The script should be safe to rerun and should overwrite prior temporary packaging artifacts.

## File Plan

Expected additions:

- `scripts/build-dmg.sh`
- `dmg-background/` asset file or similar repo-local asset path
- updated `Aigeon_0.1.0_x64.dmg`

Possible doc update:

- `README.md`
- `README.zh-CN.md`

Final implementation may adjust exact asset paths, but the build script and background asset must live in the public release repo.

## Verification Plan

Implementation will be accepted only if all of the following are true:

- opening `Aigeon_0.1.0_x64.dmg` shows a Finder window, not just a plain mounted folder view
- the window displays a branded background
- `Aigeon.app` is positioned on the left
- `Applications` is positioned on the right
- the bilingual drag instruction is visible in the window
- dragging `Aigeon.app` to `Applications` works normally
- the DMG still contains the corrected app icon in the bundled app

## Risks

### Finder persistence instability

Finder can fail to persist window metadata if the script closes or detaches too quickly.

Mitigation:

- include explicit delays after layout changes
- close the window cleanly before detach
- verify the mounted result after build

### AppleScript fragility

Finder scripting can be sensitive to localization and UI timing.

Mitigation:

- target mounted volume items by name
- keep the Finder operations minimal and ordered
- validate on the current machine after each build

### Background alias/path issues

Finder background images must exist inside the DMG, commonly in a hidden folder.

Mitigation:

- store the background asset inside the staging volume under a hidden path
- set the background picture to that in-volume file before final conversion

## Success Criteria

The task is complete when the public repo ships a new `Aigeon_0.1.0_x64.dmg` that opens into a branded drag-to-install Finder window using the approved clean bilingual layout, without changing release filenames or exposing source code.
