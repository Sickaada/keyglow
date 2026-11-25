# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

(Native Apple platform. The actual target is macOS 13+, SwiftUI, built with swiftc; the closest recorded value is `ios`.)

## Users

One person: the owner of a Keychron K3 Pro (ANSI RGB) who uses it with a Mac over Bluetooth. A personal tool, not for distribution.

## Product Purpose

KeyGlow lets the owner change the keyboard's RGB lighting (on/off, effect, color, brightness, speed) wirelessly from the Mac, which the stock keyboard can't do over Bluetooth. Success: picking a look takes a few seconds and then it's forgotten.

## Positioning

It's the only way to control this keyboard's lighting over Bluetooth. Commands travel through the HID lock-light (LED) report to custom QMK firmware on the keyboard.

## Operating Context

- Used now and then: set it, then forget it for days.
- Lives in the macOS menu bar as a compact panel that's always one click away.
- Each command takes about 1 second to reach the keyboard, so the UI must make "sent / still sending" clear and not promise instant feedback.
- Needs the macOS Input Monitoring permission (it only sends light signals and never reads keys).
- Works over Bluetooth only. The firmware also has to be flashed once over USB.

## Capabilities and Constraints

- Commands: lights on/off; 22 firmware effects (fixed order shared with the firmware); hue/saturation and brightness (0–255); speed (0–255).
- In wireless mode, brightness below about 48 turns the backlight off (firmware power saving).
- Diagnostics: "flash keyboard white" ping, signal view (keys 1–5 show raw bits), raw bit toggles, frame gap.
- Status needed: keyboard found / transport, permission granted.
- No readback: the app can't read the keyboard's current state, so values shown are the last ones sent.

## Product Principles

1. Quick and quiet: get in, pick a look, get out.
2. Honest about latency and state: show what was sent, never pretend to know what the keyboard shows.
3. Respect privacy: always clear that nothing typed is read.
4. Diagnostics are available but kept out of the way.
