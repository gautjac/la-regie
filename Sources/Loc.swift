import Foundation
import Combine

// MARK: - Loc — the little bilingual engine (shared Atelier pattern)
//
// La Régie speaks French and English. Every user-visible literal goes through
// `t(_ fr:_ en:)`, which returns the right string for the current language.
//
// The current language defaults to the system language (FR fallback — Jac is
// FR-first) and can be overridden in-app via the FR|EN switch. The override
// persists in UserDefaults under `atelier_lang`, the key shared by the whole
// Atelier family so a choice made in one app carries the same intent.

enum Lang: String {
    case fr, en
}

/// Shared key across every Atelier app — set once, the family agrees.
private let kAtelierLang = "atelier_lang"

/// First-run language: an explicit saved override wins; otherwise the system
/// language decides, with French as the fallback for anything non-English.
private func detectLang() -> Lang {
    if let saved = UserDefaults.standard.string(forKey: kAtelierLang),
       let l = Lang(rawValue: saved) {
        return l
    }
    let pref = (Locale.preferredLanguages.first ?? "fr").lowercased()
    return pref.hasPrefix("en") ? .en : .fr
}

/// The app-wide language. An ObservableObject so SwiftUI re-renders the instant
/// the language flips, while a plain global mirror (`Loc.current`) lets non-SwiftUI
/// code (menu items, the HUD, AppKit alerts) read it without plumbing the object.
final class Loc: ObservableObject {
    static let shared = Loc()

    @Published private(set) var lang: Lang

    private init() {
        let l = detectLang()
        self.lang = l
        Loc.current = l
    }

    /// Plain global the free `t(...)` helper reads. Kept in sync with `lang`.
    fileprivate static var current: Lang = .fr

    func set(_ l: Lang) {
        guard l != lang else { return }
        lang = l
        Loc.current = l
        UserDefaults.standard.set(l.rawValue, forKey: kAtelierLang)
        objectWillChange.send()
    }

    func toggle() { set(lang == .fr ? .en : .fr) }
}

/// The workhorse: pick the French or English literal for the current language.
func t(_ fr: String, _ en: String) -> String {
    Loc.current == .fr ? fr : en
}
