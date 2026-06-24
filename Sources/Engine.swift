import Foundation
import AppKit

// MARK: - Engine — firing a cue
//
// `Engine.activate(_:)` runs a scene's actions top to bottom. Actions that touch
// other processes (launch/quit/hide) or the network of system properties run on
// a background queue so a slow step never blocks the menu bar; `delay` simply
// sleeps that worker for N seconds. Each step is best-effort and isolated: a
// failed step is logged and the cue continues.
//
// `dryRun: true` plans the cue without side effects — it returns the ordered list
// of human-readable step descriptions. The selftest uses this to verify the
// whole activation pipeline without quitting any of Jac's apps.

enum Engine {

    /// Result of planning/running a cue: the step lines, in order.
    @discardableResult
    static func activate(_ scene: Scene, dryRun: Bool = false) -> [String] {
        var lines: [String] = []
        for action in scene.actions {
            lines.append(describe(action))
        }
        guard !dryRun else { return lines }

        // Run the side-effecting work off the main thread, in order.
        DispatchQueue.global(qos: .userInitiated).async {
            for action in scene.actions {
                perform(action)
            }
        }
        return lines
    }

    /// A one-line description of a step (used for the dry-run plan & logging).
    static func describe(_ a: SceneAction) -> String {
        "\(a.kind.label): \(a.summary)"
    }

    // MARK: - the actual effects

    private static func perform(_ a: SceneAction) {
        switch a.kind {

        case .launchApp:
            launch(a)

        case .quitApp:
            forEachRunning(bundleID: a.bundleID) { $0.terminate() }

        case .hideApp:
            forEachRunning(bundleID: a.bundleID) { $0.hide() }

        case .hideOthers:
            let keep = Set(a.keepBundleIDs ?? [])
            let me = Bundle.main.bundleIdentifier
            for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular {
                guard let bid = app.bundleIdentifier else { continue }
                if bid == me { continue }            // never hide ourselves
                if keep.contains(bid) { continue }
                app.hide()
            }

        case .openItem:
            if let u = a.urlString, !u.isEmpty, let url = URL(string: u) {
                NSWorkspace.shared.open(url)
            } else if let p = a.path, !p.isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: p))
            }

        case .setAudioOutput:
            if let uid = a.audioDeviceUID { AudioOutput.setDefaultOutput(uid: uid) }

        case .setVolume:
            AudioOutput.setVolume(percent: a.volume ?? 50)

        case .setWallpaper:
            if let p = a.wallpaperPath, !p.isEmpty {
                setWallpaper(URL(fileURLWithPath: p))
            }

        case .runShortcut:
            if let n = a.shortcutName { Shortcuts.run(name: n) }

        case .delay:
            Thread.sleep(forTimeInterval: max(0, a.seconds ?? 0))
        }
    }

    private static func launch(_ a: SceneAction) {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        if let path = a.appPath, !path.isEmpty,
           FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path),
                                               configuration: cfg) { _, _ in }
        } else if let bid = a.bundleID,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in }
        }
    }

    private static func forEachRunning(bundleID: String?, _ body: (NSRunningApplication) -> Void) {
        guard let bid = bundleID else { return }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bid) {
            body(app)
        }
    }

    /// Set the desktop picture on every connected screen.
    static func setWallpaper(_ url: URL) {
        let ws = NSWorkspace.shared
        for screen in NSScreen.screens {
            try? ws.setDesktopImageURL(url, for: screen, options: [:])
        }
    }
}
