// KeyGlow — control Keychron K3 Pro lighting from the Mac.
//
// What this app touches on your keyboard: it only SENDS the 1-byte lock-light
// report (HID output report ID 1). It never registers input callbacks and never
// reads keystrokes. macOS still files this under "Input Monitoring", because any
// direct conversation with a keyboard device needs that permission.
import SwiftUI
import IOKit.hid
import CoreGraphics

let keychronVID = 0x3434
let k3ProRGBPID = 0x0230

final class Keyboard: ObservableObject {
    @Published var found = false
    @Published var transport = ""
    @Published var accessGranted = false
    @Published var message = ""
    @Published var busy = false
    enum SendState { case idle, ok, failed }
    @Published var lastSend: SendState = .idle

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private let devLock = NSLock()          // device/opened are touched by main + sender queue
    private var device: IOHIDDevice?
    private var opened = false
    private var timer: Timer?

    /// live: false builds a stand-in for screenshots (no HID access).
    init(live: Bool = true) {
        guard live else { return }
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: keychronVID,
            kIOHIDProductIDKey: k3ProRGBPID,
        ] as CFDictionary)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, dev in
            Unmanaged<Keyboard>.fromOpaque(ctx!).takeUnretainedValue().attach(dev)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, dev in
            Unmanaged<Keyboard>.fromOpaque(ctx!).takeUnretainedValue().detach(dev)
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        refreshAccess()
        // Pick up a permission change made in System Settings without a relaunch.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshAccess()
        }
    }

    // Only the keyboard collection carries the lock-light output report.
    private func attach(_ dev: IOHIDDevice) {
        let outSize = IOHIDDeviceGetProperty(dev, kIOHIDMaxOutputReportSizeKey as CFString) as? Int ?? 0
        guard outSize > 0 else { return }
        devLock.lock(); device = dev; opened = false; devLock.unlock()
        found = true
        transport = IOHIDDeviceGetProperty(dev, kIOHIDTransportKey as CFString) as? String ?? "?"
    }

    private func detach(_ dev: IOHIDDevice) {
        devLock.lock()
        guard dev == device else { devLock.unlock(); return }
        device = nil
        opened = false
        devLock.unlock()
        found = false
        transport = ""
    }

    func refreshAccess() {
        let granted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if granted != accessGranted { accessGranted = granted }
    }

    func requestAccess() {
        // Shows the macOS prompt the first time and adds KeyGlow to the Input Monitoring list.
        if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) {
            NSWorkspace.shared.open(URL(string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        }
        refreshAccess()
    }

    /// Send one lock-light byte to the keyboard (bit0 Num, bit1 Caps, bit2 Scroll, bit3 Compose, bit4 Kana).
    @discardableResult
    func sendLEDs(_ leds: UInt8) -> IOReturn {
        devLock.lock(); defer { devLock.unlock() }
        guard let dev = device else { return kIOReturnNoDevice }
        if !opened {
            let r = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone)) // never seize: typing keeps working
            guard r == kIOReturnSuccess else { return r }
            opened = true
        }
        var report: [UInt8] = [0x01, leds]
        return IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 1, &report, report.count)
    }

    /// The real Caps Lock state, so we can put the light back exactly as it was.
    var capsBit: UInt8 {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift) ? 0x02 : 0x00
    }

    func testLight() {
        let restore = capsBit
        let r = sendLEDs(restore ^ 0x02)
        guard r == kIOReturnSuccess else {
            message = r == kIOReturnNotPermitted
                ? "macOS blocked it. Turn on KeyGlow in Input Monitoring, then reopen KeyGlow."
                : String(format: "Couldn't send (error 0x%08x).", r)
            return
        }
        busy = true
        message = "Look at your keyboard: the Caps Lock light should flip for 3 seconds…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.sendLEDs(restore)
            self.busy = false
            self.message = "Done. Did the Caps Lock light flip? (Caps Lock itself stayed off.)"
        }
    }

    // MARK: - Command sender (must match keyglow.c in the firmware)
    //
    // One LED report = one frame. bit4 (Kana) is a clock that toggles every frame;
    // bit0 Num, bit2 Scroll, bit3 Compose carry 3 data bits; bit1 Caps is always the real Caps state.
    // Byte = 3 frames MSB first. Packet = A5 seq cmd a b c xor(seq..c), plus one padding
    // frame so the clock ends where it started. Each packet is sent twice; the firmware
    // ignores the repeat by its sequence number.

    enum Cmd: UInt8 { case effect = 1, hsv = 2, speed = 3, power = 4, view = 5, ping = 6, battery = 7, color2 = 8, color3 = 9 }

    @Published var sending = false
    @Published var inFlight = 0          // commands queued or being sent
    @Published var frameMs: Double = 25 { didSet { lock.lock(); frameUs = useconds_t(frameMs * 1000); lock.unlock() } }
    private var frameUs: useconds_t = 25_000

    private let sendQueue = DispatchQueue(label: "keyglow.sender")
    private let lock = NSLock()
    private var pending: [UInt8: (UInt8, UInt8, UInt8)] = [:]   // latest value per command
    private var order: [UInt8] = []
    private var workerRunning = false
    private var clock: UInt8 = 0
    private var seq = UInt8.random(in: 0...255)  // random start: a relaunch never repeats the firmware's last seq

    /// Queue a command. If the same command is already waiting, only the newest value is sent.
    func send(_ cmd: Cmd, _ a: UInt8 = 0, _ b: UInt8 = 0, _ c: UInt8 = 0) {
        lock.lock()
        if pending[cmd.rawValue] == nil { order.append(cmd.rawValue) }
        pending[cmd.rawValue] = (a, b, c)
        let start = !workerRunning
        workerRunning = true
        let n = order.count + (start ? 0 : 1)
        lock.unlock()
        DispatchQueue.main.async { self.inFlight = n }
        guard start else { return }
        DispatchQueue.main.async { self.sending = true }
        sendQueue.async { self.drain() }
    }

    private func drain() {
        var failed = false
        while true {
            lock.lock()
            guard !order.isEmpty else {
                workerRunning = false
                lock.unlock()
                break
            }
            let remaining = order.count
            DispatchQueue.main.async { self.inFlight = remaining }
            let cmd = order.removeFirst()
            let args = pending.removeValue(forKey: cmd)!
            lock.unlock()

            seq &+= 1
            let body: [UInt8] = [seq, cmd, args.0, args.1, args.2]
            let packet = [0xA5] + body + [body.reduce(0, ^)]
            let result = transmit(packet)
            if result != kIOReturnSuccess {
                DispatchQueue.main.async {
                    self.message = result == kIOReturnNotPermitted
                        ? "macOS blocked it. Turn on KeyGlow in Input Monitoring, then reopen KeyGlow."
                        : String(format: "Couldn't send (error 0x%08x). Is the keyboard connected?", result)
                }
                lock.lock(); order.removeAll(); pending.removeAll(); workerRunning = false; lock.unlock()
                failed = true
                clock = 0
                _ = sendLEDs(capsBit)       // back to a clean idle state so the next packet lines up
                break
            }
            usleep(400_000)                 // idle gap (> 150 ms): firmware resets between packets
            _ = transmit(packet)            // deliberate repeat, in case a frame was lost
            usleep(400_000)
        }
        DispatchQueue.main.async {
            self.sending = false
            self.inFlight = 0
            self.lastSend = failed ? .failed : .ok
            if !failed { self.message = "" }
        }
    }

    private func transmit(_ packet: [UInt8]) -> IOReturn {
        var frames: [UInt8] = []
        for b in packet { frames += [(b >> 5) & 7, (b >> 2) & 7, b & 3] }
        frames.append(0)                    // padding: 22 frames, so the clock returns to its start
        lock.lock(); let delay = frameUs; lock.unlock()
        for d in frames {
            clock ^= 1
            let leds = capsBit | (d & 1) | (((d >> 1) & 1) << 2) | (((d >> 2) & 1) << 3) | (clock << 4)
            let r = sendLEDs(leds)
            if r != kIOReturnSuccess { return r }
            usleep(delay)
        }
        return kIOReturnSuccess
    }

    /// Diagnostics: put raw bits on the wire (see them on keys 1–5 with Fn+V).
    func sendRaw(num: Bool, scroll: Bool, compose: Bool, kana: Bool) {
        let leds = capsBit | (num ? 1 : 0) | (scroll ? 4 : 0) | (compose ? 8 : 0) | (kana ? 16 : 0)
        sendQueue.async {
            self.clock = kana ? 1 : 0   // keep our clock in step with what the firmware last saw
            _ = self.sendLEDs(leds)
        }
    }
}

