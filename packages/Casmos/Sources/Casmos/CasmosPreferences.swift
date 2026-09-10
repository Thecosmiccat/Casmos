import Foundation

/// Casmos preference keys (`casmos.pref.*`) and UserDefaults-backed values.
/// P1 layout / routing / playback hooks live in `CasmosHooks`.
public enum CasmosPrefKey {
    public static let prefix = "casmos.pref."

    public enum General {
        public static let keepOriginalFileNames = "casmos.pref.general.keepOriginalFileNames"
        public static let confirmLinkOpens = "casmos.pref.general.confirmLinkOpens"
    }

    public enum Appearance {
        public static let compactChatList = "casmos.pref.appearance.compactChatList"
        public static let monochromeFolders = "casmos.pref.appearance.monochromeFolders"
    }

    public enum Chat {
        public static let sendWithCommandEnter = "casmos.pref.chat.sendWithCommandEnter"
        /// Sticker size. Applied to the 208pt chat sticker box via `CasmosHooks`.
        public static let stickerSize = "casmos.pref.chat.stickerSize"
    }

    public enum Translator {
        public static let enabled = "casmos.pref.translator.enabled"
        /// Translator engine. `extra` routes through the existing web fallback.
        public static let engine = "casmos.pref.translator.engine"
    }

    public enum Passcode {
        public static let autoLockOnSleep = "casmos.pref.passcode.autoLockOnSleep"
        public static let hideContentInAppSwitcher = "casmos.pref.passcode.hideContentInAppSwitcher"
    }

    public enum Experimental {
        /// Pause inline chat video when Casmos is not the active app.
        public static let pauseVideoOnBackground = "casmos.pref.experimental.pauseVideoOnBackground"
        public static let verboseLogging = "casmos.pref.experimental.verboseLogging"
    }

    public static let allKeys: [String] = [
        General.keepOriginalFileNames,
        General.confirmLinkOpens,
        Appearance.compactChatList,
        Appearance.monochromeFolders,
        Chat.sendWithCommandEnter,
        Chat.stickerSize,
        Translator.enabled,
        Translator.engine,
        Passcode.autoLockOnSleep,
        Passcode.hideContentInAppSwitcher,
        Experimental.pauseVideoOnBackground,
        Experimental.verboseLogging
    ]
}

public enum CasmosStickerSize: String, CaseIterable {
    case small
    case medium
    case large

    public static let `default` = CasmosStickerSize.medium
}

public enum CasmosTranslatorEngine: String, CaseIterable {
    case system
    case extra

    public static let `default` = CasmosTranslatorEngine.system
}

public enum CasmosPreferences {
    private static var defaults: UserDefaults { .standard }

    public static func bool(forKey key: String, default value: Bool = false) -> Bool {
        if defaults.object(forKey: key) == nil {
            return value
        }
        return defaults.bool(forKey: key)
    }

    public static func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public static func string(forKey key: String, default value: String) -> String {
        defaults.string(forKey: key) ?? value
    }

    public static func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public static var stickerSize: CasmosStickerSize {
        get {
            CasmosStickerSize(rawValue: string(forKey: CasmosPrefKey.Chat.stickerSize, default: CasmosStickerSize.default.rawValue)) ?? .default
        }
        set { set(newValue.rawValue, forKey: CasmosPrefKey.Chat.stickerSize) }
    }

    public static var translatorEngine: CasmosTranslatorEngine {
        get {
            CasmosTranslatorEngine(rawValue: string(forKey: CasmosPrefKey.Translator.engine, default: CasmosTranslatorEngine.default.rawValue)) ?? .default
        }
        set { set(newValue.rawValue, forKey: CasmosPrefKey.Translator.engine) }
    }

    public static func toggle(_ key: String, default defaultValue: Bool = false) {
        set(!bool(forKey: key, default: defaultValue), forKey: key)
    }
}
