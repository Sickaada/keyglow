# Keychron Lighting Studio

## Platform
Native macOS 14+, SwiftUI/AppKit, built with swiftc. Distributed here as KeyGlow.app with bundle identifier local.keyglow so existing local preferences remain available.

## Users and purpose
A personal utility for one Keychron K3 Pro ANSI RGB owner. Pick lighting, occasionally change it, keep saved looks. It lives in the menu bar and uses custom firmware to carry lighting commands over Bluetooth.

## Confirmed application capabilities
The current source exposes 26 firmware effects: 22 QMK effects plus split, gradient, color fade and color wave. It sends power, HSV brightness, speed, two additional palette colors, diagnostics and battery-display commands. Two/three-color palette editing is available for the four custom effects. Existing device detection, packet encoding and serial command coalescing are retained.

The interface has Lighting, Animations and Presets tabs; a separate editor configures the existing palette effects. Library operations are local create/apply/rename/update/duplicate/delete/favorite and JSON import/export. Existing cue storage migrates in place.

## State and privacy
- Preview and controls represent the selected look, which may be an unsent local edit.
- The UI tracks the look associated with completed submissions and labels newer edits as waiting to apply.
- Host write success is not a keyboard acknowledgement. No lighting readback exists.
- Approximate motion previews have no real typing input or phase synchronization.
- Input Monitoring is granted to KeyGlow only. The sender does not register keyboard-input callbacks.
- A Bluetooth command takes roughly two seconds including repeat/gaps; a whole palette can take several commands. UI previews update independently. No latency guarantee is made.

## Constraints
- UI permits hardware control when device detection, Bluetooth transport and permission are available; offline editing is explicitly preview-only.
- A one-time wired firmware setup was previously performed; this UI redesign does not alter or flash firmware. Installed firmware capabilities cannot be queried.
- Brightness below 48/255 turns the lighting off on battery.
- Per-key painting, arbitrary keyframe timelines, multiple layers, configurable direction/easing/duration require a separately approved engine change. See docs/ANIMATION-ENGINE-REQUIREMENTS.md.
- Physical outcomes for this redesign must be distinguished from build, snapshot and local data verification. See docs/VERIFICATION.md.

## Visual authority
The user's supplied Keychron Lighting Studio brief replaces the earlier Cue Sheet concept. Graphite native controls surround a dark 84-key visualization with RGB illumination beneath the caps. DESIGN.md records the implemented system.
