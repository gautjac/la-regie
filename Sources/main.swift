import AppKit

// La Régie runs as a menu-bar agent — no Dock icon, no main window.
// `La Régie selftest` runs a headless sanity check instead of launching the UI.

// Top-level code in main.swift runs on the main thread; assert that isolation so
// the main-actor AppDelegate / selftest can run without an async hop.
MainActor.assumeIsolated {
    if CommandLine.arguments.contains("selftest") {
        SelfTest.run()   // calls exit()
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
