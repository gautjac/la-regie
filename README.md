# La Régie

**La salle de contrôle de ton Mac.** Define named **décors** (scenes / cues) —
ordered lists of actions that reshape your whole Mac for a named activity — and
fire them with one menu click or a per-scene global hotkey.

> *La régie* is the broadcast control room. Each scene is a **cue** you fire.

A hand-assembled, non-sandboxed macOS menu-bar app (no Xcode project). Part of
the Atelier family.

## What a scene can do

Each scene is an ordered list of **actions**, run top to bottom:

| Action | What it does | Permission |
|---|---|---|
| **Lancer une app** | Open an app (`NSWorkspace.openApplication`) | none |
| **Quitter une app** | Terminate an app by bundle id (`NSRunningApplication.terminate`) | none |
| **Masquer une app** | Hide an app | none |
| **Masquer les autres apps** | Hide everything except a keep-list | none |
| **Ouvrir fichier / URL** | Open a file, folder, or URL | none* |
| **Changer la sortie audio** | Switch the default system output device (CoreAudio HAL) | none |
| **Régler le volume** | Set the system output volume 0–100 | none |
| **Changer le fond d'écran** | Set the desktop picture on every screen | none |
| **Lancer un raccourci** | Run a macOS Shortcut by name — the honest Focus / DND bridge | Automation prompt (one-time) |
| **Pause** | Wait N seconds between steps | none |

\* Opening files in protected folders (Desktop/Documents) may show a one-time
TCC prompt the first time.

### The Focus / Do-Not-Disturb bridge

macOS has **no public API** to set a Focus directly. The supported, working path
is a macOS **Shortcut**: make a Shortcut with a "Set Focus" action (e.g. "Mettre
le Focus Montage"), and La Régie runs it via `/usr/bin/shortcuts run "<name>"`.
The editor lists your Shortcuts in a picker. The first time a scene runs a
Shortcut, macOS asks to allow La Régie to control Shortcuts — approve once.

### The window-layout bridge (L'Équerre)

La Régie *launches* apps but deliberately never *positions* their windows — that
needs the Accessibility API, and its sibling **[L'Équerre](../l-equerre)** (a
menu-bar window manager) already owns it. Rather than duplicate that engine, a
décor hands off:

1. In L'Équerre, arrange your windows and **capture** the arrangement as a named
   *disposition* (e.g. "Montage").
2. In your La Régie décor, after the `Lancer une app` steps, add a short
   **Pause** (≈1.5 s) then an **Ouvrir fichier / URL** action with:

   ```
   x-equerre://apply?name=Montage
   ```

One cue now opens the apps **and** snaps every window into place. L'Équerre
retries placement as windows appear, so the Pause only needs to be a beat.

The seeded **🎬 Montage** example décor is already wired this way — open it in
the editor to see the pattern (create a "Montage" disposition in L'Équerre first,
or change the `name=` to one you already have). Requires L'Équerre to be
installed and granted Accessibility.

## Build

```sh
./build.sh            # build + selftest, leaves the .app in build/
./build.sh install    # build, replace the /Applications copy, and launch
./build.sh selftest   # headless logic checks only
```

- `swiftc`-compiled, ad-hoc signed, `LSUIElement` (no Dock icon).
- The **executable** is named `LaRegie` (ASCII): `codesign` bus-errors on a
  non-ASCII Mach-O filename, so the accented name lives only on the bundle.
- Compiled in `/tmp` (out of iCloud) so signing stays clean.

## Persistence

Scenes live as JSON at:

```
~/Library/Application Support/La Régie/scenes.json
```

On first run, three example scenes are seeded — **Montage** (🎬, ⌃⌥⌘1),
**Écriture** (✍️, ⌃⌥⌘2), **Pause** (☕️, ⌃⌥⌘3) — so it's useful immediately.

## Global hotkeys

Each scene can claim a system-wide hotkey via Carbon `RegisterEventHotKey`
(the same mechanism Rectangle uses). Click the HOTKEY recorder in the editor and
press a combo (needs ⌘/⌥/⌃); right-click to clear.

## Bilingual

French-first with an English toggle, shared across the Atelier via the
`atelier_lang` UserDefaults key.

---

Made in the Atelier.
