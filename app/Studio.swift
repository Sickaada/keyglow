import SwiftUI
import AppKit

struct StudioEditor: View {
    @ObservedObject var kb: Keyboard
    @ObservedObject var sheet: CueSheet
    @ObservedObject var library: LibraryPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = Cue(id: 0, name: "Untitled animation", hue: 0.75, saturation: 0.8, level: 200, effect: 25, speed: 80, on: true, extra: [Tint(hue: 0.53, saturation: 0.85)])
    @State private var baseline: Cue? = nil
    @State private var undoStack: [Cue] = []
    @State private var redoStack: [Cue] = []
    @State private var playing = true
    @State private var visible = false
    @State private var slot = 0
    @State private var message = ""
    var snapshot = false
    private var ready: Bool { kb.found && kb.accessGranted && kb.transport == "Bluetooth" }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(StudioTheme.secondary)
                TextField("Animation name", text: $draft.name).textFieldStyle(.plain).font(.title3.weight(.semibold)).frame(maxWidth: 300)
                Spacer()
                Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(undoStack.isEmpty).help("Undo (⌘Z)").keyboardShortcut("z").accessibilityLabel("Undo")
                Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(redoStack.isEmpty).help("Redo (⇧⌘Z)").keyboardShortcut("z", modifiers: [.command,.shift]).accessibilityLabel("Redo")
                Divider().frame(height: 20)
                Button {
                    sheet.create(draft.name, from: draft); message = "Saved to your presets."
                } label: { Label("Save preset", systemImage: "square.and.arrow.down") }
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Apply to keyboard") {
                    sheet.live = draft; sheet.currentID = nil; sheet.persist(); sheet.noteSubmission(); kb.sendLook(draft)
                    message = "Queued for the keyboard."
                }.buttonStyle(.borderedProminent).disabled(!ready)
            }.controlSize(.regular).padding(20)
            Divider().overlay(StudioTheme.border)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("K3 Pro").font(.headline)
                        Text("ANSI · 84 keys").font(.callout).foregroundStyle(StudioTheme.secondary)
                        Spacer()
                        Text("Preview").font(.caption).foregroundStyle(StudioTheme.secondary)
                    }
                    Spacer()
                    KeyboardPreview(cue: draft, selectedZone: [22,23].contains(draft.effect) ? slot : nil,
                                    tapZone: { slot = $0 }, active: visible && playing,
                                    fixedTime: snapshot ? 2.4 : nil)
                    Spacer()
                    HStack {
                        Button { playing.toggle() } label: { Label(playing ? "Pause preview" : "Play preview", systemImage: playing ? "pause.fill" : "play.fill") }
                        Spacer()
                        Text(reduceMotion ? "Reduce Motion is on" : "Motion is an approximation")
                            .font(.caption).foregroundStyle(StudioTheme.secondary)
                    }
                }.padding(24).frame(maxWidth: .infinity)
                Divider().overlay(StudioTheme.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Animation properties").font(.headline)
                        Picker("Pattern", selection: Binding(get: { draft.effect }, set: { e in
                            draft.effect = e; slot = 0; draft.ensureSeveral(); checkpoint()
                        })) {
                            Text("Split zones").tag(22); Text("Gradient").tag(23)
                            Text("Color fade").tag(24); Text("Color wave").tag(25)
                        }
                        Text(patternDescription).font(.callout).foregroundStyle(StudioTheme.secondary).fixedSize(horizontal: false, vertical: true)
                        LightingControls(cue: $draft, library: library, changed: { _ in checkpoint() }, showEffect: false, compact: true, selectedSlot: $slot)
                        if !ready { Text("Connect over Bluetooth and allow KeyGlow in Input Monitoring to apply this look.").font(.caption).foregroundStyle(StudioTheme.secondary) }
                    }.padding(20)
                }.frame(width: 320)
            }.frame(maxHeight: .infinity)
            Divider().overlay(StudioTheme.border)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(draft.effect == 22 ? "Color regions" : "Color sequence").font(.headline)
                    Spacer()
                    Text(draft.effect >= 24 ? "Continuous loop · Linear blending" : draft.effect == 23 ? "Left to right · Linear blending" : "Left to right · Fixed regions")
                        .font(.callout).foregroundStyle(StudioTheme.secondary)
                }
                HStack(spacing: 2) {
                    ForEach(0..<draft.colorCount, id: \.self) { i in
                        let t = draft.tints[min(i, draft.tints.count - 1)]
                        Button { slot = i } label: {
                            HStack {
                                Circle().fill(t.color).frame(width: 12, height: 12)
                                Text(slotRoles(effect: draft.effect, count: draft.colorCount)[i])
                                Spacer()
                                Text(t.hex(level: draft.level)).font(.system(.caption, design: .monospaced)).foregroundStyle(StudioTheme.secondary)
                            }.padding(12)
                        }.buttonStyle(StudioButton(selected: slot == i))
                    }
                }
                Text("This editor uses your keyboard's existing palette effects. Per-key painting, timeline keyframes and layers need a separate firmware upgrade.")
                    .font(.caption).foregroundStyle(StudioTheme.secondary)
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(StudioTheme.secondary) }
            }.padding(20)
        }
        .frame(minWidth: 920, idealWidth: 920, minHeight: 640, idealHeight: 640)
        .background(StudioTheme.background).foregroundStyle(StudioTheme.text)
        .environment(\.colorScheme, .dark).tint(.white.opacity(0.88))
        .background(WindowVisibility(visible: $visible).frame(width: 0, height: 0))
        .onAppear {
            sheet.observeSending(kb)
            if baseline == nil {
                draft = Self.makeDraft(from: sheet.live)
                baseline = draft
            }
        }
        .onDisappear { visible = false }
        .onChange(of: kb.lastSend) { _, state in
            if state == .failed { message = "Send failed: \(kb.message)" }
            else if state == .ok { message = "Commands sent. Check the keyboard to confirm the look." }
        }
    }
    static func makeDraft(from current: Cue) -> Cue {
        var draft = current.use == .several ? current : Cue(id: 0, name: "Untitled animation", hue: 0.75, saturation: 0.8, level: 200, effect: 25, speed: 80, on: true, extra: [Tint(hue: 0.53, saturation: 0.85)])
        if current.use == .several { draft.name = String((current.name + " animation").prefix(100)) }
        draft.on = true
        if draft.level < 48 { draft.level = 200 }
        draft.ensureSeveral()
        return draft
    }
    private var patternDescription: String {
        switch draft.effect {
        case 22: "Two or three fixed regions. Click a region on the keyboard to choose its color."
        case 23: "A smooth blend across the keyboard. Select a color stop to adjust it."
        case 24: "The whole keyboard fades through your colors, then repeats."
        default: "Your colors flow from right to left across the keyboard."
        }
    }
    private func checkpoint() {
        if let baseline, baseline != draft { undoStack.append(baseline); if undoStack.count > 100 { undoStack.removeFirst() }; redoStack = [] }
        baseline = draft
    }
    private func undo() { guard let c = undoStack.popLast() else { return }; redoStack.append(draft); draft = c; baseline = c; slot = 0 }
    private func redo() { guard let c = redoStack.popLast() else { return }; undoStack.append(draft); draft = c; baseline = c; slot = 0 }
}
