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

    /// When translator is on and engine is extra, use the existing web fallback
    /// instead of the official translate API. `system` leaves routing unchanged.
    public static var prefersExtraTranslatorEngine: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Translator.enabled)
            && CasmosPreferences.translatorEngine == .extra
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
