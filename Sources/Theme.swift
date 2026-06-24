import SwiftUI

// MARK: - Theme — the régie's broadcast-console look
//
// Dark console panel, amber + green VU accents, a technical sans for copy and a
// mono for cues/levels. Centralized here so every view pulls the same palette.

enum Theme {
    // Console surfaces.
    static let bg        = Color(red: 0.055, green: 0.063, blue: 0.078) // deep panel
    static let panel     = Color(red: 0.086, green: 0.098, blue: 0.118) // raised strip
    static let panelHi   = Color(red: 0.118, green: 0.133, blue: 0.157) // hover / selected
    static let hairline  = Color.white.opacity(0.07)

    // Type.
    static let ink       = Color(red: 0.91, green: 0.92, blue: 0.94)
    static let inkDim    = Color(red: 0.58, green: 0.61, blue: 0.66)
    static let inkFaint  = Color(red: 0.40, green: 0.43, blue: 0.48)

    // VU accents.
    static let amber     = Color(red: 0.95, green: 0.69, blue: 0.27)
    static let green     = Color(red: 0.20, green: 0.85, blue: 0.50)
    static let red       = Color(red: 0.92, green: 0.34, blue: 0.30)

    static let mono = Font.system(.body, design: .monospaced)
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0xE8612C
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: 1)
    }

    /// "#RRGGBB" from a SwiftUI Color (best-effort via NSColor).
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .systemOrange
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
