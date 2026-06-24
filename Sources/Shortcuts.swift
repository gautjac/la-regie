import Foundation

// MARK: - Shortcuts — the honest Focus / Do-Not-Disturb bridge
//
// macOS has no public API to set a Focus directly. The supported, working path
// is the `/usr/bin/shortcuts` CLI: the user makes a Shortcut (e.g. one with a
// "Set Focus" action), and La Régie runs it by name. We can also enumerate the
// user's Shortcuts so the editor offers a picker rather than a free-text field.

enum Shortcuts {
    static let cliPath = "/usr/bin/shortcuts"

    static var isAvailable: Bool { FileManager.default.isExecutableFile(atPath: cliPath) }

    /// All Shortcuts the user has, by name. Empty if the CLI is missing.
    static func list() -> [String] {
        guard isAvailable else { return [] }
        let out = runCapturing(arguments: ["list"])
        return out
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Build the command line we'd run for a given shortcut name — used by the
    /// selftest to verify quoting without actually launching anything.
    static func commandLine(for name: String) -> [String] {
        [cliPath, "run", name]
    }

    /// Run a Shortcut by name (fire-and-forget, off the main thread).
    static func run(name: String) {
        guard isAvailable, !name.isEmpty else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cliPath)
        proc.arguments = ["run", name]
        try? proc.run()
    }

    // MARK: - private

    private static func runCapturing(arguments: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: cliPath)
        proc.arguments = arguments
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
