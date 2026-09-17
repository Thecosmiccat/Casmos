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
    private let imageView = ImageView(frame: .zero)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.nsImage = NSImage(named: NSImage.applicationIconName)
        imageView.contentGravity = .resizeAspect
        imageView.setAccessibilityElement(true)
        imageView.setAccessibilityRole(.image)
        imageView.setAccessibilityLabel("App Icon")
        addSubview(imageView)
    }

    override func layout() {
        super.layout()
        let size: CGFloat = 96
        imageView.frame = NSMakeRect(floor((frame.width - size) / 2), floor((frame.height - size) / 2), size, size)
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
        self.genericView.update(.init(title: { "App Icon" }, desc: { "Coming soon. The default icon is in Settings ⟶ [Appearance](appearance)." }, descClick: {
            context.bindings.rootNavigation().push(AppAppearanceViewController(context: context))
        }, buttons: []))
        self.readyOnce()
    }
}
