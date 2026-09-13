//
//  LanguageController.swift
//  Telegram
//
//  Created by Mike Renoir on 18.01.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Localization
import TelegramCore
import Postbox
import InAppSettings
import Translate
import Casmos

private final class Arguments {
    let context: AccountContext
    let searchInteractions: SearchInteractions
    let change:(LocalizationInfo)->Void
    let delete:(LocalizationInfo)->Void
    let toggleTranslateChannels:()->Void
    let premiumAlert:()->Void
    let doNotTranslate:(String)->Void
    let toggleCasmos:(String)->Void
    let cycleTranslatorEngine:()->Void
    
    init(context: AccountContext, searchInteractions: SearchInteractions, change:@escaping(LocalizationInfo)->Void, delete:@escaping(LocalizationInfo)->Void, toggleTranslateChannels: @escaping()->Void, premiumAlert:@escaping()->Void, doNotTranslate:@escaping(String)->Void, toggleCasmos:@escaping(String)->Void, cycleTranslatorEngine:@escaping()->Void) {
        self.context = context
        self.change = change
        self.delete = delete
        self.premiumAlert = premiumAlert
        self.toggleTranslateChannels = toggleTranslateChannels
        self.doNotTranslate = doNotTranslate
        self.toggleCasmos = toggleCasmos
        self.cycleTranslatorEngine = cycleTranslatorEngine
        self.searchInteractions = searchInteractions
    }
}


private struct State : Equatable {
    var localication: LocalizationListState = .defaultSettings
    var settings: BaseApplicationSettings = .defaultSettings
    var searchState: SearchState = .init(state: .None, request: nil)
    var tableSearchState: TableSearchViewState = .none({ _ in })
    var language: TelegramLocalization
    var isPremium: Bool
    var loading: LocalizationInfo?
    var casmos: CasmosTranslateSettings
}

private struct CasmosTranslateSettings: Equatable {
    var enabled: Bool
    var engine: String
    var auto: Bool
    var usernames: Bool
    var keepFormatting: Bool
    var deeplKey: String
    var doNotTranslate: Set<String>

    static func load() -> CasmosTranslateSettings {
        let storedKey = CasmosPreferences.deeplKey
        let deeplKey = storedKey == "CASMOS_PLACEHOLDER_DEEPL_KEY" ? "" : storedKey
        return CasmosTranslateSettings(
            enabled: CasmosPreferences.bool(forKey: CasmosPrefKey.Translator.enabled),
            engine: CasmosPreferences.translatorEngine.settingsLabel,
            auto: CasmosPreferences.translatorAuto,
            usernames: CasmosPreferences.bool(forKey: CasmosPrefKey.Translator.translateUsernames),
            keepFormatting: CasmosPreferences.keepTranslateFormatting,
            deeplKey: deeplKey,
            doNotTranslate: CasmosPreferences.doNotTranslate
        )
    }
}

private func _id_language(_ id: String) -> InputDataIdentifier {
    return .init("_id_language_\(id)")
}
private func _id_language_official(_ id: String) -> InputDataIdentifier {
    return .init("_id_language_official_\(id)")
}
private let _id_translate_channels = InputDataIdentifier("_id_translate_channels")
private let _id_do_not_translate = InputDataIdentifier("_id_do_not_translate")
private let _id_casmos_translator = InputDataIdentifier("casmos.pref.translator.enabled")
private let _id_casmos_engine = InputDataIdentifier("casmos.pref.translator.engine")
private let _id_casmos_deepl = InputDataIdentifier("casmos.pref.translator.deeplKey")
private let _id_casmos_formatting = InputDataIdentifier("casmos.pref.translator.keepFormatting")
private let _id_casmos_auto = InputDataIdentifier("casmos.pref.translator.auto")
private let _id_casmos_usernames = InputDataIdentifier("casmos.pref.translator.translateUsernames")

private let _id_search = InputDataIdentifier("_id_search")
private let _id_search_empty = InputDataIdentifier("_id_search_empty")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().languageTranslateMessagesHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    var ignoreCodes = state.settings.doNotTranslate.union(state.casmos.doNotTranslate).compactMap {
        Translate.find($0)
    }.sorted(by: { $0.language < $1.language })
    
    if ignoreCodes.isEmpty, let code = Translate.find(state.language.baseLanguageCode) {
        ignoreCodes.append(code)
    }

    var codes = Translate.codes.sorted(by: { lhs, rhs in
        let lhsSelected = ignoreCodes.contains(where: { $0.code == lhs.code })
        let rhsSelected = ignoreCodes.contains(where: { $0.code == rhs.code })
        if lhsSelected && !rhsSelected {
            return true
        } else if !lhsSelected && rhsSelected {
            return false
        } else {
            return lhs.language < rhs.language
        }
    })
    
    let codeIndex = codes.firstIndex(where: {
        $0.code.contains(state.language.baseLanguageCode)
    })
    if let codeIndex = codeIndex {
        codes.move(at: codeIndex, to: 0)
    }
    
    let title = ignoreCodes.isEmpty ? "" : ignoreCodes.map {
        return _NSLocalizedString("Translate.Language.\($0.language)")
    }.joined(separator: ", ")

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_casmos_translator, data: .init(name: "Enable Translator", color: theme.colors.text, type: .switchable(state.casmos.enabled), viewType: .firstItem, action: {
        arguments.toggleCasmos(CasmosPrefKey.Translator.enabled)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_casmos_engine, data: .init(name: "Engine", color: theme.colors.text, type: .nextContext(state.casmos.engine), viewType: .innerItem, action: arguments.cycleTranslatorEngine)))
    index += 1
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.casmos.deeplKey), error: nil, identifier: _id_casmos_deepl, mode: .secure, data: .init(viewType: .innerItem), placeholder: nil, inputPlaceholder: "DeepL key (local)", filter: { $0 }, limit: 255))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_casmos_formatting, data: .init(name: "Keep Formatting", color: theme.colors.text, type: .switchable(state.casmos.keepFormatting), viewType: .innerItem, action: {
        arguments.toggleCasmos(CasmosPrefKey.Translator.keepFormatting)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_do_not_translate, data: .init(name: strings().languageTranslateMessagesDoNotTranslate, color: theme.colors.text, type: .contextSelector(title, codes.map { code in
        ContextMenuItem(code.language, handler: {
            if let first = code.code.first {
                arguments.doNotTranslate(first)
            }
        }, itemImage: ignoreCodes.contains(where: { $0.language == code.language}) ? MenuAnimation.menu_check_selected.value : nil)
    }), viewType: .innerItem)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_translate_channels, data: .init(name: strings().languageTranslateMessagesChannel, color: theme.colors.text, type: .switchable(state.settings.translateChats), viewType: .innerItem, enabled: state.isPremium || CasmosHooks.translatorEnabled, action: arguments.toggleTranslateChannels, disabledAction: arguments.premiumAlert)))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_casmos_auto, data: .init(name: "Translate Automatically", color: theme.colors.text, type: .switchable(state.casmos.auto), viewType: .innerItem, action: {
        arguments.toggleCasmos(CasmosPrefKey.Translator.auto)
    })))
    index += 1
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_casmos_usernames, data: .init(name: "Translate Usernames", color: theme.colors.text, type: .switchable(state.casmos.usernames), viewType: .lastItem, action: {
        arguments.toggleCasmos(CasmosPrefKey.Translator.translateUsernames)
    })))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("System — official path. Extra — web fallback. Yandex — best free local engine and keeps HTML. DeepL — quality when a local key is set. Keep Formatting sends HTML to Yandex, and to DeepL when a local key is set. Translate Usernames is off by default and only applies to chat titles and one-line list names."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let listState = state.localication
    if !listState.availableSavedLocalizations.isEmpty || !listState.availableOfficialLocalizations.isEmpty {
        
        
        let availableSavedLocalizations = listState.availableSavedLocalizations.filter({ info in !listState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) })
        
        let availableOfficialLocalizations = listState.availableOfficialLocalizations.filter { value in
            if state.searchState.request.isEmpty {
                return true
            } else {
                return (value.title.lowercased().range(of: state.searchState.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.searchState.request.lowercased()) != nil)
            }
        }
        
        var existingIds:Set<String> = Set()
        
        
        let saved = availableSavedLocalizations.filter { value in
            
            if existingIds.contains(value.languageCode) {
                return false
            }

            return true
        }
        
        struct Tuple : Equatable {
            var value: LocalizationInfo
            var viewType: GeneralViewType
            var selected: Bool
            var loading: Bool
        }
        var items: [Tuple] = []
        for (i, value) in saved.enumerated() {
            let viewType: GeneralViewType = bestGeneralViewType(saved, for: i)
            existingIds.insert(value.languageCode)
            items.append(.init(value: value, viewType: viewType, selected: value.languageCode == state.language.primaryLanguage.languageCode, loading: value.languageCode == state.loading?.languageCode))
        }
        
              
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_language(item.value.languageCode), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: item.value.title, description: item.value.localizedTitle, descTextColor: theme.colors.grayText, type: item.loading ? .loading : .selectable(item.selected), viewType: item.viewType, action: {
                    arguments.change(item.value)
                }, menuItems: {
                    return [ContextMenuItem(strings().messageContextDelete, handler: {
                        arguments.delete(item.value)
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)]
                })
            }))
            index += 1
        }
        
        
        
        if !availableOfficialLocalizations.isEmpty {
            
            if !availableSavedLocalizations.isEmpty {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
            }
            
            
            let list = listState.availableOfficialLocalizations.filter { value in
                if existingIds.contains(value.languageCode) {
                    return false
                }
                var accept: Bool = true
                if !state.searchState.request.isEmpty {
                    accept = (value.title.lowercased().range(of: state.searchState.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.searchState.request.lowercased()) != nil)
                }
                return accept
            }
            
            var items: [Tuple] = []
            for (i, value) in list.enumerated() {
                let viewType: GeneralViewType = bestGeneralViewTypeAfterFirst(list, for: i)
                existingIds.insert(value.languageCode)
                items.append(.init(value: value, viewType: viewType, selected: value.languageCode == state.language.primaryLanguage.languageCode, loading: value.languageCode == state.loading?.languageCode))
            }
            
            //search
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_search, equatable: .init(state.searchState), comparable: nil, item: { initialSize, stableId in
                return SearchRowItem(initialSize, stableId: stableId, searchInteractions: arguments.searchInteractions, viewType: .firstItem)
            }))
            
            for item in items {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_language_official(item.value.languageCode), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: item.value.title, description: item.value.localizedTitle, descTextColor: theme.colors.grayText, type:   item.loading ? .loading : .selectable(item.selected), viewType: item.viewType, action: {
                        arguments.change(item.value)
                    })
                }))
                index += 1
            }
        } else if !state.searchState.request.isEmpty {
            
            if !availableSavedLocalizations.isEmpty {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
            }
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_search, equatable: .init(state.searchState), comparable: nil, item: { initialSize, stableId in
                return SearchRowItem(initialSize, stableId: stableId, searchInteractions: arguments.searchInteractions, viewType: .singleItem)
            }))
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_search_empty, equatable: .init(state.searchState), comparable: nil, item: { initialSize, stableId in
                return SearchEmptyRowItem(initialSize, stableId: stableId, viewType: .lastItem)
            }))
            
        }
    } else {
        entries.append(.loading)
        index += 1
    }

    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func LanguageController(_ context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(language: appCurrentLanguage, isPremium: context.isPremium, casmos: .load())
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    

    let applyDisposable = MetaDisposable()
    actionsDisposable.add(applyDisposable)

    let searchInteractions: SearchInteractions = .init({ state, animated in
        updateState { current in
            var current = current
            current.searchState = state
            return current
        }
    }, { state in
        updateState { current in
            var current = current
            current.searchState = state
            return current
        }
    })
    
    let arguments = Arguments(context: context, searchInteractions: searchInteractions, change: { value in
        if value.languageCode != appCurrentLanguage.primaryLanguage.languageCode {
            
            updateState { current in
                var current = current
                current.loading = value
                return current
            }
            
            applyDisposable.set(context.engine.localization.downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, languageCode: value.languageCode).start(error: { error in
                updateState { current in
                    var current = current
                    current.loading = nil
                    return current
                }
            }, completed: {
                updateState { current in
                    var current = current
                    current.loading = nil
                    return current
                }
            }))
        }
    }, delete: { info in
        verifyAlert_button(for: context.window, information: strings().languageRemovePack, successHandler: { _ in
            _ = context.engine.localization.removeSavedLocalization(languageCode: info.languageCode).start()
        })
    }, toggleTranslateChannels: {
        actionsDisposable.add(updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            return settings.withUpdatedTranslateChannels(!settings.translateChats)
        }).start())
    }, premiumAlert: {
        if CasmosHooks.translatorEnabled {
            return
        }
        showModalText(for: context.window, text: strings().languageTranslateMessagesChannelPremium, callback: { _ in
            prem(with: PremiumBoardingController(context: context, source: .translations, openFeatures: true), for: context.window)
        })
    }, doNotTranslate: { code in
        let lowered = code.lowercased()
        let selected = stateValue.with { current in
            current.settings.doNotTranslate.contains(code) || current.casmos.doNotTranslate.contains(lowered)
        }
        var casmos = CasmosPreferences.doNotTranslate
        if selected {
            casmos.remove(lowered)
        } else {
            casmos.insert(lowered)
        }
        CasmosPreferences.doNotTranslate = casmos
        actionsDisposable.add(updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var current = settings.doNotTranslate
            if selected {
                current.remove(code)
            } else {
                current.insert(code)
            }
            return settings.withUpdatedDoNotTranslate(current)
        }).start())
        updateState { current in
            var current = current
            current.casmos = .load()
            return current
        }
    }, toggleCasmos: { key in
        CasmosPreferences.toggle(key)
        updateState { current in
            var current = current
            current.casmos = .load()
            return current
        }
    }, cycleTranslatorEngine: {
        let current = CasmosPreferences.translatorEngine
        let all = CasmosTranslatorEngine.allCases
        let next = all[(all.firstIndex(of: current)! + 1) % all.count]
        CasmosPreferences.translatorEngine = next
        updateState { current in
            var current = current
            current.casmos = .load()
            return current
        }
    })
    
    
    let prefs = context.account.postbox.preferencesView(keys: [PreferencesKeys.localizationListState]) |> map { value -> LocalizationListState in
        return value.values[PreferencesKeys.localizationListState]?.get(LocalizationListState.self) ?? .defaultSettings
    } |> deliverOnPrepareQueue
    
    actionsDisposable.add(combineLatest(prefs, baseAppSettings(accountManager: context.sharedContext.accountManager), appearanceSignal, context.account.postbox.loadedPeerWithId(context.peerId)).start(next: { localization, appSettings, appearance, peer in
        updateState { current in
            var current = current
            current.localication = localization
            current.settings = appSettings
            current.language = appearance.language
            current.isPremium = peer.isPremium
            return current
        }
    }))
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().telegramLanguageViewController, hasDone: false, identifier: "language")
    
    controller.updateDatas = { data in
        if let value = data[_id_casmos_deepl]?.stringValue {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            CasmosPreferences.deeplKey = trimmed == "CASMOS_PLACEHOLDER_DEEPL_KEY" ? "" : trimmed
        }
        return .none
    }
    
    controller._becomeFirstResponder = {
        return false
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
