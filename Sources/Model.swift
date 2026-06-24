import Foundation
import AppKit

// MARK: - The data model — Scenes & Actions
//
// A SCENE ("décor" / "cue") is a named, ordered list of ACTIONS that reshape the
// whole Mac for one activity. One menu click — or a per-scene global hotkey —
// fires the cue: the actions run top to bottom.
//
// Everything here is Codable so the whole régie round-trips to JSON in
// ~/Library/Application Support/La Régie/scenes.json.

// MARK: Action kinds

/// The kind of an action. The raw value is the JSON discriminator — append new
/// kinds at the end, never renumber, so old files keep loading.
enum ActionKind: String, Codable, CaseIterable {
    case launchApp          // open an app by bundle id / path
    case quitApp            // terminate an app by bundle id
    case hideApp            // hide an app by bundle id
    case hideOthers         // hide every app except a keep-list
    case openItem           // open a file, folder, or URL
    case setAudioOutput     // switch the default system audio output device
    case setVolume          // set the system output volume (0–100)
    case setWallpaper       // set the desktop picture on every screen
    case runShortcut        // run a macOS Shortcut by name (Focus/DND bridge)
    case delay              // pause N seconds between steps

    var symbol: String {
        switch self {
        case .launchApp:      return "arrow.up.forward.app"
        case .quitApp:        return "xmark.app"
        case .hideApp:        return "eye.slash"
        case .hideOthers:     return "rectangle.on.rectangle.slash"
        case .openItem:       return "doc.text"
        case .setAudioOutput: return "hifispeaker"
        case .setVolume:      return "speaker.wave.2"
        case .setWallpaper:   return "photo"
        case .runShortcut:    return "wand.and.stars"
        case .delay:          return "hourglass"
        }
    }

    var label: String {
        switch self {
        case .launchApp:      return t("Lancer une app",            "Launch an app")
        case .quitApp:        return t("Quitter une app",           "Quit an app")
        case .hideApp:        return t("Masquer une app",           "Hide an app")
        case .hideOthers:     return t("Masquer les autres apps",   "Hide other apps")
        case .openItem:       return t("Ouvrir fichier / URL",      "Open file / URL")
        case .setAudioOutput: return t("Changer la sortie audio",   "Switch audio output")
        case .setVolume:      return t("Régler le volume",          "Set volume")
        case .setWallpaper:   return t("Changer le fond d'écran",   "Set wallpaper")
        case .runShortcut:    return t("Lancer un raccourci",       "Run a Shortcut")
        case .delay:          return t("Pause",                     "Delay")
        }
    }
}

// MARK: SceneAction

/// One step in a cue. Carries the kind plus a small bag of optional parameters;
/// only the fields relevant to the kind are used (and shown in the editor).
struct SceneAction: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: ActionKind

    // App targets (launch / quit / hide).
    var bundleID: String?       // primary identifier
    var appName: String?        // display name (cosmetic / fallback)
    var appPath: String?        // absolute path to the .app (launch fallback)

    // hideOthers keep-list: bundle ids that stay visible.
    var keepBundleIDs: [String]?

    // openItem: a file/folder path OR a URL string (exactly one).
    var path: String?
    var urlString: String?

    // setAudioOutput.
    var audioDeviceUID: String?
    var audioDeviceName: String?

    // setVolume (0...100).
    var volume: Int?

    // setWallpaper.
    var wallpaperPath: String?

    // runShortcut.
    var shortcutName: String?

    // delay.
    var seconds: Double?

    init(kind: ActionKind) { self.kind = kind }

    /// A one-line human summary of what this step will do, in the current language.
    var summary: String {
        switch kind {
        case .launchApp:
            return appName ?? bundleID ?? t("(choisir une app)", "(pick an app)")
        case .quitApp:
            return appName ?? bundleID ?? t("(choisir une app)", "(pick an app)")
        case .hideApp:
            return appName ?? bundleID ?? t("(choisir une app)", "(pick an app)")
        case .hideOthers:
            let n = keepBundleIDs?.count ?? 0
            return n == 0
                ? t("garder : rien", "keep: nothing")
                : t("garder \(n) app(s)", "keep \(n) app(s)")
        case .openItem:
            if let u = urlString, !u.isEmpty { return u }
            if let p = path, !p.isEmpty { return (p as NSString).lastPathComponent }
            return t("(choisir un élément)", "(pick an item)")
        case .setAudioOutput:
            return audioDeviceName ?? t("(choisir une sortie)", "(pick a device)")
        case .setVolume:
            return "\(volume ?? 50)%"
        case .setWallpaper:
            if let p = wallpaperPath, !p.isEmpty { return (p as NSString).lastPathComponent }
            return t("(choisir une image)", "(pick an image)")
        case .runShortcut:
            return shortcutName ?? t("(choisir un raccourci)", "(pick a Shortcut)")
        case .delay:
            return t("\(formatted(seconds ?? 1)) s", "\(formatted(seconds ?? 1)) s")
        }
    }

    private func formatted(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}

// MARK: Scene

struct Scene: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String           // a single glyph shown in menu + HUD
    var accentHex: String       // "#RRGGBB"
    var hotkey: KeyCombo?       // optional per-scene global hotkey
    var actions: [SceneAction]

    init(name: String, emoji: String, accentHex: String,
         hotkey: KeyCombo? = nil, actions: [SceneAction] = []) {
        self.name = name; self.emoji = emoji; self.accentHex = accentHex
        self.hotkey = hotkey; self.actions = actions
    }

    var accentColor: NSColor { NSColor(hex: accentHex) ?? .systemOrange }
}

// MARK: - Document (the whole régie, persisted as one JSON)

struct RegieDocument: Codable {
    var scenes: [Scene]
    var version: Int = 1
}

// MARK: - NSColor(hex:)

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}
