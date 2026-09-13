//
//  DockControl.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.01.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import ApiCredentials
import InAppSettings
import Dock

extension TelegramApplicationIcons.Icon {
    var path: String {
        return iconsFolder + "/" + self.file.fileName!
    }
    
    func resourcePath(_ context: AccountContext) -> String? {
        if self.file.fileName == TelegramApplicationIcons.Icon.defaultIconName {
            return nil
        } else {
            return context.account.postbox.mediaBox.resourcePath(self.file.resource)
        }
    }
    
    var isPremium: Bool {
        if let fileName = file.fileName, fileName.contains("Premium") {
            return true
        }
        return false
    }
    
    static let defaultIconName = "Default.icns"
}

private var iconsFolder: String {
    return ApiEnvironment.containerURL!.appendingPathComponent("icons").path
}

final class DockControl {
    
    private let promise: ValuePromise<TelegramApplicationIcons> = .init()
    
    var icons: Signal<TelegramApplicationIcons, NoError> {
        return promise.get()
    }
    
    private let disposable = MetaDisposable()
    
    private let fetch = DisposableSet()
    private let data = DisposableSet()
    
    private let engine: TelegramEngine
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let update = MetaDisposable()
    private let applyResource = MetaDisposable()
    init(_ engine: TelegramEngine, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.engine = engine
        self.accountManager = accountManager
        loadResources()
        
        silence()
    }
    
    private func loadResources() {
    }
    
    private func update(_ icons: TelegramApplicationIcons) {
        for icon in icons.icons {
            let fetchDispsable = fetchedMediaResource(mediaBox: engine.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .media(media: AnyMediaReference.message(message: icon.reference, media: icon.file), resource: icon.file.resource)).start()
            fetch.add(fetchDispsable)
        }
        self.promise.set(icons)
    }
    
    private func silence() {
        CasmosDockIcons.restoreFromPrefs()
    }
    
    func clear() {
        update.dispose()
        data.dispose()
        fetch.dispose()
        disposable.dispose()
        applyResource.dispose()
    }
    
    deinit {
        clear()
    }
}

//
//private func moveIconToCache(path: String, icon: TelegramApplicationIcons.Icon) {
//    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: iconsFolder), withIntermediateDirectories: true, attributes: nil)
//    
//    if let fileName = icon.file.fileName {
//        try? FileManager.default.copyItem(atPath: path, toPath: iconsFolder + "/" + fileName)
//    }
//}
