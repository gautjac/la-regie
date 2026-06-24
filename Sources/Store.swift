import Foundation
import AppKit
import Carbon.HIToolbox
import Combine

// MARK: - Store — the régie's single source of truth
//
// Holds the scenes, persists them to JSON, (re)registers per-scene global
// hotkeys, and exposes `activate` (which fires a cue and flashes the HUD). The
// AppDelegate, the menu, and the editor all talk to this one object.

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var scenes: [Scene] = [] {
        didSet { save(); rebindHotkeys() }
    }

    /// Called whenever scenes change, so the AppDelegate can rebuild the menu.
    var onScenesChanged: (() -> Void)?

    // Where the régie lives: ~/Library/Application Support/La Régie/scenes.json
    private let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("La Régie", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("scenes.json")
    }()

    private init() {
        load()
    }

    // MARK: - Activation

    /// Fire a cue: run its actions and flash the HUD.
    func activate(_ scene: Scene) {
        Engine.activate(scene)
        HUD.flash(emoji: scene.emoji,
                  title: scene.name,
                  accent: scene.accentColor)
    }

    func scene(withID id: UUID) -> Scene? { scenes.first { $0.id == id } }

    // MARK: - CRUD helpers used by the editor

    func addScene() {
        let palette = ["#E8612C", "#3B82F6", "#10B981", "#A855F7", "#F59E0B", "#EC4899"]
        let emojis = ["🎬", "✍️", "☕️", "🎚️", "🎧", "🌙", "🔬", "🎙️"]
        var s = Scene(name: t("Nouveau décor", "New scene"),
                      emoji: emojis.randomElement()!,
                      accentHex: palette[scenes.count % palette.count])
        s.actions = []
        scenes.append(s)
    }

    func deleteScene(_ id: UUID) {
        scenes.removeAll { $0.id == id }
    }

    func update(_ scene: Scene) {
        guard let i = scenes.firstIndex(where: { $0.id == scene.id }) else { return }
        scenes[i] = scene
    }

    // MARK: - Hotkeys

    /// Re-register every scene's global hotkey. Called after any change.
    func rebindHotkeys() {
        HotkeyManager.shared.unbindAll()
        for scene in scenes {
            guard let combo = scene.hotkey else { continue }
            let id = scene.id
            HotkeyManager.shared.bind(action: id.uuidString, to: combo) { [weak self] in
                guard let self, let s = self.scene(withID: id) else { return }
                self.activate(s)
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        let doc = RegieDocument(scenes: scenes)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(doc) {
            try? data.write(to: fileURL, options: .atomic)
        }
        onScenesChanged?()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let doc = try? JSONDecoder().decode(RegieDocument.self, from: data) else {
            // First run: seed the example scenes so it's immediately impressive.
            scenes = Store.seedScenes()
            return
        }
        scenes = doc.scenes
    }

    // MARK: - Seed scenes (first run)

    nonisolated static func seedScenes() -> [Scene] {
        // Resolve a couple of common apps so launch steps point somewhere real.
        func bid(_ id: String) -> InstalledApp? { InstalledApps.app(forBundleID: id) }

        func launch(_ id: String, _ fallbackName: String) -> SceneAction {
            var a = SceneAction(kind: .launchApp)
            if let app = bid(id) {
                a.bundleID = app.id; a.appName = app.name; a.appPath = app.path
            } else {
                a.bundleID = id; a.appName = fallbackName
            }
            return a
        }

        func quit(_ id: String, _ name: String) -> SceneAction {
            var a = SceneAction(kind: .quitApp); a.bundleID = id; a.appName = name; return a
        }

        // ── Montage ──────────────────────────────────────────────
        var montage = Scene(name: t("Montage", "Editing"),
                            emoji: "🎬", accentHex: "#E8612C",
                            hotkey: KeyCombo(keyCode: UInt32(kVK_ANSI_1),
                                             modifiers: [.control, .option, .command]))
        montage.actions = [
            launch("com.apple.FinalCut", "Final Cut Pro"),
            launch("com.apple.Music", "Music"),
            { var a = SceneAction(kind: .hideOthers)
              a.keepBundleIDs = ["com.apple.FinalCut", "com.apple.Music"]; return a }(),
            { var a = SceneAction(kind: .setVolume); a.volume = 65; return a }(),
        ]

        // ── Écriture ─────────────────────────────────────────────
        var ecriture = Scene(name: t("Écriture", "Writing"),
                             emoji: "✍️", accentHex: "#3B82F6",
                             hotkey: KeyCombo(keyCode: UInt32(kVK_ANSI_2),
                                              modifiers: [.control, .option, .command]))
        ecriture.actions = [
            quit("com.apple.mail", "Mail"),
            quit("com.tinyspeck.slackmacgap", "Slack"),
            { var a = SceneAction(kind: .hideOthers); a.keepBundleIDs = []; return a }(),
            launch("com.apple.TextEdit", "TextEdit"),
            { var a = SceneAction(kind: .setVolume); a.volume = 20; return a }(),
        ]

        // ── Pause ────────────────────────────────────────────────
        var pause = Scene(name: t("Pause", "Break"),
                          emoji: "☕️", accentHex: "#10B981",
                          hotkey: KeyCombo(keyCode: UInt32(kVK_ANSI_3),
                                           modifiers: [.control, .option, .command]))
        pause.actions = [
            { var a = SceneAction(kind: .hideOthers); a.keepBundleIDs = []; return a }(),
            { var a = SceneAction(kind: .openItem)
              a.urlString = "https://www.youtube.com/results?search_query=lofi"; return a }(),
            { var a = SceneAction(kind: .setVolume); a.volume = 45; return a }(),
        ]

        return [montage, ecriture, pause]
    }
}
