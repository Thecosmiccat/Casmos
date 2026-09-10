import Foundation

/// Thin P1 hooks over `CasmosPreferences`. Layout, translate routing, and
/// inline playback call these; they do not add a separate translate engine.
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
