import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Cue {
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 &&
        hue.isFinite && saturation.isFinite && level.isFinite && speed.isFinite &&
        (0...1).contains(hue) && (0...1).contains(saturation) && (0...255).contains(level) &&
        (0...255).contains(speed) && effects.indices.contains(effect) && (extra ?? []).count <= 2 &&
        (extra ?? []).allSatisfy { $0.hue.isFinite && $0.saturation.isFinite && (0...1).contains($0.hue) && (0...1).contains($0.saturation) }
    }
    var animated: Bool { on && ![0, 22, 23].contains(effect) }
    var reactive: Bool { [15,17,18,19,20,21].contains(effect) }
    var effectName: String { effectInfo(effect).name }
}

extension Tint {
    var hex: String {
        let c = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
    func hex(level: Double) -> String {
        let c = NSColor(hue: hue, saturation: saturation, brightness: level / 255, alpha: 1).usingColorSpace(.deviceRGB)!
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
    static func parse(_ hex: String) -> (tint: Tint, level: Double)? {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        let c = NSColor(srgbRed: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255, blue: Double(n & 255) / 255, alpha: 1)
        return (Tint(hue: c.hueComponent, saturation: c.saturationComponent), c.brightnessComponent * 255)
    }
}

extension CueSheet {
    @discardableResult func create(_ name: String, from cue: Cue? = nil) -> Int {
        var c = cue ?? live
        c.id = (cues.map(\.id).max() ?? 0) + 1
        c.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        if c.name.isEmpty { c.name = "Untitled preset" }
        cues.append(c); persist(); return c.id
    }
    func rename(_ id: Int, to name: String) {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !name.isEmpty, let i = cues.firstIndex(where: { $0.id == id }) else { return }
        cues[i].name = name; persist()
    }
    func remove(_ id: Int) {
        cues.removeAll { $0.id == id }
        if currentID == id { currentID = nil }
        persist()
    }
}

final class LibraryPreferences: ObservableObject {
    @Published var favorites: Set<Int>
    @Published var recent: [Tint]
    private let store: UserDefaults?
    init(store: UserDefaults? = .standard) {
        self.store = store
        favorites = Set(store?.array(forKey: "studio.favorites") as? [Int] ?? [])
        recent = store?.data(forKey: "studio.recent").flatMap { try? JSONDecoder().decode([Tint].self, from: $0) } ?? []
        recent = recent.filter { (0...1).contains($0.hue) && (0...1).contains($0.saturation) }
    }
    func favorite(_ id: Int) {
        if !favorites.insert(id).inserted { favorites.remove(id) }
        store?.set(Array(favorites), forKey: "studio.favorites")
    }
    func forgetFavorite(_ id: Int) {
        favorites.remove(id); store?.set(Array(favorites), forKey: "studio.favorites")
    }
    func remember(_ tint: Tint) {
        recent.removeAll { $0.near(tint) }; recent.insert(tint, at: 0)
        recent = Array(recent.prefix(8))
        store?.set(try? JSONEncoder().encode(recent), forKey: "studio.recent")
    }
}

struct PresetArchive: Codable {
    let version: Int
    let keyboard: String
    let presets: [Cue]
    static func decode(_ data: Data) throws -> [Cue] {
        guard data.count <= 1_000_000 else { throw ArchiveError.invalid }
        let a = try JSONDecoder().decode(Self.self, from: data)
        guard a.version == 1, a.keyboard == "keychron/k3_pro/ansi/rgb", !a.presets.isEmpty, a.presets.allSatisfy(\.isValid) else { throw ArchiveError.invalid }
        return a.presets
    }
    enum ArchiveError: LocalizedError {
        case invalid
        var errorDescription: String? { "Choose a Lighting Studio preset file for the K3 Pro (up to 1 MB)." }
    }
}

// Panels run outside the menu popover, so closing the popover doesn't cancel the file operation.
enum PresetFiles {
    static func export(_ cues: [Cue], completion: @escaping (String) -> Void) {
        let p = NSSavePanel(); p.allowedContentTypes = [.json]; p.nameFieldStringValue = "Keychron lighting.json"
        p.title = "Export lighting presets"; NSApp.activate(ignoringOtherApps: true)
        p.begin { response in
            guard response == .OK, let url = p.url else { return }
            do {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(PresetArchive(version: 1, keyboard: "keychron/k3_pro/ansi/rgb", presets: cues))
                guard data.count <= 1_000_000 else { throw PresetArchive.ArchiveError.invalid }
                try data.write(to: url, options: .atomic)
                completion("Exported \(cues.count) preset\(cues.count == 1 ? "" : "s").")
            } catch { completion("Export failed: \(error.localizedDescription)") }
        }
    }
    static func load(into sheet: CueSheet, completion: @escaping (String) -> Void) {
        let p = NSOpenPanel(); p.allowedContentTypes = [.json]; p.allowsMultipleSelection = false
        p.title = "Import lighting presets"; NSApp.activate(ignoringOtherApps: true)
        p.begin { response in
            guard response == .OK, let url = p.url else { return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 1_000_000 else { throw PresetArchive.ArchiveError.invalid }
                let cues = try PresetArchive.decode(Data(contentsOf: url))
                for c in cues { sheet.create(c.name, from: c) }
                completion("Imported \(cues.count) presets. Select one to apply it.")
            } catch { completion("Import failed: \(error.localizedDescription)") }
        }
    }
}
