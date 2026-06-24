import AppKit
import SwiftUI

// MARK: - AppDelegate — the menu bar & the editor window
//
// The status item shows a régie-console glyph. Clicking it drops a menu listing
// every scene (emoji + name + its hotkey on the right) for one-click activation,
// plus "Éditer les décors…", the FR|EN switch, and Quit. The editor opens a
// single standalone SwiftUI window.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) weak var shared: AppDelegate?

    private var statusItem: NSStatusItem!
    private let store = Store.shared
    private var editorWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "slider.horizontal.3",
                                   accessibilityDescription: "La Régie")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self        // rebuild on each open so it's always current
        statusItem.menu = menu

        // Warm the app catalog so the editor's app picker is instant.
        DispatchQueue.global(qos: .utility).async { _ = InstalledApps.all() }

        // Register every scene's global hotkey.
        store.rebindHotkeys()
    }

    // MARK: - Menu (rebuilt each time it opens)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: t("Décors", "Scenes"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if store.scenes.isEmpty {
            let empty = NSMenuItem(title: t("Aucun décor — Éditer pour en créer",
                                            "No scenes — Edit to create one"),
                                   action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for scene in store.scenes {
                let item = NSMenuItem(title: "  \(scene.emoji)  \(scene.name)",
                                      action: #selector(fireScene(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = scene.id
                // Show the hotkey as a trailing hint (not a real key equivalent —
                // it's already a global hotkey via Carbon).
                if let hk = scene.hotkey {
                    item.attributedTitle = menuTitle(scene: scene, hint: hk.display)
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let edit = NSMenuItem(title: t("Éditer les décors…", "Edit scenes…"),
                              action: #selector(openEditor), keyEquivalent: ",")
        edit.target = self
        menu.addItem(edit)

        // FR | EN language switch.
        let langTitle = Loc.shared.lang == .fr ? "Langue : Français  →  English"
                                               : "Language: English  →  Français"
        let lang = NSMenuItem(title: langTitle, action: #selector(toggleLang), keyEquivalent: "")
        lang.target = self
        menu.addItem(lang)

        menu.addItem(.separator())

        let about = NSMenuItem(title: t("À propos de La Régie", "About La Régie"),
                               action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: t("Quitter La Régie", "Quit La Régie"),
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    /// A two-part attributed title: "  🎬  Montage" on the left, the hotkey hint
    /// dimmed and right-aligned via a tab stop.
    private func menuTitle(scene: Scene, hint: String) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.tabStops = [NSTextTab(textAlignment: .right, location: 240)]
        let s = NSMutableAttributedString(
            string: "  \(scene.emoji)  \(scene.name)\t\(hint)")
        s.addAttributes([.paragraphStyle: para,
                         .font: NSFont.menuFont(ofSize: 0)],
                        range: NSRange(location: 0, length: s.length))
        // Dim the hint.
        if let r = s.string.range(of: hint) {
            s.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor,
                           range: NSRange(r, in: s.string))
        }
        return s
    }

    @objc private func fireScene(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let scene = store.scene(withID: id) else { return }
        store.activate(scene)
    }

    @objc private func toggleLang() { Loc.shared.toggle() }

    @objc private func showAbout() {
        let a = NSAlert()
        a.messageText = "La Régie"
        a.informativeText = t(
            "La salle de contrôle de ton Mac.\nDéfinis des décors — des suites d'actions — et déclenche-les d'un clic ou d'un raccourci global.\n\nFait dans l'Atelier.",
            "Your Mac's control room.\nDefine scenes — ordered sequences of actions — and fire them with one click or a global hotkey.\n\nMade in the Atelier.")
        a.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }

    // MARK: - Editor window

    @objc func openEditor() {
        if let win = editorWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = EditorView().environmentObject(store).environmentObject(Loc.shared)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = t("La Régie — Décors", "La Régie — Scenes")
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.setContentSize(NSSize(width: 880, height: 600))
        win.minSize = NSSize(width: 720, height: 460)
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        editorWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === editorWindow {
            editorWindow = nil
        }
    }
}
