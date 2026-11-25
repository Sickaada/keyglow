import SwiftUI
import AppKit
import OSLog

private let interactionLog = Logger(subsystem: "local.keyglow", category: "interaction")

struct Panel: View {
    @ObservedObject var kb: Keyboard
    @ObservedObject var sheet: CueSheet
    @ObservedObject var library: LibraryPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow
    @State var tab = 0
    @State private var visible = false
    @State private var contentHeight: CGFloat = 250
    @State private var settings = false
    @State private var signal = false
    @State private var bits = [false, false, false, false]
    @State private var notice = ""
    @State private var name = ""
    @State var naming = false
    @FocusState private var nameFocused: Bool
    @State private var renameID: Int? = nil
    @State private var deleteID: Int? = nil
    @State private var actionRevision = 0
    @State private var favoritesOnly = false
    var snapshot = false
    private var ready: Bool { kb.found && kb.accessGranted && kb.transport == "Bluetooth" }
    private var accent: Color { sheet.live.on ? sheet.live.color : .gray }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(20)
            Divider().overlay(StudioTheme.border)
            VStack(spacing: 12) {
                KeyboardPreview(cue: sheet.live, active: visible, fixedTime: snapshot ? 2.4 : nil)
                    .accessibilityLabel("K3 Pro, 84 keys. Selected lighting preview, \(sheet.live.effectName)")
                HStack {
                    Text(sheet.live.effectName).font(.callout.weight(.medium))
                    Spacer()
                    Text("Effect preview · Approximate").font(.caption).foregroundStyle(StudioTheme.secondary)
                }
                if sheet.live.reactive {
                    Text("Sample typing shown. KeyGlow never reads your keystrokes.").font(.caption).foregroundStyle(StudioTheme.secondary)
                }
                if !ready { connectionHelp }
                Picker("Studio section", selection: $tab) {
                    Text("Lighting").tag(0); Text("Animations").tag(1); Text("Presets").tag(2)
                }.pickerStyle(.segmented).labelsHidden()
            }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 16)
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case 1: animationLibrary
                    case 2: presetLibrary
                    default: LightingControls(cue: $sheet.live, library: library, changed: change)
                    }
                }.padding(.horizontal, 20).padding(.bottom, 20)
                .background(GeometryReader { g in Color.clear.preference(key: ContentHeight.self, value: g.size.height) })
            }
            .onChange(of: actionRevision) { _, _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { proxy.scrollTo("preset-actions", anchor: .top) }
            }
            }.frame(height: tab == 0 ? min(340, max(170, contentHeight)) : 306)
            .onPreferenceChange(ContentHeight.self) { contentHeight = $0 }
            Divider().overlay(StudioTheme.border)
            footer.padding(.horizontal, 20).padding(.vertical, 12)
        }
        .frame(width: 440)
        .background(.ultraThinMaterial)
        .background(StudioTheme.background)
        .foregroundStyle(StudioTheme.text)
        .environment(\.colorScheme, .dark)
        .tint(.white.opacity(0.88))
        .background(WindowVisibility(visible: $visible).frame(width: 0, height: 0))
        .onAppear { sheet.observeSending(kb) }
        .onDisappear { visible = false }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)

    }
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard").font(.system(size: 24, weight: .light))
                .foregroundStyle(StudioTheme.secondary)
            VStack(alignment: .leading, spacing: 5) {
                Text("Keychron Lighting Studio").font(.system(size: 15, weight: .semibold))
                HStack(spacing: 5) {
                    Circle().fill(kb.found ? Color.green : Color.gray).frame(width: 5, height: 5)
                    Text(kb.found ? "K3 Pro · \(kb.transport)" : "K3 Pro · Not connected")
                        .font(.caption).foregroundStyle(StudioTheme.secondary)
                }
            }
            Spacer(minLength: 4)
            Toggle("Master lighting", isOn: Binding(get: { sheet.live.on }, set: { on in
                sheet.live.on = on; sheet.persist()
                if ready { sheet.noteSubmission(); kb.sendLook(sheet.live) }
            })).labelsHidden().toggleStyle(.switch).controlSize(.small)
            Button { settings.toggle() } label: { Image(systemName: "gearshape").font(.body) }
                .buttonStyle(.borderless).help("Settings and diagnostics").accessibilityLabel("Settings and diagnostics")
                .popover(isPresented: $settings, arrowEdge: .top) {
                    ScrollView { diagnostics.padding(20) }.frame(width: 400, height: 370)
                        .background(StudioTheme.background).foregroundStyle(StudioTheme.text)
                        .environment(\.colorScheme, .dark)
                }
        }
    }
    private var connectionHelp: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(!kb.found ? "Connect your K3 Pro over Bluetooth to apply lighting." : !kb.accessGranted ? "Allow KeyGlow in Input Monitoring to apply lighting." : "Switch the keyboard to Bluetooth to apply lighting.")
                    .fixedSize(horizontal: false, vertical: true)
                if kb.found && !kb.accessGranted {
                    Button("Open Input Monitoring…") { kb.requestAccess() }.buttonStyle(.link)
                }
            }
        }.font(.caption).foregroundStyle(StudioTheme.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var animationLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Effects").font(.headline)
                Text("\(effects.count)").font(.caption).foregroundStyle(StudioTheme.secondary)
                Spacer()
                Button { openWindow(id: "studio"); NSApp.activate(ignoringOtherApps: true) } label: {
                    Label("Create Animation", systemImage: "plus")
                }.controlSize(.small)
            }
            Text("Choose an effect to apply. Hover to preview motion.")
                .font(.caption).foregroundStyle(StudioTheme.secondary)
            DisclosureGroup("Adjust \(sheet.live.effectName)") {
                LightingControls(cue: $sheet.live, library: library, changed: change, showEffect: false).padding(.top, 12)
            }.font(.callout)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(effects.indices, id: \.self) { i in
                    EffectCard(effect: i, current: sheet.live, selected: sheet.live.effect == i, active: visible && !snapshot) {
                        interactionLog.notice("Effect card selected: \(i, privacy: .public)")
                        sheet.live.effect = i
                        if sheet.live.use == .several { sheet.live.ensureSeveral() }
                        change(.effect)
                    }
                }
            }
        }
    }
    private var presetLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your presets").font(.headline)
                Spacer()
                Button { favoritesOnly.toggle() } label: { Image(systemName: favoritesOnly ? "star.fill" : "star") }
                    .buttonStyle(.borderless).help("Filter favorites").accessibilityLabel("Filter favorite presets")
                Button { startNaming(nil) } label: { Label("Save current", systemImage: "plus") }.controlSize(.small)
                Menu {
                    Button("Import presets…") { PresetFiles.load(into: sheet) { notice = $0 } }
                    Button("Export all presets…") { PresetFiles.export(sheet.cues) { notice = $0 } }.disabled(sheet.cues.isEmpty)
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 20)
                    .accessibilityLabel("Import and export presets")
            }
            Color.clear.frame(height: 0).id("preset-actions")
            if naming {
                VStack(alignment: .leading, spacing: 10) {
                    Text(renameID == nil ? "Name this preset" : "Rename preset").font(.callout.weight(.medium))
                    TextField("Preset name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                        .onSubmit(savePreset)
                        .accessibilityLabel("Preset name")
                        .onAppear { nameFocused = true }
                    HStack {
                        Text("Saved on this Mac").font(.caption).foregroundStyle(StudioTheme.secondary)
                        Spacer()
                        Button("Cancel") { naming = false; nameFocused = false }.controlSize(.small)
                        Button("Save", action: savePreset).controlSize(.small).buttonStyle(.borderedProminent)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(12).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
            if let id = deleteID, let cue = sheet.cues.first(where: { $0.id == id }) {
                HStack {
                    Text("Delete \(cue.name)?").font(.callout).lineLimit(1)
                    Spacer()
                    Button("Cancel") { deleteID = nil }.controlSize(.small)
                    Button("Delete", role: .destructive) { sheet.remove(id); library.forgetFavorite(id); deleteID = nil }.controlSize(.small)
                }.padding(12).background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
            if !notice.isEmpty { Text(notice).font(.caption).foregroundStyle(StudioTheme.secondary).accessibilityLabel(notice) }
            let displayed = sheet.cues.filter { !favoritesOnly || library.favorites.contains($0.id) }
            if displayed.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: favoritesOnly ? "star" : "square.stack").font(.title2)
                    Text(favoritesOnly ? "No favorites yet" : "Make this look yours").font(.headline)
                    Text(favoritesOnly ? "Use the star on a preset to keep it here." : "Save your current lighting to start your collection.")
                        .font(.callout).foregroundStyle(StudioTheme.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(displayed) { cue in
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            sheet.live = cue; sheet.currentID = cue.id; sheet.persist()
                            if ready { sheet.noteSubmission(); kb.sendLook(cue) }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                KeyboardPreview(cue: cue, active: false, miniature: true, fixedTime: 2.4).allowsHitTesting(false)
                                Text(cue.name).font(.callout.weight(.medium)).lineLimit(1)
                                Text(cue.on ? cue.effectName : "Lights off").font(.caption).foregroundStyle(StudioTheme.secondary).lineLimit(1)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityLabel("Apply \(cue.name)")
                        HStack {
                            Button { library.favorite(cue.id) } label: { Image(systemName: library.favorites.contains(cue.id) ? "star.fill" : "star") }
                                .buttonStyle(.borderless).help("Favorite").accessibilityLabel("Favorite \(cue.name)")
                            Spacer()
                            Menu {
                                Button("Rename…") { startNaming(cue) }
                                Button("Update with current look") { sheet.saveLive(into: cue.id) }
                                Button("Duplicate") { sheet.create(cue.name + " copy", from: cue) }
                                Button("Export…") { PresetFiles.export([cue]) { notice = $0 } }
                                Divider()
                                Button("Delete…", role: .destructive) { startDeleting(cue.id) }
                            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22)
                                .accessibilityLabel("Manage \(cue.name)")
                        }.font(.caption).foregroundStyle(StudioTheme.secondary).padding(.horizontal, 12).padding(.bottom, 10)
                    }.background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(sheet.currentID == cue.id && !sheet.edited ? Color.white.opacity(0.65) : .clear, lineWidth: 1))
                }
            }
        }
    }
    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack { Text("Diagnostics").font(.headline); Spacer(); Button("Close") { settings = false }.controlSize(.small) }
            Text("KeyGlow sends lighting commands only. It does not read your typing. Animation previews are approximate; the keyboard does not report its lighting state.")
                .font(.caption).foregroundStyle(StudioTheme.secondary)
            HStack {
                Button("Flash white") { kb.send(.ping) }
                Button("Show battery on keys") { kb.send(.battery); notice = "Battery level is shown on the keyboard, when running on battery." }
            }.controlSize(.small).disabled(!ready)
            Toggle("Signal view (Fn + V)", isOn: $signal)
                .onChange(of: signal) { _, on in if ready { kb.send(.view, on ? 1 : 0) } }.disabled(!ready)
            HStack {
                ForEach(0..<4, id: \.self) { i in Toggle(["Num", "Scroll", "Compose", "Kana"][i], isOn: $bits[i]).toggleStyle(.button).controlSize(.small) }
            }.disabled(!ready).onChange(of: bits) { _, b in if ready { kb.sendRaw(num: b[0], scroll: b[1], compose: b[2], kana: b[3]) } }
            HStack {
                Text("Frame gap").font(.callout)
                Slider(value: $kb.frameMs, in: 8...60, step: 1)
                Text("\(Int(kb.frameMs)) ms").font(.caption.monospacedDigit()).frame(width: 40)
            }
            if kb.lastSend == .failed { Text(kb.message).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            if !notice.isEmpty { Text(notice).font(.caption).foregroundStyle(StudioTheme.secondary) }
        }
    }
    private var footer: some View {
        HStack(spacing: 8) {
            if kb.sending { ProgressView().controlSize(.mini) }
            else { Image(systemName: kb.lastSend == .failed ? "exclamationmark.circle" : "wave.3.right").font(.caption) }
            Text(statusText)
                .font(.caption).foregroundStyle(StudioTheme.secondary)
            Spacer(minLength: 0)
            if kb.lastSend == .failed {
                Button("Retry") { if ready { sheet.noteSubmission(); kb.sendLook(sheet.live) } }.buttonStyle(.borderless).disabled(!ready)
                    .help(kb.message)
            }
            if ready && kb.lastSend != .failed {
                Button("Apply") { sheet.noteSubmission(); kb.sendLook(sheet.live) }.buttonStyle(.borderless).font(.caption).disabled(kb.sending)
                    .help("Reapply the selected look")
            }
            Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless).font(.caption).keyboardShortcut("q")
        }
        .help(kb.lastSend == .failed ? kb.message : "Previews update immediately. Bluetooth commands take about two seconds each. Sent is not an acknowledgement from the keyboard.")
    }
    private func startNaming(_ cue: Cue?) {
        interactionLog.notice("Preset name form requested")
        deleteID = nil; renameID = cue?.id; name = cue?.name ?? "New look"
        naming = true; actionRevision += 1
    }
    private func startDeleting(_ id: Int) {
        naming = false; nameFocused = false; renameID = nil
        deleteID = id; actionRevision += 1
    }
    private func savePreset() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if let id = renameID {
            guard sheet.cues.contains(where: { $0.id == id }) else {
                notice = "This preset no longer exists. Save your current look as a new preset."
                naming = false; nameFocused = false; return
            }
            sheet.rename(id, to: clean)
        }
        else {
            sheet.currentID = sheet.create(clean)
            sheet.persist()
            favoritesOnly = false
        }
        interactionLog.notice("Preset save completed; total: \(sheet.cues.count, privacy: .public)")
        notice = "Saved “\(String(clean.prefix(100)))”."
        naming = false; nameFocused = false
    }
    private var statusText: String {
        if !kb.found { return "Preview only · Connect to apply" }
        if !kb.accessGranted { return "Input Monitoring permission needed" }
        if kb.transport != "Bluetooth" { return "Switch to Bluetooth to apply" }
        if kb.sending { return "Sending · \(max(kb.inFlight, 1)) remaining" }
        if kb.lastSend == .failed { return "Send failed · Open settings" }
        if sheet.needsApply { return sheet.lastSubmitted == nil && !sheet.edited ? "Ready to apply" : "Changes waiting to apply" }
        return "Commands sent"
    }
    private func change(_ event: LightingControls.ControlChange) {
        sheet.persist()
        guard ready, sheet.live.on else {
            interactionLog.notice("Lighting selection kept local: ready=\(ready, privacy: .public), power=\(sheet.live.on, privacy: .public)")
            return
        }
        if sheet.requiresFullSubmission(for: event) {
            sheet.noteSubmission(); kb.sendLook(sheet.live); return
        }
        sheet.noteSubmission()
        switch event {
        case .effect:
            if sheet.live.use == .several { kb.sendColor2(sheet.live); kb.sendColor3(sheet.live) }
            kb.sendEffect(sheet.live.effect)
        case .palette:
            kb.sendColor(sheet.live)
            if sheet.live.use == .several { kb.sendColor2(sheet.live); kb.sendColor3(sheet.live) }
        case .brightness: kb.sendColor(sheet.live)
        case .speed: kb.sendSpeed(sheet.live.speed)
        }
    }
}

struct EffectCard: View {
    let effect: Int
    let current: Cue
    let selected: Bool
    let active: Bool
    var action: () -> Void
    @State private var hover = false
    private var sample: Cue {
        var c = current; c.effect = effect; c.on = true
        if c.use == .several { c.ensureSeveral() }; return c
    }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                KeyboardPreview(cue: sample, active: active && (hover || selected), miniature: true).allowsHitTesting(false)
                HStack {
                    Text(effectNames[effect]).font(.callout.weight(.medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    if selected { Image(systemName: "checkmark.circle.fill").font(.caption) }
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(StudioButton(selected: selected)).onHover { hover = $0 }
        .accessibilityLabel("\(effectNames[effect])\(selected ? ", selected" : "")")
    }
}

private struct ContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 250
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
