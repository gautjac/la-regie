import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - EditorView — the régie console
//
// Left: the rack of scenes (cue list). Right: the selected scene's name/emoji/
// colour/hotkey header and its ordered channel-strip of actions. Add/remove/
// reorder actions; each action edits its params inline via friendly pickers.

struct EditorView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var loc: Loc
    @State private var selection: UUID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 240)
            Divider().overlay(Theme.hairline)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg)
        .frame(minWidth: 720, minHeight: 460)
        .onAppear { if selection == nil { selection = store.scenes.first?.id } }
        .preferredColorScheme(.dark)
    }

    // MARK: Sidebar — the cue rack

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Theme.amber)
                Text("LA RÉGIE")
                    .font(Theme.mono(13, .bold))
                    .foregroundStyle(Theme.ink)
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Text(t("DÉCORS", "SCENES"))
                .font(Theme.mono(10, .semibold))
                .foregroundStyle(Theme.inkFaint)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.scenes) { scene in
                        sceneRow(scene)
                    }
                }
                .padding(.horizontal, 10)
            }

            Divider().overlay(Theme.hairline)

            Button(action: { store.addScene(); selection = store.scenes.last?.id }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(t("Nouveau décor", "New scene"))
                }
                .font(Theme.sans(12, .medium))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(Theme.panel)
        }
        .background(Theme.bg)
    }

    private func sceneRow(_ scene: Scene) -> some View {
        let isSel = selection == scene.id
        return Button(action: { selection = scene.id }) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: scene.accentHex))
                    .frame(width: 4, height: 30)
                Text(scene.emoji).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 1) {
                    Text(scene.name)
                        .font(Theme.sans(13, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(t("\(scene.actions.count) action(s)", "\(scene.actions.count) action(s)"))
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                if let hk = scene.hotkey {
                    Text(hk.display)
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(Theme.inkDim)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSel ? Theme.panelHi : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSel ? Color(hex: scene.accentHex).opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Detail — the selected scene

    @ViewBuilder private var detail: some View {
        if let id = selection, let scene = store.scene(withID: id) {
            SceneDetail(scene: scene)
                .id(id)   // rebuild state when selection changes
        } else {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.inkFaint)
                Text(t("Choisis ou crée un décor.", "Pick or create a scene."))
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.inkDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
    }
}

// MARK: - SceneDetail

private struct SceneDetail: View {
    @EnvironmentObject var store: Store
    @State var scene: Scene
    @State private var showAddMenu = false

    private func commit() { store.update(scene) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.hairline)
            actionList
        }
        .background(Theme.bg)
    }

    // Header: emoji + name, colour, hotkey, Activer, Delete.
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                EmojiField(emoji: $scene.emoji, accent: Color(hex: scene.accentHex))
                    .onChange(of: scene.emoji) { _, _ in commit() }

                TextField(t("Nom du décor", "Scene name"), text: $scene.name)
                    .textFieldStyle(.plain)
                    .font(Theme.sans(22, .bold))
                    .foregroundStyle(Theme.ink)
                    .onSubmit { commit() }
                    .onChange(of: scene.name) { _, _ in commit() }

                Spacer()

                Button(action: { store.activate(scene) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text(t("Activer", "Activate"))
                    }
                    .font(Theme.sans(13, .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(Theme.green))
                }
                .buttonStyle(.plain)
                .help(t("Déclencher ce décor maintenant", "Fire this cue now"))
            }

            HStack(spacing: 20) {
                // Accent colour swatches.
                HStack(spacing: 6) {
                    Text(t("COULEUR", "COLOUR"))
                        .font(Theme.mono(9, .semibold)).foregroundStyle(Theme.inkFaint).tracking(1)
                    ForEach(palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.white,
                                lineWidth: scene.accentHex.uppercased() == hex ? 2 : 0))
                            .onTapGesture { scene.accentHex = hex; commit() }
                    }
                }

                Divider().frame(height: 20).overlay(Theme.hairline)

                HStack(spacing: 8) {
                    Text(t("RACCOURCI", "HOTKEY"))
                        .font(Theme.mono(9, .semibold)).foregroundStyle(Theme.inkFaint).tracking(1)
                    HotkeyRecorder(combo: scene.hotkey) { newCombo in
                        scene.hotkey = newCombo; commit()
                    }
                    .frame(width: 132, height: 30)
                    .help(t("Clic pour enregistrer · clic-droit pour effacer",
                            "Click to record · right-click to clear"))
                }

                Spacer()

                Button(role: .destructive, action: {
                    store.deleteScene(scene.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.red)
                }
                .buttonStyle(.plain)
                .help(t("Supprimer ce décor", "Delete this scene"))
            }
        }
        .padding(20)
    }

    private let palette = ["#E8612C", "#3B82F6", "#10B981", "#A855F7", "#F59E0B", "#EC4899"]

    // The channel strip of actions.
    private var actionList: some View {
        VStack(spacing: 0) {
            HStack {
                Text(t("ACTIONS — exécutées de haut en bas", "ACTIONS — run top to bottom"))
                    .font(Theme.mono(10, .semibold)).foregroundStyle(Theme.inkFaint).tracking(1)
                Spacer()
                AddActionMenu { kind in
                    scene.actions.append(SceneAction(kind: kind)); commit()
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            if scene.actions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 30)).foregroundStyle(Theme.inkFaint)
                    Text(t("Aucune action. Ajoute la première étape du cue.",
                           "No actions yet. Add the first step of the cue."))
                        .font(Theme.sans(13)).foregroundStyle(Theme.inkDim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(scene.actions.enumerated()), id: \.element.id) { idx, _ in
                            ActionRow(
                                index: idx,
                                action: bindingForAction(idx),
                                canMoveUp: idx > 0,
                                canMoveDown: idx < scene.actions.count - 1,
                                onMoveUp: { move(idx, by: -1) },
                                onMoveDown: { move(idx, by: 1) },
                                onDelete: { scene.actions.remove(at: idx); commit() }
                            )
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 20)
                }
            }
        }
    }

    private func bindingForAction(_ idx: Int) -> Binding<SceneAction> {
        Binding(
            get: { scene.actions[idx] },
            set: { scene.actions[idx] = $0; commit() }
        )
    }

    private func move(_ idx: Int, by delta: Int) {
        let target = idx + delta
        guard scene.actions.indices.contains(target) else { return }
        scene.actions.swapAt(idx, target)
        commit()
    }
}

// MARK: - EmojiField — a click-to-edit single glyph

private struct EmojiField: View {
    @Binding var emoji: String
    var accent: Color
    @State private var editing = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.5), lineWidth: 1.5))
                .frame(width: 52, height: 52)
            if editing {
                TextField("", text: $emoji)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .onSubmit { trimToOne(); editing = false }
                    .onChange(of: emoji) { _, _ in trimToOne() }
            } else {
                Text(emoji.isEmpty ? "🎬" : emoji)
                    .font(.system(size: 28))
            }
        }
        .onTapGesture { editing = true }
        .help(t("Clic pour changer l'emoji", "Click to change the emoji"))
    }

    private func trimToOne() {
        if let first = emoji.first { emoji = String(first) }
        if emoji.count > 2 { emoji = String(emoji.prefix(2)) }
    }
}

// MARK: - AddActionMenu

private struct AddActionMenu: View {
    var onPick: (ActionKind) -> Void
    var body: some View {
        Menu {
            ForEach(ActionKind.allCases, id: \.self) { kind in
                Button(action: { onPick(kind) }) {
                    Label(kind.label, systemImage: kind.symbol)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                Text(t("Ajouter une action", "Add action"))
            }
            .font(Theme.sans(12, .medium))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Theme.panelHi))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
