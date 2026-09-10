import Foundation

/// Thin hooks over `CasmosPreferences` for layout, translate routing,
/// inline playback, send-key, link confirm, and passcode.
public enum CasmosHooks {
    /// Scale for the 208pt chat sticker box. Custom-emoji 112pt boxes stay unchanged.
    public static var stickerLayoutScale: Double {
        switch CasmosPreferences.stickerSize {
        case .small:
            return 0.75
        case .medium:
            return 1.0
        case .large:
            return 1.25
        }
    }

    public static var pauseVideoWhenAppInactive: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.pauseVideoOnBackground)
    }

    public static var translatorEnabled: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Translator.enabled)
    }

    public static var translatorAutoEnabled: Bool {
        translatorEnabled && CasmosPreferences.translatorAuto
    }

    /// When translator is on and engine is extra, use the existing web fallback
    /// instead of the official translate API. `system` leaves routing unchanged.
    public static var prefersExtraTranslatorEngine: Bool {
        translatorEnabled && CasmosPreferences.translatorEngine == .extra
    }

    /// Translator is on and the selected engine is a local one (extra / yandex / deepl).
    public static var usesLocalTranslatorEngine: Bool {
        translatorEnabled && CasmosPreferences.translatorEngine.isLocal
    }

    public static var sendWithCommandEnter: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Chat.sendWithCommandEnter)
    }

    public static var confirmExternalLinks: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.General.confirmLinkOpens)
    }

    public static var autoLockOnSleep: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.autoLockOnSleep)
    }

    public static var hideContentInAppSwitcher: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.hideContentInAppSwitcher)
    }

    public static func allowsInlinePlayback(windowIsKey: Bool, appIsActive: Bool) -> Bool {
        if !windowIsKey {
            return false
        }
        if pauseVideoWhenAppInactive && !appIsActive {
            return false
        }
        return true
    }
}
