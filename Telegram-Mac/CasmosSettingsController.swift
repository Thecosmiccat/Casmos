//
//  CasmosSettingsController.swift
//  Casmos
//
//  Settings shell for Casmos (General / Appearance / Chat / Translator / Passcode / Experimental).
//  Preference keys live in the Casmos package (`casmos.pref.*`).
//  P1 sticker size, extra translator routing, pause-video, and multi-engine translator.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Casmos

private final class CasmosSettingsArguments {
    let context: AccountContext
    let toggle: (String) -> Void
    let cycleStickerSize: () -> Void
    let cycleTranslatorEngine: () -> Void
    init(context: AccountContext, toggle: @escaping (String) -> Void, cycleStickerSize: @escaping () -> Void, cycleTranslatorEngine: @escaping () -> Void) {
        self.context = context
        self.toggle = toggle
        self.cycleStickerSize = cycleStickerSize
        self.cycleTranslatorEngine = cycleTranslatorEngine
    }
}

private struct CasmosSettingsState: Equatable {
    var keepOriginalFileNames: Bool
    var confirmLinkOpens: Bool
    var compactChatList: Bool
    var monochromeFolders: Bool
    var sendWithCommandEnter: Bool
    var stickerSize: String
    var translatorEnabled: Bool
    var translatorEngine: String
    var translatorAuto: Bool
    var autoLockOnSleep: Bool
    var hideContentInAppSwitcher: Bool
    var pauseVideoOnBackground: Bool
    var verboseLogging: Bool

    static func load() -> CasmosSettingsState {
        CasmosSettingsState(
            keepOriginalFileNames: CasmosPreferences.bool(forKey: CasmosPrefKey.General.keepOriginalFileNames),
            confirmLinkOpens: CasmosPreferences.bool(forKey: CasmosPrefKey.General.confirmLinkOpens),
            compactChatList: CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.compactChatList),
            monochromeFolders: CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.monochromeFolders),
            sendWithCommandEnter: CasmosPreferences.bool(forKey: CasmosPrefKey.Chat.sendWithCommandEnter),
            stickerSize: CasmosPreferences.stickerSize.rawValue,
            translatorEnabled: CasmosPreferences.bool(forKey: CasmosPrefKey.Translator.enabled),
            translatorEngine: CasmosPreferences.translatorEngine.rawValue,
            translatorAuto: CasmosPreferences.translatorAuto,
            autoLockOnSleep: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.autoLockOnSleep),
            hideContentInAppSwitcher: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.hideContentInAppSwitcher),
            pauseVideoOnBackground: CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.pauseVideoOnBackground),
            verboseLogging: CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.verboseLogging)
        )
    }
}

private let _id_keep_names = InputDataIdentifier("casmos.pref.general.keepOriginalFileNames")
private let _id_confirm_links = InputDataIdentifier("casmos.pref.general.confirmLinkOpens")
private let _id_compact_list = InputDataIdentifier("casmos.pref.appearance.compactChatList")
private let _id_mono_folders = InputDataIdentifier("casmos.pref.appearance.monochromeFolders")
private let _id_cmd_enter = InputDataIdentifier("casmos.pref.chat.sendWithCommandEnter")
private let _id_sticker_size = InputDataIdentifier("casmos.pref.chat.stickerSize")
private let _id_translator = InputDataIdentifier("casmos.pref.translator.enabled")
private let _id_translator_engine = InputDataIdentifier("casmos.pref.translator.engine")
private let _id_translator_auto = InputDataIdentifier("casmos.pref.translator.auto")
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
    footer("Stored as casmos.pref.general.* Confirm External Links prompts before opening http(s) URLs.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("APPEARANCE")
    toggleRow(id: _id_compact_list, name: "Compact Chat List", value: state.compactChatList, key: CasmosPrefKey.Appearance.compactChatList, viewType: .firstItem)
    toggleRow(id: _id_mono_folders, name: "Monochrome Folders", value: state.monochromeFolders, key: CasmosPrefKey.Appearance.monochromeFolders, viewType: .lastItem)
    footer("Stored as casmos.pref.appearance.*")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("CHAT")
    toggleRow(id: _id_cmd_enter, name: "Send with Command-Return", value: state.sendWithCommandEnter, key: CasmosPrefKey.Chat.sendWithCommandEnter, viewType: .firstItem)
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sticker_size, data: .init(name: "Sticker Size", color: theme.colors.text, type: .nextContext(state.stickerSize), viewType: .lastItem, action: arguments.cycleStickerSize)))
    index += 1
    footer("Command-Return sends when enabled. Sticker size scales the 208pt chat sticker box. Custom emoji size is unchanged.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("TRANSLATOR")
    toggleRow(id: _id_translator, name: "Enable Translator", value: state.translatorEnabled, key: CasmosPrefKey.Translator.enabled, viewType: .firstItem)
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_translator_engine, data: .init(name: "Engine", color: theme.colors.text, type: .nextContext(state.translatorEngine), viewType: .innerItem, action: arguments.cycleTranslatorEngine)))
    index += 1
    toggleRow(id: _id_translator_auto, name: "Auto-translate Chats", value: state.translatorAuto, key: CasmosPrefKey.Translator.auto, viewType: .lastItem)
    footer("System keeps the official path. Extra uses the existing web fallback. Yandex and DeepL are local engines. DeepL reads casmos.pref.translator.deeplKey when set (local only). Auto-translate applies the selected engine to chat messages.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("PASSCODE")
    toggleRow(id: _id_autolock, name: "Lock on Sleep", value: state.autoLockOnSleep, key: CasmosPrefKey.Passcode.autoLockOnSleep, viewType: .firstItem)
    toggleRow(id: _id_hide_switcher, name: "Hide Content in App Switcher", value: state.hideContentInAppSwitcher, key: CasmosPrefKey.Passcode.hideContentInAppSwitcher, viewType: .lastItem)
    footer("Lock on Sleep shows the passcode overlay if a passcode is set. Hide Content in App Switcher blanks window snapshots.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("EXPERIMENTAL")
    toggleRow(id: _id_pause_video, name: "Pause Video in Background", value: state.pauseVideoOnBackground, key: CasmosPrefKey.Experimental.pauseVideoOnBackground, viewType: .firstItem)
    toggleRow(id: _id_verbose, name: "Verbose Logging", value: state.verboseLogging, key: CasmosPrefKey.Experimental.verboseLogging, viewType: .lastItem)
    footer("Pauses inline chat video, GIFs, and round videos when Casmos is inactive.")

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
    })

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        InputDataSignalValue(entries: casmosSettingsEntries(state: state, arguments: arguments))
    }

    return InputDataController(dataSignal: signal, title: "Casmos Settings", hasDone: false)
}
