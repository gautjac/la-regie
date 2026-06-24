import AppKit

// MARK: - HUD — the brief "Décor : Montage" cue confirmation
//
// A small, non-activating panel that fades in centered near the top of the main
// screen when a cue fires, then fades out. Pure AppKit so it can appear over any
// app without stealing focus — the régie fires and gets out of the way.

@MainActor
enum HUD {
    private static var panel: NSPanel?
    private static var dismissWork: DispatchWorkItem?

    static func flash(emoji: String, title: String, accent: NSColor) {
        dismissWork?.cancel()
        panel?.orderOut(nil)

        let w: CGFloat = 320, h: CGFloat = 92
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                            styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let content = NSVisualEffectView(frame: panel.contentView!.bounds)
        content.material = .hudWindow
        content.blendingMode = .behindWindow
        content.state = .active
        content.wantsLayer = true
        content.layer?.cornerRadius = 18
        content.layer?.masksToBounds = true
        content.layer?.borderWidth = 1
        content.layer?.borderColor = accent.withAlphaComponent(0.55).cgColor
        content.autoresizingMask = [.width, .height]

        // Left accent bar — a "fader on" cue.
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: 5, height: h))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = accent.cgColor
        bar.autoresizingMask = [.height]
        content.addSubview(bar)

        let emojiLabel = NSTextField(labelWithString: emoji)
        emojiLabel.font = .systemFont(ofSize: 34)
        emojiLabel.frame = NSRect(x: 20, y: (h - 44) / 2, width: 44, height: 44)
        emojiLabel.alignment = .center
        content.addSubview(emojiLabel)

        let kicker = NSTextField(labelWithString: t("DÉCOR", "SCENE"))
        kicker.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        kicker.textColor = accent
        kicker.frame = NSRect(x: 76, y: h/2 + 4, width: w - 92, height: 16)
        content.addSubview(kicker)

        let nameLabel = NSTextField(labelWithString: title)
        nameLabel.font = .systemFont(ofSize: 21, weight: .bold)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.frame = NSRect(x: 76, y: h/2 - 26, width: w - 92, height: 28)
        content.addSubview(nameLabel)

        panel.contentView = content

        // Position: top-center of the main screen.
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            let x = f.midX - w/2
            let y = f.maxY - h - 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }
        HUD.panel = panel

        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                panel.animator().alphaValue = 0
            }, completionHandler: {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        panel.orderOut(nil)
                        if HUD.panel === panel { HUD.panel = nil }
                    }
                }
            })
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}
