import Foundation

/// Thin hooks over `CasmosPreferences` for layout, translate routing,
/// inline playback, send-key, link confirm, passcode, file names, and logging.
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

    public static var doubleTapAction: CasmosDoubleTapAction {
        CasmosPreferences.doubleTapAction
    }

    /// Hide the channel input-bar Mute / Discuss / gift buttons. Header actions stay available.
    public static var hideChannelBottomButtons: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Chat.hideChannelBottomButtons)
    }

    public static var confirmExternalLinks: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.General.confirmLinkOpens, default: true)
    }

    public static var autoLockOnSleep: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.autoLockOnSleep, default: true)
    }

    public static var hideContentInAppSwitcher: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.hideContentInAppSwitcher, default: true)
    }

    public static var keepOriginalFileNames: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.General.keepOriginalFileNames)
    }

    public static var compactChatList: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.compactChatList)
    }

    public static var monochromeFolders: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.monochromeFolders)
    }

    public static var verboseLogging: Bool {
        CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.verboseLogging, default: false)
    }

    /// Chat list avatar side. Compact is 36pt in a 56pt row.
    public static var chatListAvatarSize: Double {
        compactChatList ? 36 : 50
    }

    public static var chatListAvatarInset: Double {
        compactChatList ? 10 : 10
    }

    public static var chatListRowHeight: Double {
        compactChatList ? 56 : 70
    }

    public static var chatListRowMargin: Double {
        compactChatList ? 6 : 9
    }

    /// One-line topic rows match chat-list height (title line is ~17pt).
    public static func topicListRowHeight(titleHeight: Double) -> Double {
        chatListRowHeight - 17 + titleHeight
    }

    public static var topicListIconSize: Double {
        compactChatList ? 24 : 30
    }

    public static var searchTopicRowHeight: Double {
        compactChatList ? 40 : 50
    }

    public static func log(_ tag: String, _ message: String) {
        guard verboseLogging else {
            return
        }
        print("[Casmos][\(tag)] \(message)")
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
