---
name: Keychron Lighting Studio
description: Native graphite lighting controls around a black K3 Pro and its emitted light.
colors:
  background: "#141518"
  surface: "#1c1d21"
  elevated: "#25262b"
  border: "#303137"
  text: "#f5f5f7"
  secondary: "#a3a3ac"
  control-tint: "rgba(255,255,255,0.88)"
  selection-edge: "rgba(255,255,255,0.65)"
  swatch-edge: "rgba(255,255,255,0.25)"
  cap-top: "rgb(10.5% 10.8% 12%)"
  cap-bottom: "rgb(5.5% 5.8% 6.5%)"
  legend-off: "rgb(45% 47% 55%)"
typography:
  panel-title:
    fontFamily: "SF Pro"
    fontSize: "15pt"
    fontWeight: 600
  editor-title:
    fontFamily: "SF Pro"
    fontWeight: 600
  headline:
    fontFamily: "SF Pro"
  body:
    fontFamily: "SF Pro"
  callout:
    fontFamily: "SF Pro"
  card-label:
    fontFamily: "SF Pro"
    fontWeight: 500
  caption:
    fontFamily: "SF Pro"
  hex:
    fontFamily: "SF Mono"
rounded:
  studio: "12pt"
spacing:
  tight: "2pt"
  inline: "8pt"
  control: "10pt"
  inset: "12pt"
  section: "16pt"
  panel: "20pt"
  canvas: "24pt"
components:
  panel:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text}"
    width: "440pt"
  studio-button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.studio}"
  studio-button-selected:
    backgroundColor: "{colors.elevated}"
    textColor: "{colors.text}"
    rounded: "{rounded.studio}"
  effect-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.studio}"
    padding: "12pt"
  preset-edit-form:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.studio}"
    padding: "12pt"
  preset-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.studio}"
  palette-slot:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.studio}"
    padding: "7pt 9pt"
  hex-field:
    typography: "{typography.hex}"
    width: "88pt"
  navigation:
    textColor: "{colors.text}"
  color-swatch:
    size: "21pt"
  diagnostics-popover:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text}"
    width: "400pt"
    height: "370pt"
    padding: "20pt"
  status-footer:
    textColor: "{colors.secondary}"
    typography: "{typography.caption}"
    padding: "12pt 20pt"
  keyboard-preview:
    backgroundColor: "{colors.cap-top}"
---

# Design System: Keychron Lighting Studio

## Overview

**Creative North Star: "Keychron Lighting Studio"**

Keychron Lighting Studio is a quiet native macOS utility centered on the black K3 Pro keyboard and its emitted light. Graphite surfaces, SF Pro, restrained native material, and familiar controls support the hardware visualization. This explicitly replaces the former Cue Sheet identity.

The menu panel supports quick adjustments and a visual effects/preset library. The separate editor gives existing palette effects more room without implying per-key painting, timeline keyframes, layers, or hardware readback. RGB communicates the selected lighting; neutral controls stay legible around it.

**Key Characteristics:**
- Graphite shell with native ultra-thin material in the menu panel.
- Black keycaps, illuminated legends, inter-key emission, and soft under-light.
- Native SF Pro hierarchy and SF Symbols, including the keyboard header icon.
- Shared rounded selection controls and two-column visual libraries.
- Explicit approximate-preview, waiting-to-apply, sending, and failure language; motion respects visibility and Reduce Motion.

Evidence: `mac/KeyGlow/Theme.swift`, `Panel.swift`, `Controls.swift`, `Studio.swift`, and `KeyboardPreview.swift`, with submission-state behavior checked in `Models.swift`; direction in `.impeccable/surfaces/mac-keyglow-panel-swift.md`; capability context in `PRODUCT.md` and `docs/STUDIO-AUDIT.md`. The initial pass inspected `lighting.png` and `studio.png` under `.impeccable/review/studio/` as offline fixtures, not hardware validation. The preset-form refresh checks current `Panel.swift` and `.impeccable/review/studio/save-preset.png`, an offline fixture showing the inline name form and disabled empty-name Save state. Rename, delete confirmation, and saved-notice behavior are documented from source; installation and interactive save success are not verified here. Current PRODUCT.md identifies macOS 14+ and 26 effects. The replacement is explicitly authorized; the prior design is backed up at `.keyglow-backup/pre-studio/DESIGN.md`.

## Colors

Graphite neutrals frame freely chosen keyboard light. Frontmatter colors are the code values, not sampled composites from translucent screenshots.

### Primary
- **Control tint:** translucent white applied through SwiftUI tint to native controls.
- **Selected lighting:** dynamic cue colors, not a fixed brand accent. Swatches and previews reflect effect content.

### Neutral
- **Background:** root panel backing and editor canvas.
- **Surface / elevated:** resting and selected StudioButton fills; preset cards retain the surface fill when selected.
- **Border:** quiet header, footer, and editor dividers.
- **Text / secondary:** main labels and subdued metadata, help, and readouts.
- **Selection edge:** selected cards, palette slots, and editor zone outlines.
- **Swatch edge:** fine white boundary around color circles.
- **Cap top / bottom / legend off:** the keyboard's unlit base materials; effect math introduces only a small tint into cap faces.

Connection uses native green or gray; validation and low-brightness messages use native orange. These platform colors are not fixed hexadecimal brand tokens.

**The Light Belongs to the Keyboard Rule.** Keep the shell graphite and controls neutral; use free RGB for lighting previews and palette selections. Native connection and warning colors remain valid semantic exceptions.

## Typography

**Interface font:** SF Pro through SwiftUI system styles. **HEX font:** system monospaced design (SF Mono). There is no separate decorative display face.

The explicit panel title is the frontmatter `panel-title`. The editor name uses `.title3.weight(.semibold)`; section headings use `.headline`; effect names and card labels use `.callout.weight(.medium)`; field labels use body/callout; status, helper copy, metadata, and palette slots use `.caption`. Semantic point sizes and line heights are left to macOS rather than invented as fixed tokens. Percentage readouts use callout with monospaced digits; diagnostics use caption with monospaced digits; HEX fields use monospaced callout and sequence HEX uses monospaced caption. Text uses normal case, except the functional HEX acronym and hardware legends.

**The Native Type Rule.** Use SF Pro semantic styles for native interface text, monospaced digits for numeric readouts, and monospaced text for HEX. Do not inherit Cue Sheet uppercase tracking or an every-number-is-SF-Mono rule.

## Layout

The menu panel is fixed at 440 pt. Header and horizontal content insets are 20 pt; preview/tab band has 16 pt vertical padding and 12 pt internal gaps. The header contains a 24 pt light-weight keyboard SF Symbol, title, connection line with a 5 pt status dot, power switch, and settings action. The preview leads into Lighting / Animations / Presets segmented navigation; contextual content scrolls above a persistent footer.

Lighting scroll height follows measured content clamped to 170–340 pt. Libraries use a 306 pt viewport and two flexible columns with 10 pt gaps. Effect cards have 12 pt padding; preset card content also has 12 pt padding. The footer uses 20 pt horizontal and 12 pt vertical insets. Settings opens a separate 400 × 370 pt scrolling popover anchored to the gear button with a top arrow edge and 20 pt content padding; diagnostics no longer occupies the tab content area. The build mixes 2, 8, 10, 12, 16, 20, and 24 pt spacing; it does not implement a strict 8-point grid despite the direction's shorthand.

The editor has a minimum and ideal size of 920 × 640 pt, an expanding preview pane with 24 pt padding, a 320 pt scrolling properties pane with 20 pt padding, and a full-width color sequence/region strip. It grows with the window; no responsive breakpoint system is implemented.

Palette presets use 13 columns in the panel and 8 in the compact editor, with 2 pt column gaps and 6 pt row gaps. Slider rows have an 18 pt icon column, 66 pt label column, flexible slider, and 34 pt trailing percentage column, separated by 10 pt gaps.

## Elevation & Depth

The panel places `.ultraThinMaterial` over the graphite backing and forces dark appearance. The editor uses the opaque graphite background. Actual native material and control rendering depends on the operating system; no fixed blur radius is asserted. Cards use tonal fills and selected outlines rather than custom drop shadows.

The Canvas keyboard has an aluminum frame gradient, fine highlighted edges, dark cap gradients, blurred emission between keys, and a diffuse light pool underneath. With `u = preview width / 17.12`, inter-key emission blur is `0.22u`; under-light blur is `0.9u` with 0.75 pool opacity. These are light effects, not generic card elevations.

**The Emitted Light Rule.** Keep keycaps black while light appears between keys, through legends, and beneath the keyboard. Surface hierarchy comes from graphite tones, thin boundaries, and native material.

## Shapes

StudioButton, effect cards, preset cards, and color slots share the 12 pt corner radius. Selected StudioButtons use elevated fill and a 1 pt selection edge; preset selection uses that edge while retaining surface fill. Swatches are circles: 21 pt presets and 15 pt recent colors, 3 pt padding, a 0.5 pt inner edge, and a 1.5 pt white selection ring. Native fields, pickers, switches, and segmented controls retain platform geometry.

Keyboard geometry scales with `u`: frame radius 0.38u, cap radius 0.14u, key gaps 0.1u. The 84-key layout has six rows and a 16-unit key field; full aspect ratio is 17.12 / 7.42. Active Split/Gradient zones have a 1 pt dashed selection outline with a 4/3 pt dash pattern. Small card previews omit legends.

## Components

### Buttons and selection slots

StudioButton is a quiet rounded surface with a neutral selected edge. Pressing reduces opacity to 0.75. Palette slot buttons combine a 10 pt color dot and caption label. Editor sequence buttons use 12 pt padding and a 12 pt dot. Standard toolbar buttons use native styles; Apply to keyboard is native bordered-prominent and disabled when connection requirements are unmet. Borderless icon actions use SF Symbols and accessibility labels. No custom hover tint or focus geometry is defined for StudioButton; retain native keyboard focus behavior.

### Inputs and color controls

Native menu pickers, sliders, switch, and ColorPicker carry the shared neutral tint. HEX uses a native rounded-border field with an 88 pt width, explicit apply action, and inline orange validation. The editor name is a plain title3 text field. Circular preset/recent swatches and named two/three-color slots expose palette editing; effects that own their colors show explanatory text instead. Speed is conditional on animation. Brightness and speed are displayed as percentages over the underlying 0–255 values. The HEX input and editor sequence HEX labels both represent RGB at the current global brightness; applying HEX updates that brightness for the whole keyboard. Palette/recent swatches continue to represent hue/saturation rather than a darkened brightness sample.

### Navigation and libraries

The panel uses one native segmented control for Lighting, Animations, and Presets. Effect cards pair a miniature keyboard with the effect name and a selected checkmark. Selected or hovered effect cards animate only when the panel is active; hover does not introduce a new chrome color. Preset cards contain a static miniature, name, effect, favorite action, and management menu. Current presets receive an outline only when the current look is unedited; this indicates local selection, not hardware confirmation. Deleting a preset also removes its favorite membership. Empty libraries use an SF Symbol, headline, and short explanation.

### Inline preset forms

Save current opens a form immediately below the Presets toolbar and above the cards. Rename uses the same form, prefilled with the preset name and headed “Rename preset” instead of “Name this preset.” The form uses the existing surface fill, 12 pt radius and padding, and 10 pt vertical spacing. Its title is medium callout; the name input is a native rounded-border TextField that requests focus on appearance and submits on Return. The bottom row pairs secondary caption “Saved on this Mac” with small native Cancel and bordered-prominent Save buttons. Save is disabled for a whitespace-only name; Cancel closes the form without saving.

Delete opens an inline confirmation row above the cards with the preset name, Cancel, and a native destructive Delete action, using the same surface, radius, and padding. These preset actions do not use modal alerts. This is a Presets interaction pattern, not a ban on native dialogs elsewhere.

After save or rename, the form closes and a secondary caption notice, `Saved “<name>”.`, appears above the cards. Creating a preset clears the favorites-only filter so the saved item remains available in the list. Notice placement also applies to import/export feedback. The form and confirmation remain inside the existing scrolling library viewport; they do not increase the panel width or create a separate overlay.

### Keyboard preview and editor

The same Canvas drawing appears at panel, miniature, and editor scales. Its black caps and emitted light are the signature component. Preview motion uses a 30 fps maximum scheduling rate and pauses for inactive/hidden views, static effects, fixed-time fixtures, and Reduce Motion. Tab changes use ease-in-out over 0.18 seconds unless Reduce Motion is enabled. The editor supports Split zones, Gradient, Color fade, and Color wave with palette, brightness, and applicable speed controls; zone selection is available for Split/Gradient. Play/pause, undo/redo, save, and explicit apply are native actions. The editor shares a selected color slot across properties, the sequence strip, and applicable keyboard regions; reducing color count clamps that shared selection. A new editor draft starts with lighting enabled and raises brightness below 48/255 to 200/255 so an off or dim source look does not produce a blank editing preview. This changes the local draft, not the keyboard until Apply.

### Settings popover

Diagnostics lives in the anchored, dark graphite popover. It retains native actions and controls, a headline with Close, caption help, and orange wrapped send-error detail. Hardware actions remain disabled when readiness requirements are unmet. The popover reuses existing typography, spacing, and colors rather than creating a separate visual theme.

### Status

Use the keyboard SF Symbol in the device header and native progress/status symbols in the footer. The connection dot indicates discovery, not proof of permission or Bluetooth readiness. The panel caption explicitly reads “Effect preview · Approximate.” Footer copy distinguishes missing device, Input Monitoring permission, non-Bluetooth transport, sending with remaining count, failure, ready, waiting-to-apply, and commands sent. Controls and preview show the selected look; newer edits can differ from the look associated with the last successfully completed submission. “Changes waiting to apply” preserves that distinction. Commands sent is not delivery acknowledgement. A borderless caption-sized Apply action appears when ready and not failed, and is disabled during sending; failure presents Retry instead. Quit remains available. Reactive previews use sample typing and do not read keystrokes.

Sidecar HTML/CSS components are isolated browser illustrations of these native patterns, not replacement implementations or pixel-exact macOS control specifications. Generated tonal ramps are panel visualization aids, not additional shipped palette tokens.

## Do's and Don'ts

### Do:
- Do keep the black keyboard and its emitted light as the visual centerpiece.
- Do reuse native controls and SF Symbols for interface actions.
- Do distinguish selected palette slots and cards with neutral outlines and tonal fills.
- Do show only color and speed controls supported by the selected effect.
- Do distinguish the selected look from completed submissions, and retain approximate-preview, waiting-to-apply, sending, failure, and permission explanations.
- Do pause preview clocks when hidden, inactive, or Reduce Motion is enabled.

### Don't:
- Don't restore the blue Cue Sheet shell, cue lamp, or tracked uppercase section labels.
- Don't turn keycaps into solid RGB tiles; preserve the dark physical cap surface.
- Don't describe a preview or successful write as confirmed keyboard state.
- Don't present the existing palette editor as per-key painting, keyframes, or layers.

Not canonized or repaired: the reported unresponsive alert-based save flow is superseded by inline forms, not retained as a design pattern. Source and the save-form fixture establish the new presentation; installed-app interaction and hardware outcomes remain outside this pass’s verification. The former PRODUCT.md platform/effect-count drift is resolved. Offline fixture appearance is not evidence of hardware correctness or an accessibility review. Keyboard legend glyphs represent the physical key markings, not a general-purpose UI icon system.
