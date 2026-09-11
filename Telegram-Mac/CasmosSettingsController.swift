//
//  CasmosSettingsController.swift
//  Casmos
//
//  Settings shell for Casmos (General / Appearance / Chat / Translator / Passcode / Experimental).
//  Preference keys live in the Casmos package (`casmos.pref.*`).
//  P1 sticker size, extra translator routing, pause-video, multi-engine translator,
//  leftover Settings toggles (file names, compact list, monochrome folders, verbose logging),
//  double-click action, hide channel bottom buttons, preference JSON export/import,
//  do-not-translate languages, keep-formatting.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Casmos
import MtProtoKit
import Translate

func applyCasmosVerboseLogging() {
    let on = CasmosHooks.verboseLogging
    MTLogSetEnabled(on)
    Logger.shared.logToConsole = on
    Logger.shared.logToFile = on
    UserDefaults.standard.set(on, forKey: "enablelogs")
    if on {
        CasmosHooks.log("logging", "enabled")
    }
}

func applyCasmosAppSwitcherPrivacy(to window: NSWindow? = nil) {
    let target = window ?? appDelegate?.window
    target?.sharingType = CasmosHooks.hideContentInAppSwitcher ? .none : .readWrite
}

private final class CasmosSettingsArguments {
    let context: AccountContext
    let toggle: (String) -> Void
    let cycleStickerSize: () -> Void
    let cycleTranslatorEngine: () -> Void
    let cycleDoubleTap: () -> Void
    let toggleDoNotTranslate: (String) -> Void
    let exportPrefs: () -> Void
    let importPrefs: () -> Void
    init(context: AccountContext, toggle: @escaping (String) -> Void, cycleStickerSize: @escaping () -> Void, cycleTranslatorEngine: @escaping () -> Void, cycleDoubleTap: @escaping () -> Void, toggleDoNotTranslate: @escaping (String) -> Void, exportPrefs: @escaping () -> Void, importPrefs: @escaping () -> Void) {
        self.context = context
        self.toggle = toggle
        self.cycleStickerSize = cycleStickerSize
        self.cycleTranslatorEngine = cycleTranslatorEngine
        self.cycleDoubleTap = cycleDoubleTap
        self.toggleDoNotTranslate = toggleDoNotTranslate
        self.exportPrefs = exportPrefs
        self.importPrefs = importPrefs
    }
}

private struct CasmosSettingsState: Equatable {
    var keepOriginalFileNames: Bool
    var confirmLinkOpens: Bool
    var compactChatList: Bool
    var monochromeFolders: Bool
    var sendWithCommandEnter: Bool
    var stickerSize: String
    var doubleTapAction: String
    var hideChannelBottomButtons: Bool
    var translatorEnabled: Bool
    var translatorEngine: String
    var translatorAuto: Bool
    var keepFormatting: Bool
    var doNotTranslateTitle: String
    var autoLockOnSleep: Bool
    var hideContentInAppSwitcher: Bool
    var pauseVideoOnBackground: Bool
    var verboseLogging: Bool
    var deeplKey: String

    static func load() -> CasmosSettingsState {
        let storedKey = CasmosPreferences.deeplKey
        let deeplKey = storedKey == "CASMOS_PLACEHOLDER_DEEPL_KEY" ? "" : storedKey
        let skip = CasmosPreferences.doNotTranslate
        let skipTitle: String
        if skip.isEmpty {
            skipTitle = "None"
        } else {
            let names = skip.compactMap { code -> String? in
                if let value = Translate.find(code) {
                    return value.language
                }
                return code
            }.sorted()
            skipTitle = names.isEmpty ? "None" : names.joined(separator: ", ")
        }
        return CasmosSettingsState(
            keepOriginalFileNames: CasmosPreferences.bool(forKey: CasmosPrefKey.General.keepOriginalFileNames),
            confirmLinkOpens: CasmosPreferences.bool(forKey: CasmosPrefKey.General.confirmLinkOpens, default: true),
            compactChatList: CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.compactChatList),
            monochromeFolders: CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.monochromeFolders),
            sendWithCommandEnter: CasmosPreferences.bool(forKey: CasmosPrefKey.Chat.sendWithCommandEnter),
            stickerSize: CasmosPreferences.stickerSize.rawValue,
            doubleTapAction: CasmosPreferences.doubleTapAction.displayName,
            hideChannelBottomButtons: CasmosPreferences.bool(forKey: CasmosPrefKey.Chat.hideChannelBottomButtons),
            translatorEnabled: CasmosPreferences.bool(forKey: CasmosPrefKey.Translator.enabled),
            translatorEngine: CasmosPreferences.translatorEngine.rawValue,
            translatorAuto: CasmosPreferences.translatorAuto,
            keepFormatting: CasmosPreferences.keepTranslateFormatting,
            doNotTranslateTitle: skipTitle,
            autoLockOnSleep: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.autoLockOnSleep, default: true),
            hideContentInAppSwitcher: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.hideContentInAppSwitcher, default: true),
            pauseVideoOnBackground: CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.pauseVideoOnBackground),
            verboseLogging: CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.verboseLogging, default: false),
            deeplKey: deeplKey
        )
    }
}

private let _id_keep_names = InputDataIdentifier("casmos.pref.general.keepOriginalFileNames")
private let _id_confirm_links = InputDataIdentifier("casmos.pref.general.confirmLinkOpens")
private let _id_compact_list = InputDataIdentifier("casmos.pref.appearance.compactChatList")
private let _id_mono_folders = InputDataIdentifier("casmos.pref.appearance.monochromeFolders")
private let _id_cmd_enter = InputDataIdentifier("casmos.pref.chat.sendWithCommandEnter")
private let _id_sticker_size = InputDataIdentifier("casmos.pref.chat.stickerSize")
private let _id_double_tap = InputDataIdentifier("casmos.pref.chat.doubleTapAction")
private let _id_hide_channel_buttons = InputDataIdentifier("casmos.pref.chat.hideChannelBottomButtons")
private let _id_export = InputDataIdentifier("casmos.pref.config.export")
private let _id_import = InputDataIdentifier("casmos.pref.config.import")
private let _id_translator = InputDataIdentifier("casmos.pref.translator.enabled")
private let _id_translator_engine = InputDataIdentifier("casmos.pref.translator.engine")
private let _id_translator_auto = InputDataIdentifier("casmos.pref.translator.auto")
private let _id_keep_formatting = InputDataIdentifier("casmos.pref.translator.keepFormatting")
private let _id_do_not_translate = InputDataIdentifier("casmos.pref.translator.doNotTranslate")
private let _id_deepl_key = InputDataIdentifier("casmos.pref.translator.deeplKey")
private let _id_autolock = InputDataIdentifier("casmos.pref.passcode.autoLockOnSleep")
private let _id_hide_switcher = InputDataIdentifier("casmos.pref.passcode.hideContentInAppSwitcher")
private let _id_pause_video = InputDataIdentifier("casmos.pref.experimental.pauseVideoOnBackground")
private let _id_verbose = InputDataIdentifier("casmos.pref.experimental.verboseLogging")

private func casmosSettingsEntries(state: CasmosSettingsState, arguments: CasmosSettingsArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0

    func header(_ text: String) {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(text), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
    }
    func footer(_ text: String) {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(text), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
    }
    func toggleRow(id: InputDataIdentifier, name: String, value: Bool, key: String, viewType: GeneralViewType) {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: id, data: .init(name: name, color: theme.colors.text, type: .switchable(value), viewType: viewType, action: {
            arguments.toggle(key)
        })))
        index += 1
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("GENERAL")
    toggleRow(id: _id_keep_names, name: "Keep Original File Names", value: state.keepOriginalFileNames, key: CasmosPrefKey.General.keepOriginalFileNames, viewType: .firstItem)
    toggleRow(id: _id_confirm_links, name: "Confirm External Links", value: state.confirmLinkOpens, key: CasmosPrefKey.General.confirmLinkOpens, viewType: .lastItem)
    footer("Keep Original File Names uses the document name in Save and Downloads. Confirm External Links prompts before opening http(s) URLs and is on by default.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("APPEARANCE")
    toggleRow(id: _id_compact_list, name: "Compact Chat List", value: state.compactChatList, key: CasmosPrefKey.Appearance.compactChatList, viewType: .firstItem)
    toggleRow(id: _id_mono_folders, name: "Monochrome Folders", value: state.monochromeFolders, key: CasmosPrefKey.Appearance.monochromeFolders, viewType: .lastItem)
    footer("Compact Chat List uses 56pt rows. Monochrome Folders draws folder tags and folder tab titles in gray instead of assigned colors.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("CHAT")
    toggleRow(id: _id_cmd_enter, name: "Send with Command-Return", value: state.sendWithCommandEnter, key: CasmosPrefKey.Chat.sendWithCommandEnter, viewType: .firstItem)
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sticker_size, data: .init(name: "Sticker Size", color: theme.colors.text, type: .nextContext(state.stickerSize), viewType: .innerItem, action: arguments.cycleStickerSize)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_double_tap, data: .init(name: "Double-Click Action", color: theme.colors.text, type: .nextContext(state.doubleTapAction), viewType: .innerItem, action: arguments.cycleDoubleTap)))
    index += 1
    toggleRow(id: _id_hide_channel_buttons, name: "Hide Channel Bottom Buttons", value: state.hideChannelBottomButtons, key: CasmosPrefKey.Chat.hideChannelBottomButtons, viewType: .lastItem)
    footer("Command-Return sends when enabled. Sticker size scales the 208pt chat sticker box. Double-Click Action runs on a bubble (default Reply). Hide Channel Bottom Buttons collapses the Mute / Discuss bar; mute and discussion stay in the chat header.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("TRANSLATOR")
    toggleRow(id: _id_translator, name: "Enable Translator", value: state.translatorEnabled, key: CasmosPrefKey.Translator.enabled, viewType: .firstItem)
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_translator_engine, data: .init(name: "Engine", color: theme.colors.text, type: .nextContext(state.translatorEngine), viewType: .innerItem, action: arguments.cycleTranslatorEngine)))
    index += 1
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.deeplKey), error: nil, identifier: _id_deepl_key, mode: .secure, data: .init(viewType: .innerItem), placeholder: nil, inputPlaceholder: "DeepL key (local)", filter: { $0 }, limit: 255))
    index += 1
    toggleRow(id: _id_keep_formatting, name: "Keep Formatting", value: state.keepFormatting, key: CasmosPrefKey.Translator.keepFormatting, viewType: .innerItem)
    let skipCodes = CasmosPreferences.doNotTranslate
    let codes = Translate.codes.sorted(by: { lhs, rhs in
        let lhsSelected = skipCodes.contains(where: { lhs.code.contains($0) })
        let rhsSelected = skipCodes.contains(where: { rhs.code.contains($0) })
        if lhsSelected && !rhsSelected {
            return true
        } else if !lhsSelected && rhsSelected {
            return false
        } else {
            return lhs.language < rhs.language
        }
    })
    let skipItems: [ContextMenuItem] = codes.map { code in
        let selected = code.code.contains(where: { skipCodes.contains($0) })
        return ContextMenuItem(code.language, handler: {
            if let first = code.code.first {
                arguments.toggleDoNotTranslate(first)
            }
        }, itemImage: selected ? MenuAnimation.menu_check_selected.value : nil)
    }
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_do_not_translate, data: .init(name: "Do Not Translate", color: theme.colors.text, type: .contextSelector(state.doNotTranslateTitle, skipItems), viewType: .innerItem)))
    index += 1
    toggleRow(id: _id_translator_auto, name: "Auto-translate Chats", value: state.translatorAuto, key: CasmosPrefKey.Translator.auto, viewType: .lastItem)
    footer("System keeps the official path. Extra uses the existing web fallback. Yandex and DeepL are local engines. DeepL uses the key above when set (local only); otherwise the public web endpoint. Keep Formatting sends HTML to Yandex, and to DeepL when a local key is set, so bold, italic, links, and code survive. Extra and DeepL-without-key stay plain. Do Not Translate skips those languages in auto-translate and the Translate menu (combined with Language settings). Auto-translate applies the selected engine to chat messages, including polls and todo lists.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("PASSCODE")
    toggleRow(id: _id_autolock, name: "Lock on Sleep", value: state.autoLockOnSleep, key: CasmosPrefKey.Passcode.autoLockOnSleep, viewType: .firstItem)
    toggleRow(id: _id_hide_switcher, name: "Hide Content in App Switcher", value: state.hideContentInAppSwitcher, key: CasmosPrefKey.Passcode.hideContentInAppSwitcher, viewType: .lastItem)
    footer("Lock on Sleep shows the passcode overlay if a passcode is set. Hide Content in App Switcher blanks window snapshots. Both are on by default.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("EXPERIMENTAL")
    toggleRow(id: _id_pause_video, name: "Pause Video in Background", value: state.pauseVideoOnBackground, key: CasmosPrefKey.Experimental.pauseVideoOnBackground, viewType: .firstItem)
    toggleRow(id: _id_verbose, name: "Verbose Logging", value: state.verboseLogging, key: CasmosPrefKey.Experimental.verboseLogging, viewType: .lastItem)
    footer("Pauses inline chat video, GIFs, and round videos when Casmos is inactive. Verbose Logging is off by default; when on it writes Casmos and network logs to the console and log files.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("CONFIG")
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_export, data: .init(name: "Export Preferences", color: theme.colors.text, type: .next, viewType: .firstItem, action: arguments.exportPrefs)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_import, data: .init(name: "Import Preferences", color: theme.colors.text, type: .next, viewType: .lastItem, action: arguments.importPrefs)))
    index += 1
    footer("Writes or reads a JSON file of casmos.pref.* keys. Export may include a local DeepL key if set.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

func CasmosSettingsController(context: AccountContext) -> InputDataController {
    let initialState = CasmosSettingsState.load()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CasmosSettingsState) -> CasmosSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    let arguments = CasmosSettingsArguments(context: context, toggle: { key in
        CasmosPreferences.toggle(key)
        if key == CasmosPrefKey.Experimental.verboseLogging {
            applyCasmosVerboseLogging()
        }
        if key == CasmosPrefKey.Passcode.hideContentInAppSwitcher {
            applyCasmosAppSwitcherPrivacy()
        }
        updateState { _ in CasmosSettingsState.load() }
    }, cycleStickerSize: {
        let current = CasmosPreferences.stickerSize
        let all = CasmosStickerSize.allCases
        let next = all[(all.firstIndex(of: current)! + 1) % all.count]
        CasmosPreferences.stickerSize = next
        updateState { _ in CasmosSettingsState.load() }
    }, cycleTranslatorEngine: {
        let current = CasmosPreferences.translatorEngine
        let all = CasmosTranslatorEngine.allCases
        let next = all[(all.firstIndex(of: current)! + 1) % all.count]
        CasmosPreferences.translatorEngine = next
        updateState { _ in CasmosSettingsState.load() }
    }, cycleDoubleTap: {
        let current = CasmosPreferences.doubleTapAction
        let all = CasmosDoubleTapAction.allCases
        let next = all[(all.firstIndex(of: current)! + 1) % all.count]
        CasmosPreferences.doubleTapAction = next
        updateState { _ in CasmosSettingsState.load() }
    }, toggleDoNotTranslate: { code in
        CasmosPreferences.toggleDoNotTranslate(code)
        updateState { _ in CasmosSettingsState.load() }
    }, exportPrefs: {
        casmosExportPreferences(window: context.window)
    }, importPrefs: {
        casmosImportPreferences(window: context.window) { ok in
            if ok {
                applyCasmosAppSwitcherPrivacy()
                updateState { _ in CasmosSettingsState.load() }
            }
        }
    })

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        InputDataSignalValue(entries: casmosSettingsEntries(state: state, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: "Casmos Settings", hasDone: false)
    controller.updateDatas = { data in
        if let value = data[_id_deepl_key]?.stringValue {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            CasmosPreferences.deeplKey = trimmed == "CASMOS_PLACEHOLDER_DEEPL_KEY" ? "" : trimmed
        }
        return .none
    }
    return controller
}
