import Foundation
import AppKit
import Carbon.HIToolbox

// MARK: - SelfTest — headless sanity check (`La Régie selftest`)
//
// Exercises the pure logic without firing anything destructive:
//   • enumerate audio output devices
//   • enumerate installed apps
//   • JSON round-trip of a seeded scene
//   • build a Shortcuts command line (correct quoting)
//   • dry-run activation of every seeded scene (plan only, no side effects)
//   • KeyCombo display + Carbon modifier mapping
// Exits non-zero on the first hard failure so build.sh can gate on it.

enum SelfTest {
    @MainActor
    static func run() {
        var failures = 0
        func check(_ name: String, _ cond: Bool, _ detail: String = "") {
            let mark = cond ? "✓" : "✗"
            print("  \(mark) \(name)\(detail.isEmpty ? "" : "  — \(detail)")")
            if !cond { failures += 1 }
        }

        print("La Régie — selftest")

        // 1. Audio devices.
        let devices = AudioOutput.outputDevices()
        check("audio: enumerated output devices", !devices.isEmpty,
              "\(devices.count) device(s): " + devices.prefix(3).map { $0.name }.joined(separator: ", "))
        let curUID = AudioOutput.currentDefaultUID()
        check("audio: read current default output", curUID != nil,
              curUID.flatMap { uid in devices.first { $0.uid == uid }?.name } ?? "?")

        // 2. Installed apps.
        let apps = InstalledApps.all()
        check("apps: scanned installed bundles", apps.count > 5, "\(apps.count) app(s)")
        // A reliably-present, regular app in /System/Applications.
        let known = apps.first { $0.id == "com.apple.systempreferences" }
            ?? apps.first { $0.id == "com.apple.Safari" }
        check("apps: found a known bundle", known != nil, known?.name ?? "—")

        // 3. JSON round-trip of a scene.
        var scene = Scene(name: "Test décor", emoji: "🎛️", accentHex: "#E8612C",
                          hotkey: KeyCombo(keyCode: UInt32(kVK_ANSI_9),
                                           modifiers: [.control, .option, .command]))
        var la = SceneAction(kind: .launchApp); la.bundleID = "com.apple.TextEdit"; la.appName = "TextEdit"
        var vol = SceneAction(kind: .setVolume); vol.volume = 42
        var dl = SceneAction(kind: .delay); dl.seconds = 1.5
        scene.actions = [la, vol, dl]
        let doc = RegieDocument(scenes: [scene])
        var roundTripOK = false
        if let data = try? JSONEncoder().encode(doc),
           let back = try? JSONDecoder().decode(RegieDocument.self, from: data),
           let s = back.scenes.first {
            roundTripOK = s.name == scene.name
                && s.actions.count == 3
                && s.hotkey == scene.hotkey
                && s.actions[1].volume == 42
        }
        check("json: scene round-trips losslessly", roundTripOK)

        // 4. Shortcuts command line quoting.
        let cmd = Shortcuts.commandLine(for: "Mettre le Focus Montage")
        check("shortcuts: command line built",
              cmd == ["/usr/bin/shortcuts", "run", "Mettre le Focus Montage"],
              cmd.joined(separator: " "))
        check("shortcuts: CLI present on this Mac", Shortcuts.isAvailable, Shortcuts.cliPath)

        // 5. Dry-run activation of every seeded scene (plan only — no effects).
        let seeded = Store.seedScenes()
        check("seed: produced example scenes", seeded.count == 3, "\(seeded.count)")
        for s in seeded {
            let plan = Engine.activate(s, dryRun: true)
            check("activate(dry): \(s.name)", plan.count == s.actions.count,
                  "\(plan.count) step(s)")
        }

        // 6. KeyCombo display + Carbon mapping.
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_1),
                             modifiers: [.control, .option, .command])
        check("keycombo: display glyphs", combo.display == "⌃⌥⌘1", combo.display)
        check("keycombo: carbon modifier mask non-zero", combo.carbonModifiers != 0)

        print(failures == 0
              ? "\nAll checks passed."
              : "\n\(failures) check(s) FAILED.")
        exit(failures == 0 ? 0 : 1)
    }
}
