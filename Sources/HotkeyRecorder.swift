import SwiftUI
import AppKit

// MARK: - HotkeyRecorder — click to record a global combo
//
// A small NSView wrapped for SwiftUI. Click it, press a modifier+key combination,
// and it reports the new KeyCombo. Esc cancels; a combo with no ⌘/⌥/⌃ beeps
// (global hotkeys need a non-shift modifier to be safe). Pass nil combo to show
// "unset".

struct HotkeyRecorder: NSViewRepresentable {
    var combo: KeyCombo?
    var onChange: (KeyCombo?) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let v = RecorderView()
        v.combo = combo
        v.onChange = onChange
        return v
    }
    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.combo = combo
        nsView.onChange = onChange
        nsView.needsDisplay = true
    }

    final class RecorderView: NSView {
        var combo: KeyCombo? { didSet { needsDisplay = true } }
        var onChange: ((KeyCombo?) -> Void)?
        private var recording = false { didSet { needsDisplay = true } }
        private nonisolated(unsafe) var monitor: Any?

        override var intrinsicContentSize: NSSize { NSSize(width: 132, height: 30) }
        override var acceptsFirstResponder: Bool { true }
        override var wantsUpdateLayer: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            let amber = NSColor(srgbRed: 0.95, green: 0.69, blue: 0.27, alpha: 1)
            let rect = bounds.insetBy(dx: 1, dy: 1)
            let bg = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
            (recording ? amber.withAlphaComponent(0.16)
                       : NSColor(srgbRed: 0.118, green: 0.133, blue: 0.157, alpha: 1)).setFill()
            bg.fill()
            let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
            (recording ? amber.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.10)).setStroke()
            border.lineWidth = recording ? 1.6 : 1
            border.stroke()

            let text: String
            if recording { text = t("Presse…", "Press…") }
            else if let c = combo { text = c.display }
            else { text = t("aucun", "none") }

            let color: NSColor = recording ? amber
                : (combo == nil ? NSColor(srgbRed: 0.40, green: 0.43, blue: 0.48, alpha: 1)
                                : NSColor(srgbRed: 0.91, green: 0.92, blue: 0.94, alpha: 1))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: color
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let size = str.size()
            str.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                 y: (bounds.height - size.height) / 2))
        }

        override func mouseDown(with event: NSEvent) {
            recording.toggle()
            if recording { window?.makeFirstResponder(self); installMonitor() }
            else { removeMonitor() }
        }

        override func rightMouseDown(with event: NSEvent) {
            // Right-click clears the binding.
            recording = false
            removeMonitor()
            combo = nil
            onChange?(nil)
        }

        private func installMonitor() {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.recording else { return event }
                if event.keyCode == 53 { // Esc cancels
                    self.recording = false; self.removeMonitor(); return nil
                }
                let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
                guard mods.contains(.command) || mods.contains(.option) || mods.contains(.control) else {
                    NSSound.beep(); return nil
                }
                let newCombo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods)
                self.combo = newCombo
                self.onChange?(newCombo)
                self.recording = false
                self.removeMonitor()
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
