---
name: KeyGlow
description: A stage manager's cue sheet for one keyboard's lights, living in the macOS menu bar.
colors:
  running-blue: "#16205a"
  raised-blue: "#1e2b70"
  rule-blue: "#2f3c86"
  lift-blue: "#6b80e2"
  paper: "#eef1f7"
  dim-paper: "#a3acd9"
  standby-red: "#e5484d"
  go-green: "#30a46c"
  attention-amber: "#f5b83d"
typography:
  cue-number:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: "26pt"
    fontWeight: 600
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "15pt"
    fontWeight: 600
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "13pt"
    fontWeight: 700
  body:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "13pt"
    fontWeight: 400
  callout:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "12pt"
    fontWeight: 400
  meta:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "11pt"
    fontWeight: 400
    fontFeature: "tnum"
  label:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "11pt"
    fontWeight: 500
    letterSpacing: "0.8pt"
  figures:
    fontFamily: "SF Mono, ui-monospace, Menlo, monospace"
    fontSize: "12pt"
    fontWeight: 400
  badge:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "10pt"
    fontWeight: 700
    letterSpacing: "0.8pt"
rounded:
  swatch: "3px"
  well: "6px"
spacing:
  hair: "2px"
  xs: "8px"
  sm: "10px"
  md: "12px"
  lg: "16px"
components:
  panel:
    backgroundColor: "{colors.running-blue}"
    textColor: "{colors.paper}"
    width: "340px"
  cue-row:
    textColor: "{colors.paper}"
    typography: "{typography.body}"
    rounded: "{rounded.well}"
    padding: "6px 8px"
  cue-row-current:
    backgroundColor: "{colors.raised-blue}"
    textColor: "{colors.paper}"
    rounded: "{rounded.well}"
    padding: "6px 8px"
  gel-chip:
    rounded: "{rounded.well}"
    height: "46px"
    typography: "{typography.figures}"
  row-label:
    textColor: "{colors.dim-paper}"
    typography: "{typography.label}"
    width: "60px"
  off-cue-badge:
    backgroundColor: "{colors.dim-paper}"
    textColor: "{colors.running-blue}"
    typography: "{typography.badge}"
    rounded: "{rounded.swatch}"
    padding: "2px 5px"
  cue-lamp:
    size: "10px"
    typography: "{typography.label}"
---

# Design System: KeyGlow

## Overview

**Creative North Star: "The Cue Sheet"**

KeyGlow is a stage manager's running sheet in a 340 pt menu bar window. Every lighting look is a numbered cue (Q1, Q2...), and every send is a stage call: the lamp goes red for standby while the signal travels, then green for go when it lands. The shell is the deep blue of a backstage running light, the text is cool paper-white, and the only saturated color on screen is either the gel (the keyboard's own color) or the cue lamp telling you where the call stands.

Density is calm and compact: one column, hairline-ruled bands, standard native controls tinted into the world rather than replaced. Numbers are always set in monospaced figures so values sit in fixed columns like a cue sheet. Inside lists, rank comes from weight and brightness, never from size. The panel is honest about latency and state: it shows what was last sent and whether it arrived, and never pretends to read the keyboard back.

It refuses the category default of a grey Control Center tile grid.

**Key Characteristics:**
- Single dark running-light shell (#16205a family), forced dark appearance.
- Cue lamp as the one live signal: red standby, green go, amber check, dim idle.
- SF Pro for words, SF Mono for every number.
- Uppercase tracked micro-labels for control rows and the cue list heading.
- Hairline rules in lifted blue divide the panel into bands; no cards, no shadows on surfaces.
- Native macOS controls (switch, menu picker, small sliders) tinted with lift blue.

## Colors

A single deep-blue world with paper text and three cue-light signal colors that only ever mean state.

### Primary
- **Running-Light Blue** (running-blue): the whole panel ground. Every surface sits on it; nothing in the panel is lighter-backgrounded except the selected cue row and the gel.
- **Lift Blue** (lift-blue): the tint for native controls (switch track, slider fill, focus). The only blue that reads as interactive.

### Secondary
- **Standby Red** (standby-red): cue lamp while a command is in flight. Pulses gently unless Reduce Motion is on.
- **Go Green** (go-green): cue lamp for about 4 seconds after a send lands, then the lamp returns to idle.
- **Attention Amber** (attention-amber): lamp state "Check" when the keyboard isn't ready or a send failed; also the text color for warnings (low-level power-saving note, send errors, failed footer status).

### Neutral
- **Cue Paper** (paper): primary text, cue numbers, current-row values. Non-current cue rows use it at 82% opacity.
- **Dim Paper** (dim-paper): a blue-tinted secondary text (about 6.7:1 on the shell) for device line, meta line, row labels, help copy, footer, idle lamp word, and the OFF CUE badge fill.
- **Raised Blue** (raised-blue): fill of the current cue row; at 50% it is the hover fill for other rows.
- **Rule Blue** (rule-blue): 1 px hairlines between bands, and the unlit (idle) cue lamp.

### Named Rules
**The Signal Colors Mean State Rule.** Red, green, and amber appear only as cue-lamp states and their matching state text. They are never decoration, never brand accents, never used on controls.

**The Gel Is the Keyboard's Color Rule.** The only free hue in the panel is the gel chip and the cue swatches, which show the keyboard's own color. The UI chrome stays inside the blue family.

## Typography

**Body Font:** SF Pro (system)
**Figures Font:** SF Mono (system monospaced design)

**Character:** Plain system text for words, a monospaced voice for every number so values line up in fixed columns the way a cue sheet does. Built on SwiftUI's macOS text styles, so sizes track the system.

### Hierarchy
- **Cue number** (SF Mono semibold, largeTitle 26pt): the current cue's Q-number. Dims to dim-paper when the live look is off cue.
- **Title** (semibold, title3 15pt): current cue name, and the headline of each not-ready state.
- **Headline** (bold, 13pt): the device name in the header.
- **Body** (regular / semibold, 13pt): cue names in the cue list.
- **Callout** (regular, 12pt): explanatory and error copy in not-ready and failed states.
- **Meta** (regular, subheadline 11pt, monospaced digits): device line, current-cue meta line, effect names in the cue list, footer status, help text.
- **Label** (medium, 11pt, 0.8pt tracking, uppercase): control row labels (LIGHTS, EFFECT, LEVEL, SPEED, FRAME GAP), the CUES list heading, and the cue lamp's state word (semibold).
- **Figures** (SF Mono regular, callout 12pt): slider readouts, cue-list levels, cue numbers in rows, the gel's H/S readout (semibold, subheadline).
- **Badge** (bold, caption2 10pt, 0.8pt tracking, uppercase): the OFF CUE badge only.

### Named Rules
**The Every Number Is Mono Rule.** Any numeric value the user reads (cue numbers, levels, speeds, hue/saturation, frame gap) is set in SF Mono or with monospaced digits, right-aligned in a fixed-width column when it sits in a row.

**The Rank by Weight Rule.** Inside the cue list, the current cue is distinguished by semibold weight, full paper brightness, and the raised fill. Never by a larger size.

## Layout

A single fixed-width column (340 pt) of full-bleed bands, top to bottom: header (device line + cue lamp), current cue block (or the not-ready block), controls, cue list, optional diagnostics, footer. Bands are separated by 1 px rule-blue hairlines that run edge to edge.

- **Insets:** 16 pt horizontal inset for header, cue block, controls, diagnostics, and footer. The cue list uses an 8 pt band inset plus 8 pt row padding so its selection fill can extend wider than the text column while text stays aligned at 16 pt.
- **Vertical rhythm:** 12 pt band padding for header, controls, and cue list; 16 pt for the cue block, not-ready block, and diagnostics; 10 pt for the footer. Control rows are spaced 10 pt apart with a 24 pt minimum height; cue rows sit 2 pt apart.
- **Label column:** control rows use a fixed 60 pt label column so every control starts on the same vertical line.
- **Figure columns:** slider readouts and cue-list levels sit in a 30 pt right-aligned column; the current cue number holds a 58 pt column.
- **Disabled bands:** when the keyboard isn't ready, the controls and cue list stay visible at 45% opacity and the cue block is replaced by a plain-language explanation of what's missing.

## Elevation & Depth

Flat. Depth is tonal: the shell is one blue, the current row is one step lighter (raised-blue), and hairline rules do the structuring. There are no surface shadows.

The only shadows are light, not elevation: the cue lamp's glow (a colored blur matched to the lamp state, 4 pt at rest, breathing to 7 pt while on standby), and a small dark text shadow (black 45%, 2 pt blur, 1 pt down) that keeps white figures legible on any gel color.

### Named Rules
**The Light, Not Lift Rule.** A shadow in KeyGlow is always emitted light (the lamp's glow) or a legibility halo on the gel. Nothing is lifted off the shell with a drop shadow.

## Shapes

Two small radii and hairline edges. Swatches and the OFF CUE badge use 3 pt corners; the gel chip and cue-row selection fill use 6 pt. Color surfaces (gel, swatches, lamp) carry a thin white edge (22–25% opacity, 0.5–1 pt) so black or near-shell colors stay visible against the blue. The cue lamp is the only circle.

## Components

### Cue Lamp (signature)
The panel's one live signal, top right. A 10 pt filled circle with a 0.5 pt white edge, followed by an uppercase tracked state word in semibold label type.
- **Idle:** rule-blue circle, no glow, word "IDLE" in dim-paper.
- **Standby:** standby-red with a glow that breathes (ease-in-out, 0.6 s, repeating) while a command is in flight; static under Reduce Motion.
- **Go:** go-green with a steady glow for about 4 s after a send lands.
- **Check:** attention-amber when the keyboard is missing, permission is off, the cable is in use, or the last send failed.
- State changes cross-fade over 0.35 s ease-out. Reads to VoiceOver as one element: "Keyboard link: [state]".

### Gel Chip
A full-width 46 pt color well showing the live color, its opacity scaled by level (35% at zero up to 100% at 255); pure black when lights are off. H and S readouts in semibold mono white, bottom left; a palette symbol top right. Clicking opens the system color panel, which sends when the pick settles.

### Current Cue Block
Large mono Q-number in a 58 pt column, then the cue name (title) with a mono-digit meta line beneath ("Breathing · level 200 · speed 128"). When the live look differs from the recorded cue, the Q-number dims, an OFF CUE badge appears beside the name, and a "Record to Q#" small button is offered.

### Cue Row
- **Shape:** 6 pt rounded selection fill, 6 × 8 pt padding.
- **Content:** mono Q-number (28 pt column), 14 pt swatch, cue name, effect name in dim meta type, mono level in a 30 pt right-aligned column.
- **Current:** raised-blue fill, semibold number and name, paper text.
- **Other rows:** paper at 82% opacity, no fill; hover adds raised-blue at 50%.
- **Behavior:** click recalls and sends the cue; number keys 1–4 recall directly; context menu records the current look into that cue.

### Control Rows
Uppercase tracked dim label in a 60 pt column, then a standard macOS control: small switch for Lights, a menu picker for Effect, small sliders for Level and Speed with mono readouts. Controls take the lift-blue tint; they are not restyled.

### Buttons
Native macOS buttons only. Small control size for in-flow actions ("Record to Q#", "Send again"); borderless buttons in the footer (diagnostics symbol, Quit); toggle-style buttons for diagnostic bits.

### Footer
Dim meta status on the left ("Ready", "Sending · n left", "Last send failed" in amber), borderless diagnostics symbol and Quit on the right.

## Do's and Don'ts

### Do:
- **Do** keep every surface on running-blue (#16205a) and separate bands with 1 px rule-blue hairlines.
- **Do** route every send through the cue lamp: standby-red while in flight, go-green when it lands, amber when something needs the user.
- **Do** set every number in SF Mono or monospaced digits, right-aligned in a fixed column.
- **Do** use native macOS controls tinted lift-blue (#6b80e2) instead of custom ones.
- **Do** mark the current cue with weight, brightness, and the raised-blue fill, not size.
- **Do** give color surfaces a thin white edge so dark gels stay visible on the shell.
- **Do** respect Reduce Motion: the standby pulse stops and the lamp holds steady.

### Don't:
- **Don't** use red, green, or amber for anything other than send/attention state.
- **Don't** add drop shadows to lift surfaces; the only glow is the lamp's light.
- **Don't** lay out looks as a grey Control Center tile grid.
- **Don't** show a value as the keyboard's current state when it's only what was last sent.
