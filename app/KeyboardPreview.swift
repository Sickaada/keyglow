// A small K3 Pro (ANSI, 84 keys) lit with the current look.
// It previews the chosen look; it does not read what the keyboard is showing.
// The motion is an approximation of each effect, driven by the speed setting.
import SwiftUI

struct KeyboardPreview: View {
    let cue: Cue
    var selectedZone: Int? = nil                 // Split / Gradient: the slot being edited, outlined on the board
    var tapZone: (Int) -> Void = { _ in }
    var active = true
    var miniature = false
    var fixedTime: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || fixedTime != nil || reduceMotion || !animates)) { tl in
                Canvas { ctx, size in
                    draw(ctx, size, t: fixedTime ?? (reduceMotion ? 1.3 : tl.date.timeIntervalSinceReferenceDate))
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { e in
                guard selectedZone != nil else { return }
                let u = geo.size.width / Self.unitsWide
                let x = e.location.x / u - Self.side - Self.bezel        // key units from the left key edge
                let n = cue.colorCount
                tapZone(min(n - 1, max(0, Int(x / 16 * Double(n)))))
            }, including: selectedZone == nil ? .none : .all)
        }
        .aspectRatio(Self.unitsWide / Self.unitsHigh, contentMode: .fit)
    }

    private var animates: Bool {
        guard cue.on else { return false }
        return ![0, splitEffect, gradientEffect].contains(cue.effect)
    }

    // MARK: Layout (K3 Pro ANSI, Mac legends)

    struct Key { let x, y, w: Double; let label: String }   // in key units; the key field is 16 x 6

    static let rows: [[Double]] = [
        Array(repeating: 1, count: 16),
        Array(repeating: 1, count: 13) + [2, 1],
        [1.5] + Array(repeating: 1, count: 12) + [1.5, 1],
        [1.75] + Array(repeating: 1, count: 11) + [2.25, 1],
        [2.25] + Array(repeating: 1, count: 10) + [1.75, 1, 1],
        [1.25, 1.25, 1.25, 6.25, 1, 1, 1, 1, 1, 1],
    ]
    static let labels: [[String]] = [
        ["esc"] + (1...12).map { "F\($0)" } + ["prt", "del", "☀"],
        ["~", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "delete", "pgup"],
        ["tab"] + "QWERTYUIOP".map(String.init) + ["[", "]", "\\", "pgdn"],
        ["caps"] + "ASDFGHJKL".map(String.init) + [";", "'", "return", "home"],
        ["shift"] + "ZXCVBNM".map(String.init) + [",", ".", "/", "shift", "↑", "end"],
        ["ctrl", "opt", "cmd", "", "cmd", "fn", "ctrl", "←", "↓", "→"],
    ]
    static let keys: [Key] = rows.enumerated().flatMap { r, widths in
        var x = 0.0
        return widths.enumerated().map { i, w in
            defer { x += w }
            return Key(x: x, y: Double(r), w: w, label: labels[r][i])
        }
    }
    // Frame and room around it for the light the keyboard spills onto the panel.
    static let bezel = 0.26, side = 0.3, top = 0.15, below = 0.75
    static let unitsWide = 16 + 2 * bezel + 2 * side
    static let unitsHigh = 6 + 2 * bezel + top + below

    // MARK: Drawing

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, t: Double) {
        let u = size.width / Self.unitsWide
        let level = cue.on && cue.level >= 48 ? cue.level / 255 : 0
        let frame = CGRect(x: Self.side * u, y: Self.top * u,
                           width: (16 + 2 * Self.bezel) * u, height: (6 + 2 * Self.bezel) * u)
        let origin = CGPoint(x: frame.minX + Self.bezel * u, y: frame.minY + Self.bezel * u)
        let gap = u * 0.1

        // Work out each key's light once per frame.
        var lit: [(rect: CGRect, light: RGB, v: Double)] = []
        lit.reserveCapacity(Self.keys.count)
        var sum = RGB(0, 0, 0)
        for k in Self.keys {
            let rect = CGRect(x: origin.x + k.x * u + gap / 2, y: origin.y + k.y * u + gap / 2,
                              width: k.w * u - gap, height: u - gap)
            let l = cue.on ? light((k.x + k.w / 2) / 16, (k.y + 0.5) / 6, t: t) : RGB(0, 0, 0)
            let v = max(l.r, l.g, l.b) * level
            lit.append((rect, l, v))
            sum = RGB(sum.r + l.r * level * k.w, sum.g + l.g * level * k.w, sum.b + l.b * level * k.w)
        }
        let spill = sum.scaled(1 / 96)

        // 1. Light spilling onto the desk (the panel) under the keyboard.
        if cue.on {
            ctx.drawLayer { g in
                g.addFilter(.blur(radius: u * 0.9))
                let pool = CGRect(x: frame.minX + u * 0.6, y: frame.maxY - u * 1.4,
                                  width: frame.width - u * 1.2, height: u * 1.8)
                g.fill(Path(ellipseIn: pool), with: .color(spill.color.opacity(0.75)))
            }
        }

        // 2. Aluminium frame: dark, with a lit top edge.
        let body = Path(roundedRect: frame, cornerRadius: u * 0.38)
        ctx.fill(body, with: .linearGradient(
            Gradient(colors: [Color(red: 0.065, green: 0.065, blue: 0.075), Color(red: 0.025, green: 0.025, blue: 0.03)]),
            startPoint: CGPoint(x: 0, y: frame.minY), endPoint: CGPoint(x: 0, y: frame.maxY)))
        ctx.stroke(Path(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: u * 0.38),
                   with: .linearGradient(Gradient(colors: [.white.opacity(0.35), .white.opacity(0.06)]),
                                         startPoint: CGPoint(x: 0, y: frame.minY), endPoint: CGPoint(x: 0, y: frame.maxY)),
                   lineWidth: 1)

        // 3. Glow between the keys: LEDs sit under each cap and light up around it.
        ctx.drawLayer { g in
            g.clip(to: Path(roundedRect: frame.insetBy(dx: u * 0.08, dy: u * 0.08), cornerRadius: u * 0.3))
            g.addFilter(.blur(radius: u * 0.22))
            for k in lit where k.v > 0.02 {
                let peak = max(0.001, max(k.light.r, k.light.g, k.light.b))
                g.fill(Path(roundedRect: k.rect.insetBy(dx: -u * 0.05, dy: -u * 0.05), cornerRadius: u * 0.2),
                       with: .color(k.light.scaled(min(1, k.v * 1.2) / peak).color))
            }
        }

        // 4. Low-profile caps with shine-through legends.
        for (i, k) in Self.keys.enumerated() {
            let r = lit[i].rect, l = lit[i].light, v = lit[i].v
            let hue = v > 0.001 ? l.scaled(1 / max(l.r, l.g, l.b)) : RGB(0, 0, 0)
            let capTop = Self.cap.mix(hue, v * 0.015), capBottom = Self.capDark.mix(hue, v * 0.008)
            let cap = Path(roundedRect: r, cornerRadius: u * 0.14)
            ctx.fill(cap, with: .linearGradient(Gradient(colors: [capTop.color, capBottom.color]),
                                                startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
            ctx.stroke(Path(roundedRect: r.insetBy(dx: 0.25, dy: 0.25), cornerRadius: u * 0.14),
                       with: .color(hue.mix(RGB(1, 1, 1), 0.3).color.opacity(0.10 + 0.12 * v)), lineWidth: 0.5)

            guard !miniature, !k.label.isEmpty else { continue }
            let legend = Self.legendOff.mix(hue.mix(RGB(1, 1, 1), 0.35), min(1, v * 1.15))
            let fKey = k.label.hasPrefix("F") && k.label.count > 1
            let single = k.label.count <= 2 || fKey
            let text = Text(k.label)
                .font(.system(size: u * (fKey ? 0.27 : single ? 0.36 : 0.22), weight: single ? .semibold : .medium))
                .foregroundColor(legend.color)
            if single {
                ctx.draw(text, at: CGPoint(x: r.midX, y: r.midY))
            } else {   // word legends sit bottom-left, like the real keycaps
                ctx.draw(text, at: CGPoint(x: r.minX + u * 0.12, y: r.maxY - u * 0.12), anchor: .bottomLeading)
            }
        }

        // 5. The color part being edited (Split / Gradient).
        if let z = selectedZone {
            let w = 16 / Double(cue.colorCount)
            let zone = CGRect(x: origin.x + w * Double(z) * u, y: frame.minY + u * 0.06,
                              width: w * u, height: frame.height - u * 0.12).insetBy(dx: u * 0.04, dy: 0)
            ctx.stroke(Path(roundedRect: zone, cornerRadius: u * 0.25), with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }

    // MARK: Effects (approximations, keyed by firmware effect index)

    struct RGB {
        var r, g, b: Double
        init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t) }
        func scaled(_ s: Double) -> RGB { RGB(r * s, g * s, b * s) }
        var color: Color { Color(red: r, green: g, blue: b) }
        static func hsv(_ h: Double, _ s: Double, _ v: Double = 1) -> RGB {
            let h = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
            let i = Int(h) % 6, f = h - Double(Int(h))
            let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
            switch i {
            case 0: return RGB(v, t, p)
            case 1: return RGB(q, v, p)
            case 2: return RGB(p, v, t)
            case 3: return RGB(p, q, v)
            case 4: return RGB(t, p, v)
            default: return RGB(v, p, q)
            }
        }
    }
    static let cap = RGB(0.105, 0.108, 0.12)       // unlit keycap, top
    static let capDark = RGB(0.055, 0.058, 0.065)   // unlit keycap, bottom
    static let legendOff = RGB(0.45, 0.47, 0.55) // legend with no light behind it

    private func tint(_ i: Int) -> RGB {
        let ts = cue.tints
        let t = ts[min(i, ts.count - 1)]
        return .hsv(t.hue, t.saturation)
    }

    private func noise(_ a: Double, _ b: Double) -> Double {
        let v = sin(a * 127.1 + b * 311.7) * 43758.5453
        return v - floor(v)
    }

    /// Light for the key centered at (x, y), both 0...1.
    private func light(_ x: Double, _ y: Double, t: Double) -> RGB {
        let s = 0.15 + cue.speed / 255 * 1.1          // effect speed, cycles per second-ish
        let ph = t * s
        let main = tint(0)
        let dx = x - 0.5, dy = (y - 0.5) * 0.4
        let dist = sqrt(dx * dx + dy * dy), angle = atan2(dy, dx) / (2 * .pi)
        let id = x * 17 + y * 5                       // a stable number per key

        switch cue.effect {
        case 0: return main
        case 1: return main.scaled(0.25 + 0.75 * (0.5 + 0.5 * sin(ph * 2 * .pi * 0.5)))
        case 2: return main.scaled(0.3 + 0.7 * (0.5 + 0.5 * sin((angle + dist - ph * 0.5) * 2 * .pi)))
        case 3: return .hsv(ph * 0.2, 1)
        case 4: return .hsv(x - ph * 0.2, 1)
        case 5: return .hsv(y - ph * 0.2, 1)
        case 6: return .hsv(abs(x - 0.5) + y * 0.3 - ph * 0.2, 1)
        case 7: return .hsv(dist * 1.5 + ph * 0.2, 1)
        case 8: return .hsv(abs(dx) * 2 - ph * 0.2, 1)
        case 9: return .hsv(angle + ph * 0.2, 1)
        case 10: return .hsv(angle + dist - ph * 0.2, 1)
        case 11: return .hsv(cue.hue + 0.3 * sin((angle + ph * 0.3) * 2 * .pi), 1)
        case 12: return .hsv(angle + ph * 0.3, 1)
        case 13: return .hsv(noise(id, floor(ph * 2 + noise(id, 1) * 3)), 1)
        case 14:
            let n = noise(id, floor(ph * 3))
            return n < 0.12 ? .hsv(noise(id, 7), 1) : RGB(0, 0, 0)
        case 15:
            let n = noise(id, floor(ph * 0.7))
            return n < 0.15 ? .hsv(n * 0.6, 1) : RGB(0, 0, 0)   // warm: red to yellow
        case 16:
            let col = floor(x * 16)
            let f = (y - ph * 0.6 + noise(col, 3)).truncatingRemainder(dividingBy: 1)
            let v = max(0, 1 - ((f + 1).truncatingRemainder(dividingBy: 1)) * 3)
            return RGB(0, v, v * 0.2)
        case 17, 18, 19:
            // keys light up as you type, then fade: show a few recent "presses"
            let beat = ph * 1.5, n = noise(id, floor(beat))
            let fade = 1 - (beat - floor(beat))
            return n < 0.08 ? main.scaled(fade) : main.scaled(0.06)
        case 20:
            return .hsv(dist * 2 - ph * 0.4, 1).scaled(0.4 + 0.6 * (0.5 + 0.5 * sin((dist * 4 - ph) * 2 * .pi)))
        case 21:
            return main.scaled(max(0.06, 0.5 + 0.5 * sin((dist * 4 - ph) * 2 * .pi)))
        case splitEffect:
            return tint(min(cue.colorCount - 1, Int(x * Double(cue.colorCount))))
        case gradientEffect:
            return along(x * Double(cue.colorCount - 1), loop: false)
        case 24: return along(t * 1000 * (cue.speed + 8) / 128 / 256, loop: true)
        case 25: return along(x * Double(cue.colorCount) + t * 1000 * (cue.speed + 8) / 128 / 256, loop: true)
        default: return main
        }
    }

    /// A position through the palette: 0 = color 1, 1 = color 2, … (wraps when looping).
    private func along(_ p: Double, loop: Bool) -> RGB {
        let n = cue.colorCount
        if loop {
            let q = (p.truncatingRemainder(dividingBy: Double(n)) + Double(n)).truncatingRemainder(dividingBy: Double(n))
            let i = Int(q)
            return tint(i).mix(tint((i + 1) % n), q - Double(i))
        }
        let q = min(max(p, 0), Double(n - 1))
        let i = min(Int(q), n - 2)
        return tint(i).mix(tint(i + 1), q - Double(i))
    }
}
