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
        /// Hide the chat-list Stories strip. Default on.
        public static let hideStories = "casmos.pref.appearance.hideStories"
    }

    public enum Privacy {
        /// Hide phone and @username on your own profile UI. Default on.
        public static let hideOwnPhoneAndUsername = "casmos.pref.privacy.hideOwnPhoneAndUsername"
    }

    public enum Chat {
        public static let sendWithCommandEnter = "casmos.pref.chat.sendWithCommandEnter"
        /// Sticker size. Applied to the 208pt chat sticker box via `CasmosHooks`.
        public static let stickerSize = "casmos.pref.chat.stickerSize"
        /// Double-click action on a chat bubble. Default is reply (upstream Mac behavior).
        public static let doubleTapAction = "casmos.pref.chat.doubleTapAction"
        /// Hide Mute / Discuss / gift actions in the channel input bar. Header actions stay available.
        public static let hideChannelBottomButtons = "casmos.pref.chat.hideChannelBottomButtons"
    }

    public enum Translator {
        public static let enabled = "casmos.pref.translator.enabled"
        /// Translator engine. `extra` is the existing web fallback; `yandex` and `deepl` are local engines.
        public static let engine = "casmos.pref.translator.engine"
        /// Auto-translate chat messages with the selected engine.
        public static let auto = "casmos.pref.translator.auto"
        /// Local DeepL auth key. Empty placeholder; never commit a real key.
        public static let deeplKey = "casmos.pref.translator.deeplKey"
        /// Comma-separated language codes skipped by auto-translate and the Translate menu.
        public static let doNotTranslate = "casmos.pref.translator.doNotTranslate"
        /// Send HTML to engines that honor tags and restore bold / italic / links / code after translate.
        public static let keepFormatting = "casmos.pref.translator.keepFormatting"
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
        Appearance.hideStories,
        Privacy.hideOwnPhoneAndUsername,
        Chat.sendWithCommandEnter,
        Chat.stickerSize,
        Chat.doubleTapAction,
        Chat.hideChannelBottomButtons,
        Translator.enabled,
        Translator.engine,
        Translator.auto,
        Translator.deeplKey,
        Translator.doNotTranslate,
        Translator.keepFormatting,
        Passcode.autoLockOnSleep,
        Passcode.hideContentInAppSwitcher,
        Experimental.pauseVideoOnBackground,
        Experimental.verboseLogging
    ]

    /// Keys stored as strings. Everything else in `allKeys` is a bool.
    public static let stringKeys: Set<String> = [
        Chat.stickerSize,
        Chat.doubleTapAction,
        Translator.engine,
        Translator.deeplKey,
        Translator.doNotTranslate
    ]

    /// Unset bool keys use these defaults. Verbose logging stays off.
    public static func boolDefault(for key: String) -> Bool {
        switch key {
        case General.confirmLinkOpens,
             Appearance.hideStories,
             Privacy.hideOwnPhoneAndUsername,
             Passcode.autoLockOnSleep,
             Passcode.hideContentInAppSwitcher,
             Translator.keepFormatting:
            return true
        default:
            return false
        }
    }
}

public enum CasmosStickerSize: String, CaseIterable {
    case small
    case medium
    case large

    public static let `default` = CasmosStickerSize.medium
}

public enum CasmosDoubleTapAction: String, CaseIterable {
    case reply
    case none
    case reaction
    case edit
    case copy
    case forward
    case repeatMessage = "repeat"
    case translate
    case details

    public static let `default` = CasmosDoubleTapAction.reply

    public var displayName: String {
        switch self {
        case .reply:
            return "Reply"
        case .none:
            return "None"
        case .reaction:
            return "Reaction"
        case .edit:
            return "Edit"
        case .copy:
            return "Copy"
        case .forward:
            return "Forward"
        case .repeatMessage:
            return "Repeat"
        case .translate:
            return "Translate"
        case .details:
            return "Details"
        }
    }
}

public enum CasmosTranslatorEngine: String, CaseIterable {
    case system
    case extra
    case yandex
    case deepl

    public static let `default` = CasmosTranslatorEngine.system

    public var isLocal: Bool {
        switch self {
        case .yandex, .deepl, .extra:
            return true
        case .system:
            return false
        }
    }

    /// Yandex HTML format and DeepL official `tag_handling`. Extra web and DeepL-without-key stay plain.
    public var supportsHtmlFormatting: Bool {
        switch self {
        case .yandex:
            return true
        case .deepl:
            return CasmosPreferences.hasLiveDeeplKey
        case .extra, .system:
            return false
        }
    }
}

public enum CasmosPreferences {
    private static var defaults: UserDefaults { .standard }

    /// Posted after any `casmos.pref.*` write so chat list / appearance can rebuild.
    public static let didChangeNotification = Notification.Name("casmos.pref.didChange")

    private static func notifyChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    public static func bool(forKey key: String, default value: Bool? = nil) -> Bool {
        if defaults.object(forKey: key) == nil {
            return value ?? CasmosPrefKey.boolDefault(for: key)
        }
        return defaults.bool(forKey: key)
    }

    public static func set(_ value: Bool, forKey key: String) {
        set(value, forKey: key, notify: true)
    }

    public static func set(_ value: Bool, forKey key: String, notify: Bool) {
        defaults.set(value, forKey: key)
        if notify {
            notifyChange()
        }
    }

    public static func string(forKey key: String, default value: String) -> String {
        defaults.string(forKey: key) ?? value
    }

    public static func set(_ value: String, forKey key: String) {
        set(value, forKey: key, notify: true)
    }

    public static func set(_ value: String, forKey key: String, notify: Bool) {
        defaults.set(value, forKey: key)
        if notify {
            notifyChange()
        }
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

    public static var translatorAuto: Bool {
        get { bool(forKey: CasmosPrefKey.Translator.auto) }
        set { set(newValue, forKey: CasmosPrefKey.Translator.auto) }
    }

    /// Local DeepL key. Default is empty (`CASMOS_PLACEHOLDER_DEEPL_KEY` is treated as unset).
    public static var deeplKey: String {
        get { string(forKey: CasmosPrefKey.Translator.deeplKey, default: "") }
        set { set(newValue, forKey: CasmosPrefKey.Translator.deeplKey) }
    }

    /// A stored DeepL key that is not the empty placeholder.
    public static var hasLiveDeeplKey: Bool {
        let key = deeplKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && key != "CASMOS_PLACEHOLDER_DEEPL_KEY"
    }

    /// Language codes skipped by Casmos auto-translate and the Translate menu.
    public static var doNotTranslate: Set<String> {
        get {
            let raw = string(forKey: CasmosPrefKey.Translator.doNotTranslate, default: "")
            return Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
        }
        set {
            let joined = newValue.map { $0.lowercased() }.filter { !$0.isEmpty }.sorted().joined(separator: ",")
            set(joined, forKey: CasmosPrefKey.Translator.doNotTranslate)
        }
    }

    public static func toggleDoNotTranslate(_ code: String) {
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else {
            return
        }
        var current = doNotTranslate
        if current.contains(value) {
            current.remove(value)
        } else {
            current.insert(value)
        }
        doNotTranslate = current
    }

    /// Keep message formatting (bold / italic / links / code) when using engines that honor HTML. Default on.
    public static var keepTranslateFormatting: Bool {
        get { bool(forKey: CasmosPrefKey.Translator.keepFormatting, default: true) }
        set { set(newValue, forKey: CasmosPrefKey.Translator.keepFormatting) }
    }

    public static func toggle(_ key: String, default defaultValue: Bool? = nil) {
        set(!bool(forKey: key, default: defaultValue), forKey: key)
    }

    public static var doubleTapAction: CasmosDoubleTapAction {
        get {
            CasmosDoubleTapAction(rawValue: string(forKey: CasmosPrefKey.Chat.doubleTapAction, default: CasmosDoubleTapAction.default.rawValue)) ?? .default
        }
        set { set(newValue.rawValue, forKey: CasmosPrefKey.Chat.doubleTapAction) }
    }

    /// JSON export of known `casmos.pref.*` keys. May include a local DeepL key when set.
    public static func exportJSON() -> Data? {
        var prefs: [String: Any] = [:]
        for key in CasmosPrefKey.allKeys {
            if CasmosPrefKey.stringKeys.contains(key) {
                prefs[key] = string(forKey: key, default: "")
            } else {
                prefs[key] = bool(forKey: key)
            }
        }
        let payload: [String: Any] = [
            "app": "casmos",
            "version": 1,
            "prefs": prefs
        ]
        return try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    /// Import a Casmos preferences JSON object. Unknown keys and non-`casmos.pref.*` keys are ignored.
    @discardableResult
    public static func importJSON(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = object as? [String: Any] else {
            return false
        }
        let prefs: [String: Any]
        if let nested = root["prefs"] as? [String: Any] {
            prefs = nested
        } else if root.keys.contains(where: { $0.hasPrefix(CasmosPrefKey.prefix) }) {
            prefs = root
        } else {
            return false
        }
        var applied = false
        let known = Set(CasmosPrefKey.allKeys)
        for (key, value) in prefs {
            guard key.hasPrefix(CasmosPrefKey.prefix), known.contains(key) else {
                continue
            }
            if CasmosPrefKey.stringKeys.contains(key) {
                if let string = value as? String {
                    set(string, forKey: key, notify: false)
                    applied = true
                }
            } else if let flag = value as? Bool {
                set(flag, forKey: key, notify: false)
                applied = true
            } else if let number = value as? NSNumber {
                set(number.boolValue, forKey: key, notify: false)
                applied = true
            }
        }
        if applied {
            notifyChange()
        }
        return applied
    }
}
