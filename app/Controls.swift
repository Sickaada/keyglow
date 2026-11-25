import SwiftUI
import AppKit

struct LightingControls: View {
    @Binding var cue: Cue
    @ObservedObject var library: LibraryPreferences
    var changed: (ControlChange) -> Void
    var showEffect = true
    var compact = false
    var selectedSlot: Binding<Int>? = nil
    @State private var slot = 0
    @State private var hex = ""
    @State private var invalidHex = false
    typealias ControlChange = LookChange

    private var index: Int { min(selectedSlot?.wrappedValue ?? slot, cue.colorCount - 1) }
    private var tint: Tint { cue.tints[min(index, cue.tints.count - 1)] }
    private var colorBinding: Binding<Color> {
        Binding(get: { Color(hue: tint.hue, saturation: tint.saturation, brightness: cue.level / 255) }, set: { color in
            let c = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
            cue.level = c.brightnessComponent * 255
            set(Tint(hue: c.hueComponent, saturation: c.saturationComponent)); changed(.brightness)
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showEffect {
                HStack {
                    Label("Effect", systemImage: "sparkles").foregroundStyle(StudioTheme.secondary)
                    Spacer()
                    Picker("Lighting effect", selection: Binding(get: { cue.effect }, set: { e in
                        cue.effect = e; slot = 0
                        if cue.use == .several { cue.ensureSeveral() }
                        changed(.effect)
                    })) {
                        ForEach(effects.indices, id: \.self) { Text(effectNames[$0]).tag($0) }
                    }.labelsHidden().frame(maxWidth: 235)
                }
            }
            if cue.use != .own { palette }
            else {
                Label("This effect creates its own colors.", systemImage: "paintpalette")
                    .font(.callout).foregroundStyle(StudioTheme.secondary)
            }
            slider("Brightness", icon: "sun.max", key: \.level, event: .brightness)
            if cue.animated { slider("Speed", icon: "speedometer", key: \.speed, event: .speed) }
            if cue.on && cue.level < 48 {
                Text("Below 19% brightness, the keyboard turns its lights off on battery.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .onAppear { syncHex() }
        .onChange(of: cue) { _, _ in syncHex() }
        .onChange(of: index) { _, _ in syncHex() }
    }
    private var palette: some View {
        VStack(alignment: .leading, spacing: 12) {
            if cue.use == .several {
                HStack(spacing: 8) {
                    ForEach(0..<cue.colorCount, id: \.self) { i in
                        let t = cue.tints[min(i, cue.tints.count - 1)]
                        Button { slot = i; selectedSlot?.wrappedValue = i } label: {
                            HStack(spacing: 5) {
                                Circle().fill(t.color).frame(width: 10, height: 10)
                                Text(slotRoles(effect: cue.effect, count: cue.colorCount)[i]).font(.caption)
                            }.padding(.horizontal, 9).padding(.vertical, 7)
                        }.buttonStyle(StudioButton(selected: index == i))
                        .accessibilityLabel("Edit color \(i + 1)")
                    }
                    Spacer(minLength: 4)
                    Picker("Color count", selection: Binding(get: { cue.colorCount }, set: { n in
                        cue.setColorCount(n); slot = min(index, n - 1); selectedSlot?.wrappedValue = slot; changed(.palette)
                    })) { Text("2 colors").tag(2); Text("3 colors").tag(3) }
                    .labelsHidden().fixedSize()
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: compact ? 8 : 13), spacing: 6) {
                ForEach(Array(presets.enumerated()), id: \.offset) { _, p in
                    swatch(p.tint, name: p.name, diameter: 21)
                }
            }
            HStack(spacing: 10) {
                ColorPicker("Custom", selection: colorBinding, supportsOpacity: false)
                    .font(.callout).fixedSize()
                Spacer()
                Text("HEX").font(.caption).foregroundStyle(StudioTheme.secondary)
                TextField("#RRGGBB", text: $hex)
                    .font(.system(.callout, design: .monospaced))
                    .textFieldStyle(.roundedBorder).frame(width: 88)
                    .onSubmit(commitHex).accessibilityLabel("Hex color").help("RGB at the current global brightness. Applying HEX also updates brightness for the whole keyboard.")
                Button(action: commitHex) { Image(systemName: "checkmark") }
                    .buttonStyle(.borderless).help("Apply HEX color").accessibilityLabel("Apply hex color")
            }
            if invalidHex { Text("Enter six hexadecimal digits, for example #8855FF.").font(.caption).foregroundStyle(.orange) }
            if !library.recent.isEmpty {
                HStack(spacing: 8) {
                    Text("Recent").font(.caption).foregroundStyle(StudioTheme.secondary)
                    ForEach(Array(library.recent.enumerated()), id: \.offset) { _, t in swatch(t, name: t.hex, diameter: 15) }
                }
            }
        }
    }
    private func swatch(_ t: Tint, name: String, diameter: CGFloat) -> some View {
        Button { set(t) } label: {
            Circle().fill(t.color)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                .frame(width: diameter, height: diameter)
                .padding(3)
                .overlay(Circle().strokeBorder(t.near(tint) ? Color.white : Color.clear, lineWidth: 1.5))
                .contentShape(Circle())
        }.buttonStyle(.plain).help(name).accessibilityLabel("Set \(name)")
    }
    private func set(_ t: Tint) {
        cue.setTint(t, at: cue.use == .several ? index : 0)
        library.remember(t); invalidHex = false; syncHex(); changed(.palette)
    }
    private func syncHex() {
        let c = NSColor(hue: tint.hue, saturation: tint.saturation, brightness: cue.level / 255, alpha: 1).usingColorSpace(.deviceRGB)!
        hex = String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
        invalidHex = false
    }
    private func commitHex() {
        guard let parsed = Tint.parse(hex) else { invalidHex = true; return }
        // Palette colors are hue/saturation; brightness is global. A darker HEX also updates that global level.
        cue.level = parsed.level
        set(parsed.tint); changed(.brightness)
    }
    private func slider(_ name: String, icon: String, key: WritableKeyPath<Cue, Double>, event: ControlChange) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(StudioTheme.secondary).frame(width: 18)
            Text(name).frame(width: 66, alignment: .leading)
            Slider(value: Binding(get: { cue[keyPath: key] }, set: { cue[keyPath: key] = $0.rounded() }), in: 0...255) { editing in
                if !editing { changed(event) }
            }.controlSize(.small).accessibilityLabel(name)
            Text("\(Int((cue[keyPath: key] / 255 * 100).rounded()))%")
                .font(.callout.monospacedDigit()).foregroundStyle(StudioTheme.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

// Explicit visibility gates the preview clock, including menu windows retained offscreen by SwiftUI.
struct WindowVisibility: NSViewRepresentable {
    @Binding var visible: Bool
    func makeNSView(context: Context) -> Probe { Probe { value in visible = value } }
    func updateNSView(_ view: Probe, context: Context) { view.update = { visible = $0 } }
    final class Probe: NSView {
        var update: (Bool) -> Void
        var observer: NSObjectProtocol?
        init(_ update: @escaping (Bool) -> Void) { self.update = update; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in self?.publish() }
            publish()
        }
        func publish() {
            let value = window?.isVisible == true && window?.occlusionState.contains(.visible) == true
            DispatchQueue.main.async { [weak self] in self?.update(value) }
        }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}
