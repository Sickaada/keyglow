import SwiftUI
import AppKit

@main
struct KeyGlowApp: App {
    @StateObject private var kb = Keyboard()
    @StateObject private var sheet = CueSheet()
    @StateObject private var library = LibraryPreferences()
    init() {
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            Snapshot.run(into: CommandLine.arguments[i + 1]); exit(0)
        }
        if CommandLine.arguments.contains("--self-test") { StudioChecks.run(); exit(0) }
    }
    var body: some Scene {
        MenuBarExtra {
            Panel(kb: kb, sheet: sheet, library: library)
        } label: {
            Image(systemName: "keyboard").accessibilityLabel("Keychron Lighting Studio")
        }.menuBarExtraStyle(.window)
        Window("Animation Studio", id: "studio") {
            StudioEditor(kb: kb, sheet: sheet, library: library)
        }.defaultSize(width: 920, height: 640).windowResizability(.contentMinSize)
    }
}

// Offscreen snapshots use isolated fixture state, no HID access and no saved user defaults.
enum Snapshot {
    static func run(into dir: String) {
        _ = NSApplication.shared; NSApp.setActivationPolicy(.prohibited)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        func render<V: View>(_ view: V, _ name: String, size: CGSize? = nil) {
            let host = NSHostingView(rootView: view.environment(\.controlActiveState, .key))
            host.frame.size = size ?? host.fittingSize
            let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = host; host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
        let sheet = CueSheet(store: nil), library = LibraryPreferences(store: nil), kb = Keyboard(live: false)
        sheet.live.hue = 0.76; sheet.live.effect = 23; sheet.live.ensureSeveral()
        sheet.live.extra = [Tint(hue: 0.51, saturation: 0.85)]
        kb.found = true; kb.accessGranted = true; kb.transport = "Bluetooth"
        for tab in 0...2 { render(Panel(kb: kb, sheet: sheet, library: library, tab: tab, snapshot: true), ["lighting", "animations", "presets"][tab]) }
        render(Panel(kb: kb, sheet: sheet, library: library, tab: 2, naming: true, snapshot: true), "save-preset")
        render(StudioEditor(kb: kb, sheet: sheet, library: library, snapshot: true), "studio", size: CGSize(width: 920, height: 640))
        kb.found = false
        render(Panel(kb: kb, sheet: sheet, library: library, snapshot: true), "disconnected")
        kb.found = true; kb.accessGranted = false
        render(Panel(kb: kb, sheet: sheet, library: library, snapshot: true), "permission")
        kb.accessGranted = true; kb.lastSend = .failed; kb.message = "Test fixture: device disconnected during send."
        render(Panel(kb: kb, sheet: sheet, library: library, snapshot: true), "failed")
        kb.lastSend = .idle; sheet.live.on = false
        render(Panel(kb: kb, sheet: sheet, library: library, snapshot: true), "off")
        sheet.cues = []
        render(Panel(kb: kb, sheet: sheet, library: library, tab: 2, snapshot: true), "empty-library")
    }
}

enum StudioChecks {
    static func run() {
        precondition(KeyboardPreview.keys.count == 84)
        precondition(KeyboardPreview.rows.allSatisfy { abs($0.reduce(0,+) - 16) < 0.001 })
        let sheet = CueSheet(store: nil)
        let id = sheet.create("Test", from: Cue.defaults[0])
        sheet.rename(id, to: "Renamed"); precondition(sheet.cues.last?.name == "Renamed")
        sheet.remove(id); precondition(!sheet.cues.contains { $0.id == id })
        let archive = PresetArchive(version: 1, keyboard: "keychron/k3_pro/ansi/rgb", presets: Cue.defaults)
        let data = try! JSONEncoder().encode(archive)
        precondition(try! PresetArchive.decode(data) == Cue.defaults)
        var invalid = Cue.defaults[0]; invalid.effect = 200
        let large = (1...101).map { n -> Cue in var c = Cue.defaults[0]; c.id = n; c.name = "Preset \(n)"; return c }
        let largeData = try! JSONEncoder().encode(PresetArchive(version: 1, keyboard: "keychron/k3_pro/ansi/rgb", presets: large))
        precondition(try! PresetArchive.decode(largeData).count == 101)
        let invalidData = try! JSONEncoder().encode(PresetArchive(version: 1, keyboard: "keychron/k3_pro/ansi/rgb", presets: [invalid]))
        precondition((try? PresetArchive.decode(invalidData)) == nil)
        precondition(Tint.parse("#GGGGGG") == nil && Tint.parse("#55AAFF") != nil)
        let white = Tint.parse("#FFFFFF")!; precondition(white.tint.saturation == 0 && white.level == 255)
        let suiteName = "local.keyglow.studio-checks." + UUID().uuidString
        let store = UserDefaults(suiteName: suiteName)!
        defer { store.removePersistentDomain(forName: suiteName) }
        let persistent = CueSheet(store: store)
        persistent.cues = []; persistent.persist()
        let emptyReload = CueSheet(store: store)
        precondition(emptyReload.cues.isEmpty && emptyReload.live.isValid)
        let savedID = emptyReload.create("Persistence check")
        precondition(CueSheet(store: store).cues.first?.id == savedID)
        var offGradient = Cue.defaults[0]; offGradient.effect = 23; offGradient.on = false; offGradient.level = 0
        let draft = StudioEditor.makeDraft(from: offGradient)
        precondition(draft.on && draft.level >= 48 && draft.colorCount == 2 && draft.isValid)
        let prefs = LibraryPreferences(store: nil); prefs.favorite(1); precondition(prefs.favorites.contains(1)); prefs.favorite(1); precondition(prefs.favorites.isEmpty)
        prefs.favorite(10); prefs.forgetFavorite(10); precondition(!prefs.favorites.contains(10))
        sheet.lastSubmitted = sheet.live; precondition(!sheet.needsApply)
        sheet.live.level = 42; precondition(sheet.needsApply)
        let pending = CueSheet(store: nil)
        pending.lastSubmitted = pending.live
        pending.live.hue = 0.14 // edit while disconnected
        pending.live.speed = 44 // reconnect, edit only speed
        precondition(pending.requiresFullSubmission(for: .speed))
        pending.noteSubmission() // full current look is now queued
        pending.live.speed = 88
        precondition(!pending.requiresFullSubmission(for: .speed))
        let fresh = CueSheet(store: nil)
        precondition(fresh.requiresFullSubmission(for: .palette))
        precondition(Tint(hue: 0, saturation: 1).hex(level: 128) == "#800000")
        for n in 0..<20 { prefs.remember(Tint(hue: Double(n)/20, saturation: 1)) }; precondition(prefs.recent.count == 8)
        print("PASS: 84-key geometry, preset create/rename/delete, archive round-trip/rejection, 101-preset import, empty-library persistence, pending-state comparison, HEX validation, favorites and recent-color bounds.")
    }
}
