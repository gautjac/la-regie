import Foundation
import AppKit

// MARK: - InstalledApps — enumerate the .app bundles the user can target
//
// We scan the standard application folders, read each bundle's display name and
// bundle id, and cache the result. Icons are fetched lazily by NSWorkspace.

struct InstalledApp: Identifiable, Equatable, Hashable {
    let id: String        // bundle id
    let name: String
    let path: String

    static func == (l: InstalledApp, r: InstalledApp) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum InstalledApps {
    private static var cache: [InstalledApp]?

    /// All installed apps, sorted by name. Cached after first scan.
    static func all(refresh: Bool = false) -> [InstalledApp] {
        if !refresh, let c = cache { return c }
        let fm = FileManager.default
        var dirs = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
        ]
        if let home = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path as String? {
            dirs.append(home)
        }

        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for dir in dirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let path = (dir as NSString).appendingPathComponent(entry)
                guard let bundle = Bundle(path: path),
                      let bid = bundle.bundleIdentifier, !seen.contains(bid) else { continue }
                seen.insert(bid)
                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? (entry as NSString).deletingPathExtension
                apps.append(InstalledApp(id: bid, name: name, path: path))
            }
        }
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cache = apps
        return apps
    }

    /// The icon for an app path, sized for the editor. NSWorkspace caches these.
    static func icon(forPath path: String, side: CGFloat = 18) -> NSImage {
        let img = NSWorkspace.shared.icon(forFile: path)
        img.size = NSSize(width: side, height: side)
        return img
    }

    static func app(forBundleID bid: String) -> InstalledApp? {
        all().first { $0.id == bid }
    }
}
