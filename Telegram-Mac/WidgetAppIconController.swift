//
//  WidgetAppIconController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore

final class WidgetAppIconContainer : View {
    private let strip = CasmosDockIconStrip(frame: .zero)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(strip)
    }

    override func layout() {
        super.layout()
        strip.frame = bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


final class WidgetAppIconController : TelegramGenericViewController<WidgetView<WidgetAppIconContainer>> {
    override init(_ context: AccountContext) {
        super.init(context)
        self.bar = .init(height: 0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.genericView.dataView = WidgetAppIconContainer(frame: .zero)

        let context = self.context
        self.genericView.update(.init(title: { strings().emptyChatAppIcon }, desc: { strings().emptyChatAppIconDesc }, descClick: {
            context.bindings.rootNavigation().push(AppAppearanceViewController(context: context))
        }, buttons: []))
        self.readyOnce()
    }
}
