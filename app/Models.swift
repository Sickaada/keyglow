import SwiftUI
import AppKit
import Combine

// MARK: - Effects (order must match effects[] in keyglow.c)

/// How an effect uses color decides what the color controls show.
enum ColorUse { case one, several, own }

struct EffectInfo { let name: String; let use: ColorUse }

let effects: [EffectInfo] = [
    .init(name: "Solid color", use: .one), .init(name: "Breathing", use: .one), .init(name: "Spiral glow", use: .one),
    .init(name: "Color cycle", use: .own), .init(name: "Cycle left to right", use: .own),
    .init(name: "Cycle top to bottom", use: .own), .init(name: "Rainbow chevron", use: .own),
    .init(name: "Cycle out to in", use: .own), .init(name: "Cycle out to in, dual", use: .own),
    .init(name: "Pinwheel", use: .own), .init(name: "Spiral", use: .own), .init(name: "Dual beacon", use: .own),
    .init(name: "Rainbow beacon", use: .own), .init(name: "Jellybean raindrops", use: .own),
    .init(name: "Pixel rain", use: .own), .init(name: "Typing heatmap", use: .own), .init(name: "Digital rain", use: .own),
    .init(name: "Reactive, simple", use: .one), .init(name: "Reactive, wide", use: .one),
    .init(name: "Reactive, nexus", use: .one), .init(name: "Splash", use: .own), .init(name: "Solid splash", use: .one),
    // 22...25 need the KeyGlow firmware's multi-color effects
    .init(name: "Split", use: .several), .init(name: "Gradient", use: .several),
    .init(name: "Color fade", use: .several), .init(name: "Color wave", use: .several),
]
let effectNames = effects.map(\.name)
let splitEffect = 22, gradientEffect = 23

func effectInfo(_ i: Int) -> EffectInfo { effects.indices.contains(i) ? effects[i] : effects[0] }

/// What each color slot means for a multi-color effect: a place on the board, or a turn in the order.
func slotRoles(effect: Int, count: Int) -> [String] {
    let positional = effect == splitEffect || effect == gradientEffect
    let names = positional ? (count == 3 ? ["Left", "Middle", "Right"] : ["Left", "Right"]) : ["1st", "2nd", "3rd"]
    return Array(names.prefix(count))
}
func slotsAreOrdered(effect: Int) -> Bool { effect != splitEffect && effect != gradientEffect }

// MARK: - Colors

struct Tint: Codable, Equatable {
    var hue: Double        // 0...1
    var saturation: Double // 0...1
    var color: Color { Color(hue: hue, saturation: saturation, brightness: 1) }
    func near(_ o: Tint) -> Bool {
        if saturation < 0.03 && o.saturation < 0.03 { return true }   // whites: hue doesn't matter
        let dh = abs(hue - o.hue)
        return min(dh, 1 - dh) < 0.012 && abs(saturation - o.saturation) < 0.03
    }
    /// Light colors need a dark check mark to stay visible.
    var isLight: Bool { saturation < 0.5 || (hue > 0.1 && hue < 0.55) }
}

struct Preset: Identifiable { let name: String; let tint: Tint; var id: String { name } }

let presets: [Preset] = [
    ("White", 0.00, 0.00), ("Warm white", 0.09, 0.30), ("Red", 0.00, 1.00), ("Orange", 0.06, 1.00),
    ("Gold", 0.11, 1.00), ("Yellow", 0.16, 1.00), ("Green", 0.33, 1.00), ("Mint", 0.42, 0.65),
    ("Cyan", 0.50, 1.00), ("Blue", 0.62, 1.00), ("Indigo", 0.70, 1.00), ("Purple", 0.78, 1.00),
    ("Pink", 0.90, 0.70),
].map { Preset(name: $0.0, tint: Tint(hue: $0.1, saturation: $0.2)) }

enum LookChange { case effect, palette, brightness, speed }

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
    var extra: [Tint]? = nil   // colors 2 and 3, used by multi-color effects

    var color: Color { Color(hue: hue, saturation: saturation, brightness: 1) }
    var use: ColorUse { effectInfo(effect).use }
    var tints: [Tint] { [Tint(hue: hue, saturation: saturation)] + (extra ?? []) }
    var colorCount: Int { min(3, max(2, tints.count)) }

    mutating func setTint(_ t: Tint, at i: Int) {
        if i == 0 { hue = t.hue; saturation = t.saturation; return }
        var e = extra ?? []
        while e.count < i { e.append(t) }
        e[i - 1] = t
        extra = e
    }

    /// Multi-color effects need a second color; start with the opposite hue so the split is visible.
    mutating func ensureSeveral() {
        if (extra ?? []).isEmpty {
            extra = [Tint(hue: (hue + 0.5).truncatingRemainder(dividingBy: 1), saturation: 1)]
        }
    }

    mutating func setColorCount(_ n: Int) {
        ensureSeveral()
        var e = extra ?? []
        if n == 3, e.count < 2 { e.append(Tint(hue: (e[0].hue + 0.25).truncatingRemainder(dividingBy: 1), saturation: 1)) }
        if n == 2, e.count > 1 { e = [e[0]] }
        extra = e
    }

    func sameLook(as o: Cue) -> Bool {
        abs(hue - o.hue) < 0.01 && abs(saturation - o.saturation) < 0.01 &&
        Int(level) == Int(o.level) && effect == o.effect && Int(speed) == Int(o.speed) && on == o.on &&
        (use != .several || (extra ?? []) == (o.extra ?? []))
    }

    static let defaults: [Cue] = [
        Cue(id: 1, name: "Work light", hue: 0.00, saturation: 0.00, level: 255, effect: 0, speed: 128, on: true),
        Cue(id: 2, name: "Ember",      hue: 0.06, saturation: 1.00, level: 150, effect: 1, speed: 70,  on: true),
        Cue(id: 3, name: "Ocean",      hue: 0.62, saturation: 1.00, level: 200, effect: 1, speed: 128, on: true),
        Cue(id: 4, name: "Blackout",   hue: 0.00, saturation: 0.00, level: 0,   effect: 0, speed: 128, on: false),
    ]
}

final class CueSheet: ObservableObject {
    @Published var cues: [Cue]
    @Published var live: Cue            // selected look; may differ from what was submitted
    @Published var currentID: Int?      // the cue last recalled or saved

    @Published var lastSubmitted: Cue? = nil
    private var submissionCandidate: Cue? = nil
    private var sendObserver: AnyCancellable?
    func noteSubmission() { submissionCandidate = live }
    /// Partial commands may clear pending state only when they cover every difference.
    /// The in-flight candidate includes commands already queued by earlier edits.
    func requiresFullSubmission(for change: LookChange) -> Bool {
        guard var covered = submissionCandidate ?? lastSubmitted else { return true }
        switch change {
        case .effect:
            covered.effect = live.effect
            if live.use == .several { covered.extra = live.extra }
        case .palette:
            covered.hue = live.hue; covered.saturation = live.saturation; covered.level = live.level
            if live.use == .several { covered.extra = live.extra }
        case .brightness:
            covered.hue = live.hue; covered.saturation = live.saturation; covered.level = live.level
        case .speed:
            covered.speed = live.speed
        }
        return !covered.sameLook(as: live)
    }
    func observeSending(_ kb: Keyboard) {
        guard sendObserver == nil else { return }
        sendObserver = kb.$sending.dropFirst().receive(on: DispatchQueue.main).sink { [weak self, weak kb] busy in
            guard let self, let kb, !busy, kb.inFlight == 0, let candidate = self.submissionCandidate else { return }
            if kb.lastSend == .ok { self.lastSubmitted = candidate }
            self.submissionCandidate = nil
        }
    }
    var needsApply: Bool { lastSubmitted.map { !live.sameLook(as: $0) } ?? true }

    private let store: UserDefaults?

    init(store: UserDefaults? = .standard) {
        self.store = store
        let saved = store?.data(forKey: "cues").flatMap { try? JSONDecoder().decode([Cue].self, from: $0) }
        let cues = (saved ?? Cue.defaults).filter { $0.isValid }
        self.cues = cues
        let current = store?.object(forKey: "currentCue") as? Int ?? 3
        self.currentID = current
        let liveSaved = store?.data(forKey: "live").flatMap { try? JSONDecoder().decode(Cue.self, from: $0) }
        self.live = liveSaved.flatMap { $0.isValid ? $0 : nil } ?? cues.first { $0.id == current } ?? Cue.defaults[0]
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
    private func byte(_ v: Double) -> UInt8 { UInt8(clamping: Int(v * 255)) }
    func sendColor2(_ c: Cue) {
        let t = c.tints[min(1, c.tints.count - 1)]
        send(.color2, byte(t.hue), byte(t.saturation))
    }
    func sendColor3(_ c: Cue) {
        let t = c.tints[min(2, c.tints.count - 1)]
        send(.color3, byte(t.hue), byte(t.saturation), c.colorCount == 3 ? 1 : 0)
    }
    /// Send the color in one slot: 0 is the main color, 1 and 2 are the extra colors.
    func sendSlot(_ i: Int, of c: Cue) {
        switch i {
        case 0: sendColor(c)
        case 1: sendColor2(c)
        default: sendColor3(c)
        }
    }
    func sendLook(_ c: Cue) {
        guard c.on else { sendPower(false); return }
        sendPower(true)
        if c.use == .several { sendColor2(c); sendColor3(c) }
        sendEffect(c.effect)
        sendColor(c)
        sendSpeed(c.speed)
    }
}
