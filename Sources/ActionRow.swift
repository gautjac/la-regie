import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - ActionRow — one channel strip in the cue
//
// A numbered strip: order controls, the action's icon + label, an inline param
// editor specific to the kind, and a delete button. Friendly pickers (app, audio
// device, file, shortcut) keep the params honest — no free-text bundle ids.

struct ActionRow: View {
    let index: Int
    @Binding var action: SceneAction
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Order column.
            VStack(spacing: 2) {
                Button(action: onMoveUp) { Image(systemName: "chevron.up") }
                    .buttonStyle(.plain).disabled(!canMoveUp)
                    .foregroundStyle(canMoveUp ? Theme.inkDim : Theme.inkFaint.opacity(0.4))
                Text("\(index + 1)")
                    .font(Theme.mono(11, .bold)).foregroundStyle(Theme.inkDim)
                Button(action: onMoveDown) { Image(systemName: "chevron.down") }
                    .buttonStyle(.plain).disabled(!canMoveDown)
                    .foregroundStyle(canMoveDown ? Theme.inkDim : Theme.inkFaint.opacity(0.4))
            }
            .frame(width: 22)

            // Kind icon.
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Theme.bg)
                    .frame(width: 34, height: 34)
                Image(systemName: action.kind.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.amber)
            }

            // Label + inline editor.
            VStack(alignment: .leading, spacing: 4) {
                Text(action.kind.label)
                    .font(Theme.sans(12, .semibold)).foregroundStyle(Theme.ink)
                ActionParamEditor(action: $action)
            }

            Spacer(minLength: 8)

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Theme.inkFaint)
            }
            .buttonStyle(.plain)
            .help(t("Retirer cette action", "Remove this action"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - ActionParamEditor — the friendly picker per kind

private struct ActionParamEditor: View {
    @Binding var action: SceneAction

    var body: some View {
        switch action.kind {
        case .launchApp, .quitApp, .hideApp:
            AppPicker(bundleID: $action.bundleID, appName: $action.appName, appPath: $action.appPath)
        case .hideOthers:
            KeepListPicker(keep: $action.keepBundleIDs)
        case .openItem:
            OpenItemEditor(path: $action.path, urlString: $action.urlString)
        case .setAudioOutput:
            AudioPicker(uid: $action.audioDeviceUID, name: $action.audioDeviceName)
        case .setVolume:
            VolumeSlider(volume: $action.volume)
        case .setWallpaper:
            WallpaperPicker(path: $action.wallpaperPath)
        case .runShortcut:
            ShortcutPicker(name: $action.shortcutName)
        case .delay:
            DelayEditor(seconds: $action.seconds)
        }
    }
}

// MARK: - App picker (icons)

private struct AppPicker: View {
    @Binding var bundleID: String?
    @Binding var appName: String?
    @Binding var appPath: String?

    var body: some View {
        Menu {
            ForEach(InstalledApps.all(), id: \.id) { app in
                Button(action: {
                    bundleID = app.id; appName = app.name; appPath = app.path
                }) { Text(app.name) }
            }
        } label: {
            HStack(spacing: 6) {
                if let p = appPath, FileManager.default.fileExists(atPath: p) {
                    Image(nsImage: InstalledApps.icon(forPath: p))
                } else {
                    Image(systemName: "app.dashed").foregroundStyle(Theme.inkFaint)
                }
                Text(appName ?? t("Choisir une app…", "Choose an app…"))
                    .foregroundStyle(appName == nil ? Theme.inkFaint : Theme.inkDim)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8)).foregroundStyle(Theme.inkFaint)
            }
            .font(Theme.sans(12))
        }
        .menuStyle(.borderlessButton).fixedSize()
    }
}

// MARK: - Keep-list (hide others)

private struct KeepListPicker: View {
    @Binding var keep: [String]?

    private var keptApps: [InstalledApp] {
        (keep ?? []).compactMap { InstalledApps.app(forBundleID: $0) }
    }

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Text(t("Garder visibles :", "Keep visible:"))
                ForEach(InstalledApps.all(), id: \.id) { app in
                    Button(action: { toggle(app.id) }) {
                        Label(app.name,
                              systemImage: (keep ?? []).contains(app.id) ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle").foregroundStyle(Theme.inkDim)
                    Text(t("Ajouter à la liste", "Add to keep-list"))
                        .foregroundStyle(Theme.inkDim)
                }
                .font(Theme.sans(12))
            }
            .menuStyle(.borderlessButton).fixedSize()

            if keptApps.isEmpty {
                Text(t("(masque tout sauf La Régie)", "(hides all but La Régie)"))
                    .font(Theme.mono(10)).foregroundStyle(Theme.inkFaint)
            } else {
                ForEach(keptApps, id: \.id) { app in
                    HStack(spacing: 3) {
                        Image(nsImage: InstalledApps.icon(forPath: app.path, side: 14))
                        Button(action: { toggle(app.id) }) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 9))
                        }.buttonStyle(.plain).foregroundStyle(Theme.inkFaint)
                    }
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.bg))
                }
            }
        }
    }

    private func toggle(_ bid: String) {
        var s = Set(keep ?? [])
        if s.contains(bid) { s.remove(bid) } else { s.insert(bid) }
        keep = Array(s)
    }
}

// MARK: - Open item (file/folder/URL)

private struct OpenItemEditor: View {
    @Binding var path: String?
    @Binding var urlString: String?
    @State private var url: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Button(action: pickFile) {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                    Text(t("Fichier / dossier…", "File / folder…"))
                }.font(Theme.sans(12)).foregroundStyle(Theme.inkDim)
            }.buttonStyle(.plain)

            if let p = path, !p.isEmpty {
                Text((p as NSString).lastPathComponent)
                    .font(Theme.mono(11)).foregroundStyle(Theme.amber).lineLimit(1)
            }

            Text(t("ou", "or")).font(Theme.sans(11)).foregroundStyle(Theme.inkFaint)

            HStack(spacing: 4) {
                Image(systemName: "link").font(.system(size: 10)).foregroundStyle(Theme.inkFaint)
                TextField("https://…", text: $url)
                    .textFieldStyle(.plain)
                    .font(Theme.mono(11)).foregroundStyle(Theme.ink)
                    .frame(width: 200)
                    .onChange(of: url) { _, v in
                        urlString = v.isEmpty ? nil : v
                        if !v.isEmpty { path = nil }
                    }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bg))
        }
        .onAppear { url = urlString ?? "" }
    }

    private func pickFile() {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.canChooseDirectories = true; p.allowsMultipleSelection = false
        if p.runModal() == .OK, let u = p.url {
            path = u.path; urlString = nil; url = ""
        }
    }
}

// MARK: - Audio output picker

private struct AudioPicker: View {
    @Binding var uid: String?
    @Binding var name: String?
    @State private var devices: [AudioDevice] = []

    var body: some View {
        Menu {
            ForEach(devices) { dev in
                Button(action: { uid = dev.uid; name = dev.name }) { Text(dev.name) }
            }
            if devices.isEmpty { Text(t("Aucun appareil", "No devices")) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hifispeaker").foregroundStyle(Theme.inkDim)
                Text(name ?? t("Choisir une sortie…", "Choose a device…"))
                    .foregroundStyle(name == nil ? Theme.inkFaint : Theme.inkDim)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8)).foregroundStyle(Theme.inkFaint)
            }.font(Theme.sans(12))
        }
        .menuStyle(.borderlessButton).fixedSize()
        .onAppear { devices = AudioOutput.outputDevices() }
    }
}

// MARK: - Volume slider

private struct VolumeSlider: View {
    @Binding var volume: Int?
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill").font(.system(size: 10)).foregroundStyle(Theme.inkFaint)
            Slider(value: Binding(
                get: { Double(volume ?? 50) },
                set: { volume = Int($0) }), in: 0...100)
                .frame(width: 180)
                .tint(Theme.green)
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 10)).foregroundStyle(Theme.inkFaint)
            Text("\(volume ?? 50)%")
                .font(Theme.mono(12, .semibold)).foregroundStyle(Theme.amber)
                .frame(width: 42, alignment: .trailing)
        }
    }
}

// MARK: - Wallpaper picker

private struct WallpaperPicker: View {
    @Binding var path: String?
    var body: some View {
        HStack(spacing: 8) {
            Button(action: pick) {
                HStack(spacing: 5) {
                    Image(systemName: "photo")
                    Text(t("Choisir une image…", "Choose an image…"))
                }.font(Theme.sans(12)).foregroundStyle(Theme.inkDim)
            }.buttonStyle(.plain)

            if let p = path, !p.isEmpty {
                if let img = NSImage(contentsOfFile: p) {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 24).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text((p as NSString).lastPathComponent)
                    .font(Theme.mono(11)).foregroundStyle(Theme.amber).lineLimit(1)
            }
        }
    }
    private func pick() {
        let p = NSOpenPanel()
        p.canChooseFiles = true; p.allowsMultipleSelection = false
        p.allowedContentTypes = [.image]
        if p.runModal() == .OK, let u = p.url { path = u.path }
    }
}

// MARK: - Shortcut picker

private struct ShortcutPicker: View {
    @Binding var name: String?
    @State private var shortcuts: [String] = []

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if shortcuts.isEmpty {
                    Text(t("Aucun raccourci trouvé", "No shortcuts found"))
                }
                ForEach(shortcuts, id: \.self) { s in
                    Button(action: { name = s }) { Text(s) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").foregroundStyle(Theme.inkDim)
                    Text(name ?? t("Choisir un raccourci…", "Choose a Shortcut…"))
                        .foregroundStyle(name == nil ? Theme.inkFaint : Theme.inkDim)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8)).foregroundStyle(Theme.inkFaint)
                }.font(Theme.sans(12))
            }
            .menuStyle(.borderlessButton).fixedSize()
            Text(t("· pont Focus / Ne pas déranger", "· Focus / Do-Not-Disturb bridge"))
                .font(Theme.mono(9)).foregroundStyle(Theme.inkFaint)
        }
        .onAppear { shortcuts = Shortcuts.list() }
    }
}

// MARK: - Delay editor

private struct DelayEditor: View {
    @Binding var seconds: Double?
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass").font(.system(size: 11)).foregroundStyle(Theme.inkFaint)
            Slider(value: Binding(
                get: { seconds ?? 1 },
                set: { seconds = ($0 * 2).rounded() / 2 }), in: 0...10)
                .frame(width: 160).tint(Theme.amber)
            Text(String(format: "%.1f s", seconds ?? 1))
                .font(Theme.mono(12, .semibold)).foregroundStyle(Theme.amber)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
