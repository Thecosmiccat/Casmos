//
//  CasmosSettingsController.swift
//  Casmos
//
//  Settings shell for Casmos (General / Appearance / Chat / Passcode / Experimental).
//  Preference keys live in the Casmos package (`casmos.pref.*`).
//  P1 sticker size, pause-video,
//  leftover Settings toggles (file names, compact list, monochrome folders, verbose logging),
//  double-click action, hide channel bottom buttons, message filter, preference JSON export/import,
//  hide stories (default on), hide own phone and @username (default on),
//  per-account passcode / hide account / panic (Touch ID session reveal).
//  Translator lives in Language (Translate Messages).
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Casmos
import MtProtoKit
import ThemeSettings
import ColorPalette

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
    var hide = CasmosHooks.hideContentInAppSwitcher
    if hide, let delegate = appDelegate, delegate.appEncryption != nil {
        hide = delegate.appEncryption.hasPasscode()
    } else {
        hide = false
    }
    target?.sharingType = hide ? .none : .readWrite
}

private final class CasmosSettingsArguments {
    let context: AccountContext
    let toggle: (String) -> Void
    let cycleStickerSize: () -> Void
    let cycleDoubleTap: () -> Void
    let exportPrefs: () -> Void
    let importPrefs: () -> Void
    let setAccountPasscode: () -> Void
    let removeAccountPasscode: () -> Void
    let setPanicPasscode: () -> Void
    let removePanicPasscode: () -> Void
    let unlockHidden: () -> Void
    init(context: AccountContext, toggle: @escaping (String) -> Void, cycleStickerSize: @escaping () -> Void, cycleDoubleTap: @escaping () -> Void, exportPrefs: @escaping () -> Void, importPrefs: @escaping () -> Void, setAccountPasscode: @escaping () -> Void, removeAccountPasscode: @escaping () -> Void, setPanicPasscode: @escaping () -> Void, removePanicPasscode: @escaping () -> Void, unlockHidden: @escaping () -> Void) {
        self.context = context
        self.toggle = toggle
        self.cycleStickerSize = cycleStickerSize
        self.cycleDoubleTap = cycleDoubleTap
        self.exportPrefs = exportPrefs
        self.importPrefs = importPrefs
        self.setAccountPasscode = setAccountPasscode
        self.removeAccountPasscode = removeAccountPasscode
        self.setPanicPasscode = setPanicPasscode
        self.removePanicPasscode = removePanicPasscode
        self.unlockHidden = unlockHidden
    }
}

private struct CasmosSettingsState: Equatable {
    var keepOriginalFileNames: Bool
    var confirmLinkOpens: Bool
    var compactChatList: Bool
    var monochromeFolders: Bool
    var hideStories: Bool
    var hideOwnPhoneAndUsername: Bool
    var sendWithCommandEnter: Bool
    var stickerSize: String
    var doubleTapAction: String
    var hideChannelBottomButtons: Bool
    var messageFilter: String
    var autoLockOnSleep: Bool
    var hideContentInAppSwitcher: Bool
    var hasAccountPasscode: Bool
    var hideThisAccount: Bool
    var allowPanic: Bool
    var hasPanicPasscode: Bool
    var touchIdAvailable: Bool
    var useTouchIdForAccounts: Bool
    var logoutOnPanic: Bool
    var pauseVideoOnBackground: Bool
    var verboseLogging: Bool

    static func load(accountId: Int64? = nil) -> CasmosSettingsState {
        return CasmosSettingsState(
            keepOriginalFileNames: CasmosPreferences.bool(forKey: CasmosPrefKey.General.keepOriginalFileNames),
            confirmLinkOpens: CasmosPreferences.bool(forKey: CasmosPrefKey.General.confirmLinkOpens, default: true),
            compactChatList: CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.compactChatList),
            monochromeFolders: CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.monochromeFolders),
            hideStories: CasmosPreferences.bool(forKey: CasmosPrefKey.Appearance.hideStories),
            hideOwnPhoneAndUsername: CasmosPreferences.bool(forKey: CasmosPrefKey.Privacy.hideOwnPhoneAndUsername),
            sendWithCommandEnter: CasmosPreferences.bool(forKey: CasmosPrefKey.Chat.sendWithCommandEnter),
            stickerSize: CasmosPreferences.stickerSize.rawValue,
            doubleTapAction: CasmosPreferences.doubleTapAction.displayName,
            hideChannelBottomButtons: CasmosPreferences.bool(forKey: CasmosPrefKey.Chat.hideChannelBottomButtons),
            messageFilter: CasmosPreferences.messageFilterRaw,
            autoLockOnSleep: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.autoLockOnSleep, default: true),
            hideContentInAppSwitcher: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.hideContentInAppSwitcher, default: true),
            hasAccountPasscode: accountId.map { CasmosAccountPasscode.hasPasscode(accountId: $0) } ?? false,
            hideThisAccount: accountId.map { CasmosAccountPasscode.isHidden(accountId: $0) } ?? false,
            allowPanic: accountId.map { CasmosAccountPasscode.allowPanic(accountId: $0) } ?? true,
            hasPanicPasscode: CasmosAccountPasscode.hasPanicPasscode(),
            touchIdAvailable: casmosTouchIdAvailable(),
            useTouchIdForAccounts: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.useTouchIdForAccounts),
            logoutOnPanic: CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.logoutOnPanic),
            pauseVideoOnBackground: CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.pauseVideoOnBackground),
            verboseLogging: CasmosPreferences.bool(forKey: CasmosPrefKey.Experimental.verboseLogging, default: false)
        )
    }
}

private let _id_keep_names = InputDataIdentifier("casmos.pref.general.keepOriginalFileNames")
private let _id_confirm_links = InputDataIdentifier("casmos.pref.general.confirmLinkOpens")
private let _id_compact_list = InputDataIdentifier("casmos.pref.appearance.compactChatList")
private let _id_mono_folders = InputDataIdentifier("casmos.pref.appearance.monochromeFolders")
private let _id_hide_stories = InputDataIdentifier("casmos.pref.appearance.hideStories")
private let _id_custom_theme = InputDataIdentifier("casmos.pref.appearance.customTheme")
private let _id_hide_own_ids = InputDataIdentifier("casmos.pref.privacy.hideOwnPhoneAndUsername")
private let _id_cmd_enter = InputDataIdentifier("casmos.pref.chat.sendWithCommandEnter")
private let _id_sticker_size = InputDataIdentifier("casmos.pref.chat.stickerSize")
private let _id_double_tap = InputDataIdentifier("casmos.pref.chat.doubleTapAction")
private let _id_hide_channel_buttons = InputDataIdentifier("casmos.pref.chat.hideChannelBottomButtons")
private let _id_message_filter = InputDataIdentifier("casmos.pref.chat.messageFilter")
private let _id_export = InputDataIdentifier("casmos.pref.config.export")
private let _id_import = InputDataIdentifier("casmos.pref.config.import")
private let _id_autolock = InputDataIdentifier("casmos.pref.passcode.autoLockOnSleep")
private let _id_hide_switcher = InputDataIdentifier("casmos.pref.passcode.hideContentInAppSwitcher")
private let _id_account_passcode = InputDataIdentifier("casmos.pref.passcode.account")
private let _id_remove_account_passcode = InputDataIdentifier("casmos.pref.passcode.account.remove")
private let _id_hide_account = InputDataIdentifier("casmos.pref.passcode.hideAccount")
private let _id_allow_panic = InputDataIdentifier("casmos.pref.passcode.allowPanic")
private let _id_panic_passcode = InputDataIdentifier("casmos.pref.passcode.panic")
private let _id_remove_panic = InputDataIdentifier("casmos.pref.passcode.panic.remove")
private let _id_touchid_accounts = InputDataIdentifier("casmos.pref.passcode.useTouchIdForAccounts")
private let _id_logout_panic = InputDataIdentifier("casmos.pref.passcode.logoutOnPanic")
private let _id_unlock_hidden = InputDataIdentifier("casmos.pref.passcode.unlockHidden")
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
    toggleRow(id: _id_confirm_links, name: "Confirm External Links", value: state.confirmLinkOpens, key: CasmosPrefKey.General.confirmLinkOpens, viewType: .innerItem)
    toggleRow(id: _id_hide_own_ids, name: "Hide Phone and Username", value: state.hideOwnPhoneAndUsername, key: CasmosPrefKey.Privacy.hideOwnPhoneAndUsername, viewType: .lastItem)
    footer("Keep Original File Names uses the document name in Save and Downloads. Confirm External Links prompts before opening http(s) URLs and is on by default. Hide Phone and Username removes your number and @username from your own profile, Settings header, and Edit Account values. Username and Change Number stay tappable without blank values (on by default).")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("APPEARANCE")
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_custom_theme, data: .init(name: "Custom Theme", color: theme.colors.text, type: .next, viewType: .firstItem, action: {
        arguments.context.bindings.rootNavigation().push(CasmosCustomThemeController(context: arguments.context))
    })))
    index += 1
    toggleRow(id: _id_compact_list, name: "Compact Chat List", value: state.compactChatList, key: CasmosPrefKey.Appearance.compactChatList, viewType: .innerItem)
    toggleRow(id: _id_mono_folders, name: "Monochrome Folders", value: state.monochromeFolders, key: CasmosPrefKey.Appearance.monochromeFolders, viewType: .innerItem)
    toggleRow(id: _id_hide_stories, name: "Hide Stories", value: state.hideStories, key: CasmosPrefKey.Appearance.hideStories, viewType: .lastItem)
    footer("Custom Theme opens a full-page studio: tap a screen, then tap a color or a swatch. Compact Chat List uses 56pt rows. Monochrome Folders draws folder tags and folder tab titles in gray. Hide Stories removes the chat-list Stories strip and avatar story rings and is on by default.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("CHAT")
    toggleRow(id: _id_cmd_enter, name: "Send with Command-Return", value: state.sendWithCommandEnter, key: CasmosPrefKey.Chat.sendWithCommandEnter, viewType: .firstItem)
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sticker_size, data: .init(name: "Sticker Size", color: theme.colors.text, type: .nextContext(state.stickerSize), viewType: .innerItem, action: arguments.cycleStickerSize)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_double_tap, data: .init(name: "Double-Click Action", color: theme.colors.text, type: .nextContext(state.doubleTapAction), viewType: .innerItem, action: arguments.cycleDoubleTap)))
    index += 1
    toggleRow(id: _id_hide_channel_buttons, name: "Hide Channel Bottom Buttons", value: state.hideChannelBottomButtons, key: CasmosPrefKey.Chat.hideChannelBottomButtons, viewType: .innerItem)
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.messageFilter), error: nil, identifier: _id_message_filter, mode: .plain, data: .init(viewType: .lastItem), placeholder: nil, inputPlaceholder: "spam, promo, keyword", filter: { $0 }, limit: 500))
    index += 1
    footer("Command-Return sends when enabled. Sticker size scales the 208pt chat sticker box. Double-Click Action runs on a bubble (default Reply). Hide Channel Bottom Buttons collapses the Mute / Discuss bar; mute and discussion stay in the chat header. Message Filter hides incoming text that contains a comma-separated keyword on this Mac only. It does not delete messages.")

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    header("PASSCODE")
    toggleRow(id: _id_autolock, name: "Lock on Sleep", value: state.autoLockOnSleep, key: CasmosPrefKey.Passcode.autoLockOnSleep, viewType: .firstItem)
    toggleRow(id: _id_hide_switcher, name: "Hide Content in App Switcher", value: state.hideContentInAppSwitcher, key: CasmosPrefKey.Passcode.hideContentInAppSwitcher, viewType: .innerItem)
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_account_passcode, data: .init(name: state.hasAccountPasscode ? "Change Account Passcode" : "Set Account Passcode", color: theme.colors.text, type: .next, viewType: .innerItem, action: arguments.setAccountPasscode)))
    index += 1
    if state.hasAccountPasscode {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_remove_account_passcode, data: .init(name: "Remove Account Passcode", color: theme.colors.text, type: .next, viewType: .innerItem, action: arguments.removeAccountPasscode)))
        index += 1
        toggleRow(id: _id_hide_account, name: "Hide This Account", value: state.hideThisAccount, key: "casmos.passcode.hideAccount", viewType: .innerItem)
        toggleRow(id: _id_allow_panic, name: "Include in Panic", value: state.allowPanic, key: "casmos.passcode.allowPanic", viewType: .innerItem)
    }
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_panic_passcode, data: .init(name: state.hasPanicPasscode ? "Change Panic Passcode" : "Set Panic Passcode", color: theme.colors.text, type: .next, viewType: .innerItem, action: arguments.setPanicPasscode)))
    index += 1
    if state.hasPanicPasscode {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_remove_panic, data: .init(name: "Remove Panic Passcode", color: theme.colors.text, type: .next, viewType: .innerItem, action: arguments.removePanicPasscode)))
        index += 1
    }
    if state.touchIdAvailable {
        toggleRow(id: _id_touchid_accounts, name: "Touch ID Reveals Hidden Accounts", value: state.useTouchIdForAccounts, key: CasmosPrefKey.Passcode.useTouchIdForAccounts, viewType: .innerItem)
    } else {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_touchid_accounts, data: .init(name: "Touch ID Reveals Hidden Accounts", color: theme.colors.text, type: .nextContext("NOT WIRED"), viewType: .innerItem, enabled: false)))
        index += 1
    }
    toggleRow(id: _id_logout_panic, name: "Logout on Panic", value: state.logoutOnPanic, key: CasmosPrefKey.Passcode.logoutOnPanic, viewType: .innerItem)
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_unlock_hidden, data: .init(name: "Unlock Hidden Account", color: theme.colors.text, type: .next, viewType: .lastItem, action: arguments.unlockHidden)))
    index += 1
    footer("Lock on Sleep and Hide Content in App Switcher are on by default. Hide Content in App Switcher blanks App Switcher when a passcode is set. Account passcode hashes stay in the Keychain. Hide This Account drops the account from the switcher until you type that passcode. Panic hides included accounts for this session; Hide This Account stays after quit. Logout on Panic also signs those accounts out and is off by default. Touch ID Reveals Hidden Accounts stays off until LocalAuthentication succeeds; without biometrics it shows NOT WIRED. Cold-start lock only accepts the app passcode (NOT WIRED for panic / hide). This is local hide, not network anonymity.")

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
    let accountId = context.account.id.int64
    let reload: () -> CasmosSettingsState = { CasmosSettingsState.load(accountId: accountId) }
    let initialState = reload()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CasmosSettingsState) -> CasmosSettingsState) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    let arguments = CasmosSettingsArguments(context: context, toggle: { key in
        if key == "casmos.passcode.hideAccount" {
            guard CasmosAccountPasscode.hasPasscode(accountId: accountId) else {
                return
            }
            CasmosAccountPasscode.setHidden(!CasmosAccountPasscode.isHidden(accountId: accountId), accountId: accountId)
            updateState { _ in reload() }
            return
        }
        if key == "casmos.passcode.allowPanic" {
            CasmosAccountPasscode.setAllowPanic(!CasmosAccountPasscode.allowPanic(accountId: accountId), accountId: accountId)
            updateState { _ in reload() }
            return
        }
        if key == CasmosPrefKey.Passcode.useTouchIdForAccounts {
            if !casmosTouchIdAvailable() {
                updateState { _ in reload() }
                return
            }
            if CasmosPreferences.bool(forKey: CasmosPrefKey.Passcode.useTouchIdForAccounts) {
                CasmosPreferences.set(false, forKey: CasmosPrefKey.Passcode.useTouchIdForAccounts)
                updateState { _ in reload() }
                return
            }
            casmosEvaluateTouchId(reason: "Allow Touch ID to reveal hidden accounts this session") { ok in
                if ok {
                    CasmosPreferences.set(true, forKey: CasmosPrefKey.Passcode.useTouchIdForAccounts)
                }
                updateState { _ in reload() }
            }
            return
        }
        CasmosPreferences.toggle(key)
        if key == CasmosPrefKey.Experimental.verboseLogging {
            applyCasmosVerboseLogging()
        }
        if key == CasmosPrefKey.Passcode.hideContentInAppSwitcher {
            applyCasmosAppSwitcherPrivacy()
        }
        updateState { _ in reload() }
    }, cycleStickerSize: {
        let current = CasmosPreferences.stickerSize
        let all = CasmosStickerSize.allCases
        let next = all[(all.firstIndex(of: current)! + 1) % all.count]
        CasmosPreferences.stickerSize = next
        updateState { _ in reload() }
    }, cycleDoubleTap: {
        let current = CasmosPreferences.doubleTapAction
        let all = CasmosDoubleTapAction.allCases
        let next = all[(all.firstIndex(of: current)! + 1) % all.count]
        CasmosPreferences.doubleTapAction = next
        updateState { _ in reload() }
    }, exportPrefs: {
        casmosExportPreferences(window: context.window)
    }, importPrefs: {
        casmosImportPreferences(window: context.window) { ok in
            if ok {
                applyCasmosAppSwitcherPrivacy()
                updateState { _ in reload() }
            }
        }
    }, setAccountPasscode: {
        casmosPresentSetAccountPasscode(context: context) {
            updateState { _ in reload() }
        }
    }, removeAccountPasscode: {
        casmosPresentRemoveAccountPasscode(context: context) {
            updateState { _ in reload() }
        }
    }, setPanicPasscode: {
        casmosPresentSetPanicPasscode(context: context) {
            updateState { _ in reload() }
        }
    }, removePanicPasscode: {
        casmosPresentRemovePanicPasscode(context: context) {
            updateState { _ in reload() }
        }
    }, unlockHidden: {
        casmosPresentUnlockHidden(context: context) {
            updateState { _ in reload() }
        }
    })

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        InputDataSignalValue(entries: casmosSettingsEntries(state: state, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: "Casmos Settings", removeAfterDisappear: false, hasDone: false, identifier: "casmos")
    controller.updateDatas = { data in
        if let value = data[_id_message_filter]?.stringValue {
            CasmosPreferences.messageFilterRaw = value
        }
        return .none
    }
    return controller
}

private let casmosThemeApplyDisposable = MetaDisposable()
private var casmosThemePending: ColorPalette?
private var casmosThemePendingWallpaper = false

func casmosCommitCustomTheme(context: AccountContext) {
    casmosThemeApplyDisposable.set(nil)
    guard let palette = casmosThemePending else {
        return
    }
    let wallpaper = casmosThemePendingWallpaper
    casmosThemePending = nil
    casmosThemePendingWallpaper = false
    _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
        var settings = settings.withUpdatedPalette(palette).withUpdatedCloudTheme(nil)
        if wallpaper {
            settings = settings.updateWallpaper { _ in
                ThemeWallpaper(wallpaper: .color(palette.chatBackground.argb), associated: nil)
            }
        }
        let defaultTheme = DefaultTheme(local: palette.parent, cloud: nil)
        if palette.isDark {
            settings = settings.withUpdatedDefaultDark(defaultTheme)
        } else {
            settings = settings.withUpdatedDefaultDay(defaultTheme)
        }
        return settings.saveDefaultAccent(color: PaletteAccentColor(palette.accent, palette.bubbleBackground_outgoing)).withUpdatedDefaultIsDark(palette.isDark).withSavedAssociatedTheme()
    }).start()
}

func casmosQueueCustomTheme(context: AccountContext, palette: ColorPalette, wallpaper: Bool) {
    casmosThemePending = palette
    casmosThemePendingWallpaper = casmosThemePendingWallpaper || wallpaper
    casmosThemeApplyDisposable.set((Signal<Void, NoError>.single(Void()) |> delay(0.12, queue: .mainQueue())).start(next: {
        casmosCommitCustomTheme(context: context)
    }))
}

func CasmosCustomThemeController(context: AccountContext) -> ViewController {
    return CasmosThemeStudioController(context)
}
