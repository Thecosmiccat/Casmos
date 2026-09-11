//
//  CasmosAccountPasscodeUI.swift
//  Casmos
//
//  Per-account passcode, hide-account, panic, and Touch ID session unlock.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import LocalAuthentication
import Casmos

func casmosVisibleAccounts(_ accounts: [AccountWithInfo], currentId: AccountRecordId?) -> [AccountWithInfo] {
    accounts.filter { !CasmosAccountPasscode.shouldHideFromSwitcher(accountId: $0.account.id.int64, currentId: currentId?.int64) }
}

func casmosTouchIdAvailable() -> Bool {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return false
    }
    if #available(macOS 10.13.2, *) {
        switch context.biometryType {
        case .touchID, .faceID:
            return true
        case .opticID:
            return true
        default:
            return false
        }
    }
    return true
}

func casmosEvaluateTouchId(reason: String, completion: @escaping (Bool) -> Void) {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        completion(false)
        return
    }
    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
        Queue.mainQueue().async {
            completion(success)
        }
    }
}

/// Call only after LocalAuthentication succeeded.
func casmosRevealHiddenAccountsAfterTouchId() {
    guard CasmosHooks.useTouchIdForAccounts, casmosTouchIdAvailable() else {
        return
    }
    CasmosAccountPasscode.revealHiddenSessions()
}

private let _id_pass = InputDataIdentifier("casmos.passcode.input")
private let _id_confirm = InputDataIdentifier("casmos.passcode.confirm")

private enum CasmosPasscodePromptMode {
    case setAccount(Int64)
    case removeAccount(Int64)
    case setPanic
    case removePanic
    case unlockHidden
}

private func casmosPasscodePrompt(context: AccountContext, mode: CasmosPasscodePromptMode, title: String, completed: @escaping () -> Void) -> InputDataModalController {
    let initial: [InputDataIdentifier: InputDataValue] = [:]
    let statePromise = ValuePromise(initial, ignoreRepeated: true)
    let stateValue = Atomic(value: initial)
    let updateState: (([InputDataIdentifier: InputDataValue]) -> [InputDataIdentifier: InputDataValue]) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    let confirmNeeded: Bool = {
        switch mode {
        case .setAccount, .setPanic:
            return true
        default:
            return false
        }
    }()

    let placeholder: String = {
        switch mode {
        case .removeAccount, .removePanic:
            return "Current passcode"
        case .unlockHidden:
            return "Account or panic passcode"
        default:
            return "New passcode"
        }
    }()

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { data -> InputDataSignalValue in
        var entries: [InputDataEntry] = []
        var sectionId: Int32 = 0
        var index: Int32 = 0
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.input(sectionId: sectionId, index: index, value: data[_id_pass] ?? .string(""), error: nil, identifier: _id_pass, mode: .secure, data: .init(viewType: confirmNeeded ? .firstItem : .singleItem), placeholder: nil, inputPlaceholder: placeholder, filter: { $0 }, limit: 255))
        index += 1
        if confirmNeeded {
            entries.append(.input(sectionId: sectionId, index: index, value: data[_id_confirm] ?? .string(""), error: nil, identifier: _id_confirm, mode: .secure, data: .init(viewType: .lastItem), placeholder: nil, inputPlaceholder: "Re-enter passcode", filter: { $0 }, limit: 255))
            index += 1
        }
        entries.append(.sectionId(sectionId, type: .normal))
        return InputDataSignalValue(entries: entries)
    }

    let controller = InputDataController(dataSignal: signal, title: title)
    var close: (() -> Void)?
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            if let value = data[_id_pass] {
                current[_id_pass] = value
            }
            if let value = data[_id_confirm] {
                current[_id_confirm] = value
            }
            return current
        }
        return .none
    }
    controller.validateData = { data in
        let pass = data[_id_pass]?.stringValue ?? ""
        let confirm = data[_id_confirm]?.stringValue ?? ""
        if pass.isEmpty {
            return .fail(.fields([_id_pass: .shake]))
        }
        switch mode {
        case let .setAccount(accountId):
            if pass != confirm {
                return .fail(.fields([_id_pass: .shake, _id_confirm: .shake]))
            }
            guard CasmosAccountPasscode.setPasscode(pass, accountId: accountId) else {
                return .fail(.fields([_id_pass: .shake, _id_confirm: .shake]))
            }
        case let .removeAccount(accountId):
            guard CasmosAccountPasscode.verify(pass, accountId: accountId) else {
                return .fail(.fields([_id_pass: .shake]))
            }
            CasmosAccountPasscode.removePasscode(accountId: accountId)
        case .setPanic:
            if pass != confirm {
                return .fail(.fields([_id_pass: .shake, _id_confirm: .shake]))
            }
            guard CasmosAccountPasscode.setPanicPasscode(pass) else {
                return .fail(.fields([_id_pass: .shake, _id_confirm: .shake]))
            }
        case .removePanic:
            guard CasmosAccountPasscode.verifyPanic(pass) else {
                return .fail(.fields([_id_pass: .shake]))
            }
            CasmosAccountPasscode.removePanicPasscode()
        case .unlockHidden:
            switch CasmosAccountPasscode.match(pass) {
            case .none:
                return .fail(.fields([_id_pass: .shake]))
            case .panic:
                casmosHandlePanic(context: context)
            case let .account(accountId):
                CasmosAccountPasscode.unlockSession(accountId: accountId)
                context.sharedContext.switchToAccount(id: AccountRecordId(rawValue: accountId), action: nil)
            }
        }
        completed()
        close?()
        return .none
    }
    let modal = InputDataModalController(controller, modalInteractions: ModalInteractions(acceptTitle: "Done", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true))
    close = { [weak modal] in
        modal?.close()
    }
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modal] in
        modal?.close()
    })
    return modal
}

func casmosPresentSetAccountPasscode(context: AccountContext, completed: @escaping () -> Void) {
    let accountId = context.account.id.int64
    let title = CasmosAccountPasscode.hasPasscode(accountId: accountId) ? "Change Account Passcode" : "Set Account Passcode"
    showModal(with: casmosPasscodePrompt(context: context, mode: .setAccount(accountId), title: title, completed: completed), for: context.window)
}

func casmosPresentRemoveAccountPasscode(context: AccountContext, completed: @escaping () -> Void) {
    showModal(with: casmosPasscodePrompt(context: context, mode: .removeAccount(context.account.id.int64), title: "Remove Account Passcode", completed: completed), for: context.window)
}

func casmosPresentSetPanicPasscode(context: AccountContext, completed: @escaping () -> Void) {
    let title = CasmosAccountPasscode.hasPanicPasscode() ? "Change Panic Passcode" : "Set Panic Passcode"
    showModal(with: casmosPasscodePrompt(context: context, mode: .setPanic, title: title, completed: completed), for: context.window)
}

func casmosPresentRemovePanicPasscode(context: AccountContext, completed: @escaping () -> Void) {
    showModal(with: casmosPasscodePrompt(context: context, mode: .removePanic, title: "Remove Panic Passcode", completed: completed), for: context.window)
}

func casmosPresentUnlockHidden(context: AccountContext, completed: @escaping () -> Void) {
    showModal(with: casmosPasscodePrompt(context: context, mode: .unlockHidden, title: "Unlock Hidden Account", completed: completed), for: context.window)
}

func casmosHandlePanic(context: AccountContext) {
    let ids = CasmosAccountPasscode.panicAccountIds()
    CasmosAccountPasscode.runPanic()
    if CasmosHooks.logoutOnPanic {
        for id in ids {
            _ = logoutFromAccount(id: AccountRecordId(rawValue: id), accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
        }
    }
    let current = context.account.id.int64
    if ids.contains(current) || CasmosAccountPasscode.isHidden(accountId: current) {
        _ = (context.sharedContext.activeAccountsWithInfo |> take(1) |> deliverOnMainQueue).start(next: { _, accounts in
            if let next = casmosVisibleAccounts(accounts, currentId: nil).first {
                context.sharedContext.switchToAccount(id: next.account.id, action: nil)
            }
        })
    }
}

func casmosApplyPasscodeMatch(_ match: CasmosPasscodeMatch, context: AccountContext?) -> Bool {
    switch match {
    case .none:
        return false
    case .panic:
        if let context {
            casmosHandlePanic(context: context)
        } else {
            CasmosAccountPasscode.runPanic()
        }
        return true
    case let .account(accountId):
        CasmosAccountPasscode.unlockSession(accountId: accountId)
        context?.sharedContext.switchToAccount(id: AccountRecordId(rawValue: accountId), action: nil)
        return true
    }
}
