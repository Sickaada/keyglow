// KeyGlow menu bar panel: the Cue Sheet.
// Every look is a numbered cue; every send is a stage call (standby, then go).
import SwiftUI
import AppKit

// MARK: - Palette (backstage running light)

enum Stage {
    static let blue      = Color(red: 0.086, green: 0.125, blue: 0.353)   // #16205a shell
    static let raised    = Color(red: 0.118, green: 0.169, blue: 0.439)   // #1e2b70 selected row
    static let rule      = Color(red: 0.184, green: 0.235, blue: 0.525)   // #2f3c86 hairlines
    static let lift      = Color(red: 0.420, green: 0.502, blue: 0.886)   // #6b80e2 native control accent
    static let paper     = Color(red: 0.933, green: 0.945, blue: 0.969)   // #eef1f7 primary text
    static let dim       = Color(red: 0.639, green: 0.675, blue: 0.851)   // #a3acd9 secondary text (tinted, 6.7:1)
    static let standby   = Color(red: 0.898, green: 0.282, blue: 0.302)   // #e5484d sending
    static let go        = Color(red: 0.188, green: 0.643, blue: 0.424)   // #30a46c landed
    static let attention = Color(red: 0.961, green: 0.722, blue: 0.239)   // #f5b83d needs you
}

extension Font {
    static func figures(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}

// MARK: - Effects (order must match effects[] in keyglow.c)

let effectNames = [
    "Solid color", "Breathing", "Spiral glow", "Color cycle", "Cycle left to right", "Cycle top to bottom",
    "Rainbow chevron", "Cycle out to in", "Cycle out to in, dual", "Pinwheel", "Spiral",
    "Dual beacon", "Rainbow beacon", "Jellybean raindrops", "Pixel rain", "Typing heatmap",
    "Digital rain", "Reactive, simple", "Reactive, wide", "Reactive, nexus", "Splash", "Solid splash",
]

// MARK: - Cues

struct Cue: Codable, Equatable, Identifiable {
    var id: Int            // cue number
    var name: String
    var hue: Double        // 0...1
    var saturation: Double // 0...1
    var level: Double      // 0...255
    var effect: Int
    var speed: Double      // 0...255
    var on: Bool

    var color: Color { Color(hue: hue, saturation: saturation, brightness: 1) }

    func sameLook(as o: Cue) -> Bool {
        abs(hue - o.hue) < 0.01 && abs(saturation - o.saturation) < 0.01 &&
        Int(level) == Int(o.level) && effect == o.effect && Int(speed) == Int(o.speed) && on == o.on
    }

    static let defaults: [Cue] = [
        Cue(id: 1, name: "Work light", hue: 0.60, saturation: 0.04, level: 255, effect: 0, speed: 128, on: true),
        Cue(id: 2, name: "Ember",      hue: 0.05, saturation: 0.90, level: 150, effect: 1, speed: 70,  on: true),
        Cue(id: 3, name: "Ocean",      hue: 0.60, saturation: 0.85, level: 200, effect: 1, speed: 128, on: true),
        Cue(id: 4, name: "Blackout",   hue: 0.00, saturation: 0.00, level: 0,   effect: 0, speed: 128, on: false),
    ]
}

final class CueSheet: ObservableObject {
    @Published var cues: [Cue]
    @Published var live: Cue            // what the controls show = what was last sent
    @Published var currentID: Int?      // the cue last recalled or saved

    private let store: UserDefaults?

    init(store: UserDefaults? = .standard) {
        self.store = store
        let saved = store?.data(forKey: "cues").flatMap { try? JSONDecoder().decode([Cue].self, from: $0) }
        let cues = saved ?? Cue.defaults
        self.cues = cues
        let current = store?.object(forKey: "currentCue") as? Int ?? 3
        self.currentID = current
        let liveSaved = store?.data(forKey: "live").flatMap { try? JSONDecoder().decode(Cue.self, from: $0) }
        self.live = liveSaved ?? cues.first { $0.id == current } ?? cues[0]
    }

    var current: Cue? { cues.first { $0.id == currentID } }
    var edited: Bool { guard let c = current else { return true } ; return !c.sameLook(as: live) }

    func persist() {
        guard let store else { return }
        store.set(try? JSONEncoder().encode(cues), forKey: "cues")
        store.set(try? JSONEncoder().encode(live), forKey: "live")
        store.set(currentID, forKey: "currentCue")
    }

    func saveLive(into id: Int) {
        guard let i = cues.firstIndex(where: { $0.id == id }) else { return }
        let name = cues[i].name
        cues[i] = live
        cues[i].id = id
        cues[i].name = name
        currentID = id
        persist()
    }
}

// MARK: - Sending a look

extension Keyboard {
    func sendPower(_ on: Bool) { send(.power, on ? 1 : 0) }
    func sendEffect(_ e: Int) { send(.effect, UInt8(clamping: e)) }
    func sendSpeed(_ v: Double) { send(.speed, UInt8(clamping: Int(v))) }
    func sendColor(_ c: Cue) {
        send(.hsv, UInt8(clamping: Int(c.hue * 255)), UInt8(clamping: Int(c.saturation * 255)), UInt8(clamping: Int(c.level)))
    }
    func sendLook(_ c: Cue) {
        guard c.on else { sendPower(false); return }
        sendPower(true)
        sendEffect(c.effect)
        sendColor(c)
        sendSpeed(c.speed)
    }
}

// MARK: - The cue lamp (signature move)

struct CueLamp: View {
    enum Call { case dark, standby, go, attention }
    let call: Call
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var color: Color {
        switch call {
        case .dark: Stage.rule
        case .standby: Stage.standby
        case .go: Stage.go
        case .attention: Stage.attention
        }
    }
    private var word: String {
        switch call {
        case .dark: "Ready"
        case .standby: "Sending"
        case .go: "Sent"
        case .attention: "Needs attention"
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .shadow(color: call == .dark ? .clear : color.opacity(pulse ? 0.9 : 0.5), radius: pulse ? 7 : 4)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            Text(word.uppercased())
                .font(.subheadline.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(call == .dark ? Stage.dim : Stage.paper)
                .contentTransition(.opacity)
        }
        .animation(.easeOut(duration: 0.35), value: call)
        .onChange(of: call) { _, c in startPulse(c) }
        .onAppear { startPulse(call) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(word)")
    }

    private func startPulse(_ c: Call) {
        guard c == .standby, !reduceMotion else { pulse = false; return }
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
    }
}

// MARK: - Panel

struct Panel: View {
    @ObservedObject var kb: Keyboard
    @ObservedObject var sheet: CueSheet
    @State private var showDiagnostics = false
    @State private var signalView = false
    @State private var bits = [false, false, false, false]
    var previewGo = false
    @State private var goUntil = Date.distantPast
    @State private var tick = Date()

    private var bluetooth: Bool { kb.transport == "Bluetooth" }
    private var ready: Bool { kb.found && kb.accessGranted && bluetooth }

    private var call: CueLamp.Call {
        if !ready || kb.lastSend == .failed { return .attention }
        if kb.sending { return .standby }
        if previewGo || tick < goUntil { return .go }
        return .dark
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            rule
            if ready { cueBlock } else { attentionBlock }
            rule
            controls.disabled(!ready).opacity(ready ? 1 : 0.45)
            rule
            cueList.disabled(!ready).opacity(ready ? 1 : 0.45)
            rule
            if showDiagnostics { diagnostics.disabled(!ready); rule }
            footer
        }
        .frame(width: 340)
        .background(Stage.blue)
        .foregroundStyle(Stage.paper)
        .environment(\.colorScheme, .dark)
        .tint(Stage.lift)
        .onChange(of: kb.sending) { _, sending in
            if !sending && kb.lastSend == .ok {
                goUntil = Date().addingTimeInterval(4)
                tick = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.05) { tick = Date() }
            }
        }
    }

    private var rule: some View { Rectangle().fill(Stage.rule).frame(height: 1) }

    // Device line + lamp
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("K3 Pro").font(.headline)
                Text(deviceLine).font(.subheadline).foregroundStyle(Stage.dim)
            }
            Spacer()
            CueLamp(call: call)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var deviceLine: String {
        guard kb.found else { return "Not connected" }
        return kb.transport == "Bluetooth" ? "Bluetooth · connected" : "\(kb.transport) · switch to Bluetooth"
    }

    // Current cue
    private var cueBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(sheet.currentID.map { "\($0)" } ?? "–")
                    .font(.figures(.largeTitle, weight: .semibold))
                    .foregroundStyle(sheet.edited ? Stage.dim : Stage.paper)
                    .frame(minWidth: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(sheet.current?.name ?? "Unsaved look").font(.title3.weight(.semibold))
                        if sheet.edited {
                            Text("EDITED").font(.caption2.weight(.bold)).tracking(0.8)
                                .foregroundStyle(Stage.blue)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(Stage.dim))
                        }
                    }
                    Text(metaLine).font(.subheadline.monospacedDigit()).foregroundStyle(Stage.dim).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            gelChip
            if kb.lastSend == .failed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The keyboard didn't get that. Wake it with a keypress, then send again.")
                        .font(.callout).foregroundStyle(Stage.attention)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Send again") { kb.sendLook(sheet.live) }.controlSize(.small)
                }
            }
            if sheet.edited, let id = sheet.currentID {
                HStack {
                    Text("Changed since you saved look \(id)").font(.subheadline).foregroundStyle(Stage.dim)
                    Spacer()
                    Button("Update look \(id)") { sheet.saveLive(into: id) }
                        .controlSize(.small)
                }
            }
        }
        .padding(16)
    }

    private var metaLine: String {
        guard sheet.live.on else { return "Lights off" }
        return "\(effectNames[sheet.live.effect]) · brightness \(Int(sheet.live.level)) · speed \(Int(sheet.live.speed))"
    }

    // The gel: a full-width color well, clickable
    private var gelChip: some View {
        Button { openGel() } label: { gelFace }
            .buttonStyle(.plain)
            .help("Choose the gel color")
            .accessibilityLabel("Gel color, hue \(Int(sheet.live.hue * 255)), saturation \(Int(sheet.live.saturation * 255))")
            .accessibilityHint("Opens the color picker")
    }

    private var gelFace: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(sheet.live.on ? sheet.live.color.opacity(0.35 + 0.65 * sheet.live.level / 255) : Color.black)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.22), lineWidth: 1))
            Text("H \(Int(sheet.live.hue * 255))  S \(Int(sheet.live.saturation * 255))")
                .font(.figures(.subheadline, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .padding(.horizontal, 10).padding(.bottom, 7)
            Image(systemName: "paintpalette")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(9)
        }
        .frame(height: 46)
        .contentShape(Rectangle())
    }

    private func openGel() {
        let sheet = self.sheet, kb = self.kb
        GelPanel.shared.open(NSColor(sheet.live.color)) { ns in
            let c = ns.usingColorSpace(.deviceRGB) ?? .white
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            sheet.live.hue = h
            sheet.live.saturation = s
            sheet.persist()
            kb.sendColor(sheet.live)
        }
    }

    // Not ready: say exactly what's missing and how to fix it
    private var attentionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !kb.found {
                Text("Keyboard not found").font(.title3.weight(.semibold))
                Text("Turn the K3 Pro on, switch it to Bluetooth, and make sure it's paired with this Mac.")
                    .font(.callout).foregroundStyle(Stage.dim)
            } else if !kb.accessGranted {
                Text("KeyGlow needs permission").font(.title3.weight(.semibold))
                Text("macOS calls it Input Monitoring. KeyGlow only sends light signals and never reads what you type. After switching it on, reopen KeyGlow.")
                    .font(.callout).foregroundStyle(Stage.dim)
                Button("Open Input Monitoring…") { kb.requestAccess() }.padding(.top, 2)
            } else {
                Text("Switch to Bluetooth").font(.title3.weight(.semibold))
                Text("The keyboard is on the cable. KeyGlow talks to it over Bluetooth only.")
                    .font(.callout).foregroundStyle(Stage.dim)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    // Effect / level / speed
    private var controls: some View {
        VStack(spacing: 10) {
            row("Lights") {
                Toggle("Lights", isOn: Binding(
                    get: { sheet.live.on },
                    set: { on in sheet.live.on = on; sheet.persist(); kb.sendPower(on) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                Spacer()
            }
            row("Effect") {
                Picker("Effect", selection: Binding(
                    get: { sheet.live.effect },
                    set: { e in sheet.live.effect = e; sheet.persist(); kb.sendEffect(e) })) {
                    ForEach(effectNames.indices, id: \.self) { Text(effectNames[$0]).tag($0) }
                }
                .labelsHidden()
            }
            row("Brightness") { slider(\.level) { kb.sendColor(sheet.live) } }
            row("Speed") { slider(\.speed) { kb.sendSpeed(sheet.live.speed) } }
            if sheet.live.on && sheet.live.level < 48 {
                Text("Below 48 the keyboard switches its lights off on battery.")
                    .font(.subheadline).foregroundStyle(Stage.attention)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label.uppercased())
                .font(.subheadline.weight(.medium)).tracking(0.8)
                .foregroundStyle(Stage.dim)
                .frame(width: 84, alignment: .leading)
            content()
        }
        .frame(minHeight: 24)
    }

    private func slider(_ key: WritableKeyPath<Cue, Double>, onDone: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Slider(value: Binding(get: { sheet.live[keyPath: key] }, set: { sheet.live[keyPath: key] = $0.rounded() }),
                   in: 0...255) { editing in if !editing { sheet.persist(); onDone() } }
                .controlSize(.small)
            Text("\(Int(sheet.live[keyPath: key]))")
                .font(.figures(.callout))
                .frame(width: 30, alignment: .trailing)
        }
    }

    // Saved cues: click to recall
    private var cueList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SAVED LOOKS").font(.subheadline.weight(.medium)).tracking(0.8).foregroundStyle(Stage.dim)
                .padding(.horizontal, 8).padding(.bottom, 4)
            ForEach(sheet.cues) { cue in
                CueRow(cue: cue, current: cue.id == sheet.currentID) {
                    sheet.live = cue
                    sheet.currentID = cue.id
                    sheet.persist()
                    kb.sendLook(cue)
                } record: {
                    sheet.saveLive(into: cue.id)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 12)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Flash keyboard white") { kb.send(.ping) }
                Spacer()
                Toggle("Signal view", isOn: $signalView)
                    .toggleStyle(.switch).controlSize(.small)
                    .onChange(of: signalView) { _, on in kb.send(.view, on ? 1 : 0) }
            }
            Text("Signal view (or Fn+V) lights keys 1–5 for Num, Caps, Scroll, Compose, Kana.")
                .font(.subheadline).foregroundStyle(Stage.dim)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Toggle(["Num", "Scroll", "Compose", "Kana"][i], isOn: $bits[i]).toggleStyle(.button).controlSize(.small)
                }
            }
            .onChange(of: bits) { _, b in kb.sendRaw(num: b[0], scroll: b[1], compose: b[2], kana: b[3]) }
            HStack(spacing: 10) {
                Text("FRAME GAP").font(.subheadline.weight(.medium)).tracking(0.8).foregroundStyle(Stage.dim)
                Slider(value: $kb.frameMs, in: 8...60, step: 1).controlSize(.small)
                Text("\(Int(kb.frameMs)) ms").font(.figures(.callout)).frame(width: 46, alignment: .trailing)
            }
            if !kb.message.isEmpty {
                Text("Last error: \(kb.message)").font(.subheadline).foregroundStyle(Stage.attention)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text(!ready ? "Not ready" : kb.sending ? "Sending · \(max(kb.inFlight, 1)) left, about 2 s each" : (kb.lastSend == .failed ? "Last send failed" : "Ready"))
                .monospacedDigit()
                .font(.subheadline).foregroundStyle(kb.lastSend == .failed ? Stage.attention : Stage.dim)
            Spacer()
            Button { withAnimation(.easeOut(duration: 0.2)) { showDiagnostics.toggle() } } label: {
                Image(systemName: "stethoscope")
            }
            .buttonStyle(.borderless).help("Diagnostics")
            .accessibilityLabel("Diagnostics")
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless).help("Quit KeyGlow (⌘Q)")
                .keyboardShortcut("q")
        }
        .foregroundStyle(Stage.dim)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct CueRow: View {
    let cue: Cue
    let current: Bool
    let recall: () -> Void
    let record: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: recall) {
            HStack(spacing: 12) {
                Text("\(cue.id)").font(.figures(.callout, weight: current ? .semibold : .regular))
                    .frame(width: 16, alignment: .leading)
                RoundedRectangle(cornerRadius: 3)
                    .fill(cue.on ? cue.color : .black)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                    .frame(width: 14, height: 14)
                Text(cue.name).font(.body.weight(current ? .semibold : .regular))
                Spacer()
                Text(cue.on ? effectNames[cue.effect] : "Off")
                    .font(.subheadline).foregroundStyle(Stage.dim)
                Text(cue.on ? "\(Int(cue.level))" : "0")
                    .font(.figures(.callout)).foregroundStyle(current ? Stage.paper : Stage.dim)
                    .frame(width: 30, alignment: .trailing)
            }
            .foregroundStyle(current ? Stage.paper : Stage.paper.opacity(0.82))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 6).fill(current ? Stage.raised : (hover ? Stage.raised.opacity(0.5) : .clear)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(cue.id)")), modifiers: [])
        .onHover { hover = $0 }
        .contextMenu { Button("Save current look here", action: record) }
        .accessibilityLabel("Saved look \(cue.id), \(cue.name)\(current ? ", current" : "")")
        .accessibilityHint("Sends this look to the keyboard")
    }
}

// MARK: - System color panel for the gel (outlives the menu bar panel closing)

final class GelPanel: NSObject {
    static let shared = GelPanel()
    private var onChange: ((NSColor) -> Void)?

    func open(_ color: NSColor, onChange: @escaping (NSColor) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = false      // send when the pick settles, not on every drag step
        panel.color = color
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
    }

    @objc private func changed(_ panel: NSColorPanel) { onChange?(panel.color) }
}

// MARK: - App

@main
struct KeyGlowApp: App {
    @StateObject private var kb = Keyboard()
    @StateObject private var sheet = CueSheet()

    init() {
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            Snapshot.run(into: CommandLine.arguments[i + 1])
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Panel(kb: kb, sheet: sheet)
        } label: {
            Image(systemName: kb.sending ? "light.beacon.max.fill" : "light.beacon.max")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Snapshots for design review (no HID access)

enum Snapshot {
    static func run(into dir: String) {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        func board(_ name: String, found: Bool = true, transport: String = "Bluetooth", access: Bool = true,
                   sending: Bool = false, last: Keyboard.SendState = .ok, edit: Bool = false,
                   go: Bool = false, inFlight: Int = 0, message: String = "") {
            let kb = Keyboard(live: false)
            kb.found = found; kb.transport = transport; kb.accessGranted = access
            kb.sending = sending; kb.lastSend = last; kb.inFlight = inFlight; kb.message = message
            let sheet = CueSheet(store: nil)
            if edit { sheet.live.level = 120; sheet.live.effect = 3 }
            let view = Panel(kb: kb, sheet: sheet, previewGo: go)
                .environment(\.controlActiveState, .key)
            let host = NSHostingView(rootView: view)
            host.frame.size = host.fittingSize
            let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }

        board("panel")
        board("panel-sending", sending: true, inFlight: 1)
        board("panel-edited", edit: true)
        board("panel-no-permission", access: false)
        board("panel-not-found", found: false, transport: "")
        board("panel-usb", transport: "USB")
        board("panel-go", go: true)
        board("panel-sending-queue", sending: true, inFlight: 3)
        board("panel-failed", last: .failed, message: "Couldn't send (error 0xe00002c0). Is the keyboard connected?")
    }
}
