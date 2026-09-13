//
//  Auth_QRCode.swift
//  Telegram
//
//  Created by Mike Renoir on 14.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import ColorPalette
import TelegramMedia

enum QRTokenState {
    case qr(CGImage)
}

private final class ExportTokenOptionView : View {
    private let textView: TextView = TextView()
    private let optionText = TextView()
    private let cap = View(frame: NSMakeRect(0, 0, 20, 20))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        cap.layer?.cornerRadius = cap.frame.height / 2
        
        textView.isSelectable = false
        textView.userInteractionEnabled = false
        
        optionText.isSelectable = false
        optionText.userInteractionEnabled = false
        addSubview(cap)
        addSubview(self.textView)
        addSubview(self.optionText)
    }
    
    func update(title: String, number: String) {
        let textAttr = NSMutableAttributedString()
        _ = textAttr.append(string: title, color: theme.colors.text, font: .normal(.text))
        textAttr.detectBoldColorInString(with: .medium(.text))
        let text = TextViewLayout(textAttr, maximumNumberOfLines: 2)
        text.measure(width: frame.width - cap.frame.width - 10)
        textView.update(text)
        
        let option = TextViewLayout(.initialize(string: number, color: theme.colors.underSelectedColor, font: .code(.text)), maximumNumberOfLines: 2)
        option.measure(width: frame.width)
        optionText.update(option)
        
        cap.backgroundColor = theme.colors.accent
        
        setFrameSize(NSMakeSize(cap.frame.width + 10 + text.layoutSize.width, max(cap.frame.height, 4 + text.layoutSize.height + 4)))
    }
    
    override func layout() {
        super.layout()
        
        cap.setFrameOrigin(NSZeroPoint)
        let offset: CGFloat = optionText.frame.width == 6 ? 7 : 6
        optionText.setFrameOrigin(NSMakePoint(offset, 2))
        textView.setFrameOrigin(NSMakePoint(cap.frame.maxX + 10, 2))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class Auth_TokenView : View {
    fileprivate let imageView: ImageView = ImageView(frame: Auth_Insets.qrSize.bounds)
    private let animation: LottiePlayerView = LottiePlayerView(frame: Auth_Insets.qrAnimSize.bounds)
    fileprivate let logoView: ImageView = ImageView(frame: NSMakeRect(0, 0, 40, 40))
    private let containerView = View()
    private let titleView = TextView()
    fileprivate let cancelButton = TextButton()
    
    private let firstHelp: ExportTokenOptionView
    private let secondHelp: ExportTokenOptionView
    private let thridHelp: ExportTokenOptionView
    private let helpView = View()
    
    private let shimmeringView = ShimmerEffectView()
    private let animationContainer = View()

    fileprivate var cancel:(()->Void)?

    required init(frame frameRect: NSRect) {
        firstHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        secondHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        thridHelp = ExportTokenOptionView(frame: NSMakeRect(0, 0, frameRect.width, 0))
        super.init(frame: frameRect)
        
        self.animationContainer.isHidden = true
        
        containerView.addSubview(self.imageView)
        animationContainer.addSubview(self.animation)
        containerView.addSubview(self.animationContainer)
        containerView.addSubview(self.logoView)
        containerView.addSubview(self.titleView)
        containerView.addSubview(self.cancelButton)
        
        containerView.addSubview(helpView)
        
        helpView.addSubview(self.firstHelp)
        helpView.addSubview(self.secondHelp)
        helpView.addSubview(self.thridHelp)

        
        addSubview(containerView)
        titleView.isSelectable = false
        titleView.userInteractionEnabled = false
        updateLocalizationAndTheme(theme: theme)
        
        cancelButton.set(handler: { [weak self] _ in
            self?.cancel?()
        }, for: .Click)
    }
    
    private func measure() {
        let titleLayout = TextViewLayout(.initialize(string: strings().loginQRTitle, color: theme.colors.text, font: .medium(18)), maximumNumberOfLines: 2, alignment: .center)
        titleLayout.measure(width: frame.width)
        titleView.update(titleLayout)
        
        firstHelp.update(title: strings().loginQR1Help1, number: "1")
        secondHelp.update(title: strings().loginQR2Help2, number: "2")
        thridHelp.update(title: strings().loginQR1Help3, number: "3")
        
        cancelButton.set(font: Auth_Insets.infoFontBold, for: .Normal)
        cancelButton.set(color: theme.colors.accent, for: .Normal)
        cancelButton.set(text: strings().loginQRCancel, for: .Normal)
        _ = cancelButton.sizeToFit()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let theme = theme as! TelegramPresentationTheme
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = theme.colors.background
        animationContainer.background = dayClassicPalette.background
        animationContainer.layer?.cornerRadius = 10
        
        measure()
        
        updateLottie()
        
       needsLayout = true
    }
    
    private func updateLottie() {
        // Casmos Option B QR chip (qr_chip_40); paper-plane Lottie retired.
        if let image = NSImage(named: "CasmosQRChip")?.precomposed() {
            self.logoView.image = image
        } else {
            self.logoView.image = nil
        }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateLottie()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(state: QRTokenState, isLoading _: Bool) {
        switch state {
        case let .qr(image):
            self.imageView.animates = true
            self.imageView.image = image
            imageView.sizeToFit()
        }
        needsLayout = true
    }
    
    override func layout() {
            
        firstHelp.setFrameOrigin(NSMakePoint(0, 0))
        secondHelp.setFrameOrigin(NSMakePoint(0, firstHelp.frame.maxY + 10))
        thridHelp.setFrameOrigin(NSMakePoint(0, secondHelp.frame.maxY + 10))
        
        helpView.setFrameSize(NSMakeSize(max(firstHelp.frame.width, secondHelp.frame.width, thridHelp.frame.width), thridHelp.frame.maxY))

        
        containerView.setFrameSize(NSMakeSize(frame.width, imageView.frame.height + Auth_Insets.betweenHeader + self.titleView.frame.height + Auth_Insets.betweenHeader + helpView.frame.height + Auth_Insets.betweenHeader + cancelButton.frame.height))
        containerView.center()
        
        animationContainer.setFrameSize(Auth_Insets.qrSize)
        
        animationContainer.centerX(y: 0)
        imageView.centerX(y: 0)
        animation.center()
        
        logoView.centerX(y: floor((imageView.frame.height - logoView.frame.height) / 2))
        titleView.updateWithNewWidth(containerView.frame.width)
        titleView.centerX(y: imageView.frame.maxY + Auth_Insets.betweenHeader)

        helpView.centerX(y: titleView.frame.maxY + Auth_Insets.betweenHeader)
       
        cancelButton.centerX(y: helpView.frame.maxY + Auth_Insets.betweenHeader)
        
    }
}


final class Auth_TokenController : GenericViewController<Auth_TokenView> {
    private let temp:Data
    required override init(frame: NSRect) {
        var data = Data(count: 34)
        let _ = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 34, $0)
        }
        self.temp = data
        super.init(frame: frame)
    }
    private var token: AuthTransferExportedToken?
    
    func update(_ token: AuthTransferExportedToken?, cancel:@escaping()->Void) {
        
        var tokenString = (token?.value ?? temp).base64EncodedString()
        tokenString = tokenString.replacingOccurrences(of: "+", with: "-")
        tokenString = tokenString.replacingOccurrences(of: "/", with: "_")
        let urlString = "tg://login?token=\(tokenString)"
        
        self.token = token
        
        let signal = (qrCode(string: urlString, color: dayClassicPalette.text, backgroundColor: dayClassicPalette.background, icon: .custom(theme.icons.login_qr_empty_cap))
                      |> deliverOnMainQueue)
        
        let _ = signal.start(next: { [weak self] _, generate in
                guard let strongSelf = self else {
                    return
                }
            let context = generate(TransformImageArguments(corners: ImageCorners(radius: 10), imageSize: Auth_Insets.qrSize, boundingSize: Auth_Insets.qrSize, intrinsicInsets: NSEdgeInsets(), scale: System.backingScale))
                if let image = context?.generateImage() {
                    strongSelf.genericView.update(state: .qr(image), isLoading: token == nil)
                }
            })
        
        genericView.cancel = cancel
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        if let cancel = genericView.cancel {
            self.update(self.token, cancel: cancel)
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
