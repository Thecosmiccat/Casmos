import AppKit
import Foundation
import Speech
import SwiftSignalKit
import TGUIKit
import TelegramCore
import Postbox
import Casmos

private let casmosFrostIdentifier = NSUserInterfaceItemIdentifier("casmos.frost")

func applyCasmosFrostedWindow(_ window: NSWindow, enabled: Bool) {
    guard let content = window.contentView else {
        return
    }
    content.subviews.filter { $0.identifier == casmosFrostIdentifier }.forEach { $0.removeFromSuperview() }
    window.isOpaque = true
    window.titleVisibility = .visible
    if window.styleMask.contains(.fullSizeContentView) {
        window.styleMask.remove(.fullSizeContentView)
    }
    if enabled {
        window.titlebarAppearsTransparent = false
    }
    content.needsLayout = true
}

func casmosTranscribeAudioFile(path: String, locale: String, completion: @escaping (String?) -> Void) {
    if #available(macOS 10.15, *) {
        SFSpeechRecognizer.requestAuthorization { status in
            Queue.mainQueue().async {
                guard status == .authorized, let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else {
                    completion(nil)
                    return
                }
                recognizer.supportsOnDeviceRecognition = true
                let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: path))
                request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
                request.shouldReportPartialResults = false
                var finished = false
                recognizer.recognitionTask(with: request) { result, error in
                    let text: String?
                    if let result, result.isFinal {
                        let value = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                        text = value.isEmpty ? nil : value
                    } else if error != nil {
                        text = nil
                    } else {
                        return
                    }
                    Queue.mainQueue().async {
                        guard !finished else {
                            return
                        }
                        finished = true
                        completion(text)
                    }
                }
            }
        }
    } else {
        completion(nil)
    }
}

enum CasmosGitHubRelease {
    case unavailable
    case current
    case newer(tag: String, page: URL)
}

private func casmosReleaseTag(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count >= 2, (trimmed.first == "v" || trimmed.first == "V"), trimmed.dropFirst().first?.isNumber == true {
        return String(trimmed.dropFirst())
    }
    return trimmed
}

func casmosCheckGitHubReleases(_ completion: ((CasmosGitHubRelease) -> Void)? = nil) {
    guard let url = URL(string: "https://api.github.com/repos/Thecosmiccat/Casmos/releases/latest") else {
        completion?(.unavailable)
        return
    }
    var request = URLRequest(url: url)
    request.setValue("Casmos", forHTTPHeaderField: "User-Agent")
    URLSession.shared.dataTask(with: request) { data, response, _ in
        Queue.mainQueue().async {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 || data == nil {
                completion?(.unavailable)
                return
            }
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion?(.unavailable)
                return
            }
            let tag = (json["tag_name"] as? String) ?? ""
            let html = json["html_url"] as? String
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            if !tag.isEmpty, casmosReleaseTag(tag) != casmosReleaseTag(current), let html, let page = URL(string: html) {
                if let window = appDelegate?.window {
                    verifyAlert_button(for: window, header: "Casmos Update", information: "GitHub has \(tag). This build is \(current).", ok: "Open Release", successHandler: { _ in
                        NSWorkspace.shared.open(page)
                    })
                }
                completion?(.newer(tag: tag, page: page))
            } else {
                completion?(.current)
            }
        }
    }.resume()
}

private let casmosBannerShareDisposable = MetaDisposable()
private let casmosBannerFetchDisposable = MetaDisposable()
private var casmosBannerFetching = Set<Int64>()

private func casmosRotatedBanner(_ image: NSImage, quarters: Int) -> NSImage {
    let q = ((quarters % 4) + 4) % 4
    if q == 0 {
        return image
    }
    let src = image.size
    let size = q % 2 == 1 ? NSMakeSize(src.height, src.width) : src
    return NSImage(size: size, flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            return false
        }
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: CGFloat(q) * .pi / 2)
        image.draw(in: NSRect(x: -src.width / 2, y: -src.height / 2, width: src.width, height: src.height), from: .zero, operation: .copy, fraction: 1)
        return true
    }
}

private let casmosBannerOverhang: CGFloat = 110
private let casmosBannerPhoto: CGFloat = 120
private let casmosBannerNameGap: CGFloat = 10
private let casmosBannerStatusGap: CGFloat = 4
private let casmosBannerBelowStatus: CGFloat = 8

private func casmosBannerViewportHeight(nameHeight: CGFloat, statusHeight: CGFloat) -> CGFloat {
    casmosBannerOverhang + casmosBannerPhoto + casmosBannerNameGap + nameHeight + casmosBannerStatusGap + statusHeight + casmosBannerBelowStatus
}

func casmosProfileBannerJPEG(_ image: NSImage, offset: NSPoint = NSMakePoint(0.5, 0.5), scale: CGFloat = 1, quarters: Int = 0, viewport: NSSize = .zero) -> Data? {
    let rotated = casmosRotatedBanner(image, quarters: quarters)
    let src = rotated.size
    guard src.width > 0, src.height > 0 else {
        return nil
    }
    let userScale = min(3, max(0.25, scale))
    let canvasW: CGFloat = 1200
    let aspect = viewport.width > 1 && viewport.height > 1 ? viewport.height / viewport.width : casmosBannerViewportHeight(nameHeight: 22, statusHeight: 16) / 400
    let canvas = NSMakeSize(canvasW, max(1, canvasW * aspect))
    let cover = max(canvas.width / src.width, canvas.height / src.height) * userScale
    let drawn = NSMakeSize(src.width * cover, src.height * cover)
    let origin = NSMakePoint((canvas.width - drawn.width) * offset.x, (canvas.height - drawn.height) * offset.y)
    let rendered = NSImage(size: canvas, flipped: true) { _ in
        NSColor.black.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: canvas))
        NSGraphicsContext.current?.imageInterpolation = .high
        rotated.draw(in: NSRect(origin: origin, size: drawn), from: .zero, operation: .copy, fraction: 1)
        return true
    }
    guard let tiff = rendered.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
    }
    return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
}

private final class CasmosBannerCropControl: Control {
    private let image: NSImage
    var offset = NSMakePoint(0.5, 0.5)
    var scale: CGFloat = 1
    var quarters = 0
    private var dragStart: NSPoint?
    private var offsetStart = NSMakePoint(0.5, 0.5)

    init(frame: NSRect, image: NSImage) {
        self.image = image
        super.init(frame: frame)
        layer?.masksToBounds = true
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    private func fitted() -> (NSImage, NSSize, NSSize) {
        let rotated = casmosRotatedBanner(image, quarters: quarters)
        let src = rotated.size
        let cover = max(bounds.width / src.width, bounds.height / src.height) * scale
        return (rotated, src, NSMakeSize(src.width * cover, src.height * cover))
    }

    func addZoom(_ delta: CGFloat) {
        scale = min(3, max(0.25, scale + delta))
        needsDisplay = true
    }

    func rotate(by delta: Int) {
        quarters = ((quarters + delta) % 4 + 4) % 4
        needsDisplay = true
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }
        let (rotated, src, drawn) = fitted()
        guard src.width > 0, src.height > 0 else {
            return
        }
        let origin = NSMakePoint((bounds.width - drawn.width) * offset.x, (bounds.height - drawn.height) * offset.y)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: isFlipped)
        rotated.draw(in: NSRect(origin: origin, size: drawn), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        offsetStart = offset
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else {
            return
        }
        let loc = convert(event.locationInWindow, from: nil)
        let (_, _, drawn) = fitted()
        let extraX = abs(drawn.width - bounds.width) < 1 ? bounds.width : (drawn.width - bounds.width)
        let extraY = abs(drawn.height - bounds.height) < 1 ? bounds.height : (drawn.height - bounds.height)
        var next = NSMakePoint(offsetStart.x - (loc.x - start.x) / extraX, offsetStart.y - (loc.y - start.y) / extraY)
        next.x = min(2, max(-1, next.x))
        next.y = min(2, max(-1, next.y))
        offset = next
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) > 0.1 {
            addZoom(event.scrollingDeltaY * 0.01)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func magnify(with event: NSEvent) {
        addZoom(event.magnification)
    }
}

private final class CasmosPassHits: View {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

private final class CasmosBannerEditorController: TelegramGenericViewController<View> {
    private let image: NSImage
    private let onConfirm: (NSPoint, CGFloat, Int, NSSize) -> Void
    private var crop: CasmosBannerCropControl?
    private let scrim = View()
    private let chrome = CasmosPassHits(frame: .zero)
    private let photo = AvatarControl(font: .avatar(30))
    private let nameView = TextView()
    private let statusView = TextView()
    private let messageButton = TextButton()
    private let moreButton = TextButton()
    private let hint = TextView()
    private var tools: [TextButton] = []

    init(_ context: AccountContext, image: NSImage, onConfirm: @escaping (NSPoint, CGFloat, Int, NSSize) -> Void) {
        self.image = image
        self.onConfirm = onConfirm
        super.init(context)
        bar = .init(height: 50)
    }

    override var enableBack: Bool {
        return true
    }

    override var defaultBarTitle: String {
        return strings().peerInfoProfileBanner
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.backgroundColor = theme.colors.listBackground

        let crop = CasmosBannerCropControl(frame: .zero, image: image)
        self.crop = crop
        genericView.addSubview(crop)

        scrim.isEventLess = true
        scrim.userInteractionEnabled = false
        let dim = SimpleGradientLayer()
        dim.startPoint = CGPoint(x: 0.5, y: 1)
        dim.endPoint = CGPoint(x: 0.5, y: 0)
        dim.locations = [0, 0.45, 1]
        dim.colors = [
            NSColor.black.withAlphaComponent(0.45).cgColor,
            NSColor.black.withAlphaComponent(0.08).cgColor,
            NSColor.black.withAlphaComponent(0.28).cgColor
        ]
        scrim.layer?.addSublayer(dim)
        scrim.identifier = NSUserInterfaceItemIdentifier("casmos.banner.scrim")
        genericView.addSubview(scrim)
        genericView.customHandler.layout = { [weak self, weak dim] view in
            self?.layoutEditor()
            dim?.frame = self?.scrim.bounds ?? .zero
        }

        photo.setFrameSize(NSMakeSize(casmosBannerPhoto, casmosBannerPhoto))
        photo.userInteractionEnabled = false
        if let peer = context.myPeer {
            photo.setPeer(account: context.account, peer: peer)
        }
        chrome.addSubview(photo)

        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        statusView.userInteractionEnabled = false
        statusView.isSelectable = false
        chrome.addSubview(nameView)
        chrome.addSubview(statusView)
        genericView.addSubview(chrome)

        func pill(_ button: TextButton, title: String) {
            button.set(font: .medium(.text), for: .Normal)
            button.set(color: theme.colors.accent, for: .Normal)
            button.set(background: theme.colors.background, for: .Normal)
            button.set(text: title, for: .Normal)
            button.sizeToFit(NSMakeSize(18, 10))
            button.layer?.cornerRadius = 10
            button.userInteractionEnabled = false
            genericView.addSubview(button)
        }
        pill(messageButton, title: strings().peerInfoActionMessage)
        pill(moreButton, title: strings().peerInfoActionMore)

        func tool(_ title: String, tip: String, handler: @escaping () -> Void) -> TextButton {
            let button = TextButton()
            button.set(font: .medium(.text), for: .Normal)
            button.set(color: theme.colors.accent, for: .Normal)
            button.set(text: title, for: .Normal)
            button.sizeToFit(NSMakeSize(10, 4))
            button.toolTip = tip
            button.set(handler: { _ in handler() }, for: .Click)
            genericView.addSubview(button)
            return button
        }
        tools = [
            tool("−", tip: "Zoom Out") { [weak crop] in crop?.addZoom(-0.2) },
            tool("+", tip: "Zoom In") { [weak crop] in crop?.addZoom(0.2) },
            tool("↺", tip: "Rotate Left") { [weak crop] in crop?.rotate(by: -1) },
            tool("↻", tip: "Rotate Right") { [weak crop] in crop?.rotate(by: 1) },
            tool(strings().peerInfoProfileBannerUse, tip: strings().peerInfoProfileBannerUse) { [weak self] in
                self?.finish()
            }
        ]

        let name = context.myPeer?.displayTitle ?? ""
        nameView.update(TextViewLayout(.initialize(string: name, color: .white, font: .medium(.title)), maximumNumberOfLines: 1, alignment: .center))
        statusView.update(TextViewLayout(.initialize(string: strings().peerStatusOnline, color: NSColor.white.withAlphaComponent(0.85), font: .normal(.short)), maximumNumberOfLines: 1, alignment: .center))
        hint.userInteractionEnabled = false
        hint.isSelectable = false
        hint.update(TextViewLayout(.initialize(string: "Drag to move · scroll to zoom", color: theme.colors.grayText, font: .normal(.small)), maximumNumberOfLines: 1, alignment: .center))
        genericView.addSubview(hint)
        readyOnce()
    }

    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
        layoutEditor()
    }

    private func layoutEditor() {
        let size = genericView.frame.size
        let nameW = min(size.width - 32, 280 as CGFloat)
        nameView.resize(nameW)
        statusView.resize(nameW)
        let bannerH = min(size.height - 96, casmosBannerViewportHeight(nameHeight: nameView.frame.height, statusHeight: statusView.frame.height))
        crop?.frame = NSMakeRect(0, 0, size.width, bannerH)
        crop?.needsDisplay = true
        scrim.frame = NSMakeRect(0, 0, size.width, bannerH)
        chrome.frame = NSMakeRect(0, 0, size.width, bannerH)
        photo.centerX(y: casmosBannerOverhang)
        nameView.centerX(y: photo.frame.maxY + casmosBannerNameGap)
        statusView.centerX(y: nameView.frame.maxY + casmosBannerStatusGap)
        let gap: CGFloat = 12
        let buttonsW = messageButton.frame.width + gap + moreButton.frame.width
        let bx = floor((size.width - buttonsW) / 2)
        messageButton.setFrameOrigin(NSMakePoint(bx, bannerH + 16))
        moreButton.setFrameOrigin(NSMakePoint(bx + messageButton.frame.width + gap, bannerH + 16))
        hint.resize(size.width - 32)
        hint.centerX(y: size.height - 64)
        var x: CGFloat = 16
        for button in tools {
            button.setFrameOrigin(NSMakePoint(x, size.height - 40))
            x += button.frame.width + 10
        }
    }

    override func returnKeyAction() -> KeyHandlerResult {
        finish()
        return .invoked
    }

    private func finish() {
        onConfirm(crop?.offset ?? NSMakePoint(0.5, 0.5), crop?.scale ?? 1, crop?.quarters ?? 0, crop?.frame.size ?? .zero)
        navigationController?.back()
    }
}

private func casmosAboutLimit(_ context: AccountContext) -> Int {
    Int(context.isPremium ? context.premiumLimits.about_length_limit_premium : context.premiumLimits.about_length_limit_default)
}

private func casmosShareOwnBanner(context: AccountContext, jpeg: Data?) {
    let peerId = context.peerId.toInt64()
    let limit = casmosAboutLimit(context)
    let storedAbout = context.account.postbox.transaction { transaction -> String in
        (transaction.getPeerCachedData(peerId: context.peerId) as? CachedUserData)?.about ?? ""
    }
    guard let jpeg else {
        casmosBannerShareDisposable.set((storedAbout |> mapToSignal { stored -> Signal<Void, NoError> in
            let next = CasmosProfileBanners.applyingSlug(nil, to: stored, limit: limit)
            if next == stored {
                return .complete()
            }
            return context.engine.accountData.updateAbout(about: next) |> `catch` { _ in .complete() }
        }).start())
        return
    }
    let resource = LocalFileMediaResource(fileId: arc4random64(), size: Int64(jpeg.count))
    context.account.postbox.mediaBox.storeResourceData(resource.id, data: jpeg)
    let signal = uploadWallpaper(account: context.account, resource: resource, mimeType: "image/jpeg", settings: WallpaperSettings(), forChat: false)
    |> map { Optional($0) }
    |> `catch` { _ in
        return Signal<UploadWallpaperStatus?, NoError>.single(nil)
    }
    |> mapToSignal { status -> Signal<String, NoError> in
        guard let status else {
            return .complete()
        }
        switch status {
        case .progress:
            return Signal<String, NoError>.never()
        case let .complete(wallpaper):
            if case let .file(file) = wallpaper, !file.slug.isEmpty {
                return .single(file.slug)
            }
            return .complete()
        }
    }
    |> mapToSignal { slug -> Signal<Void, NoError> in
        CasmosProfileBanners.setSlug(slug, peerId: peerId)
        return storedAbout |> mapToSignal { stored -> Signal<Void, NoError> in
            let next = CasmosProfileBanners.applyingSlug(slug, to: stored, limit: limit)
            if next == stored {
                return .complete()
            }
            return context.engine.accountData.updateAbout(about: next) |> `catch` { _ in .complete() }
        }
    }
    casmosBannerShareDisposable.set(signal.start())
}

func casmosFetchSharedBannerIfNeeded(context: AccountContext, peerId: PeerId, about: String?) {
    let id = peerId.toInt64()
    guard let slug = CasmosProfileBanners.slug(fromAbout: about) else {
        return
    }
    if CasmosProfileBanners.exists(peerId: id) {
        if CasmosProfileBanners.savedSlug(peerId: id) == slug {
            return
        }
        if CasmosProfileBanners.savedSlug(peerId: id) == nil {
            return
        }
    }
    if casmosBannerFetching.contains(id) {
        return
    }
    casmosBannerFetching.insert(id)
    let signal = getWallpaper(network: context.account.network, slug: slug)
    |> map { Optional($0) }
    |> `catch` { _ in
        return Signal<TelegramWallpaper?, NoError>.single(nil)
    }
    |> mapToSignal { wallpaper -> Signal<Data?, NoError> in
        guard let wallpaper, case let .file(file) = wallpaper else {
            return .single(nil)
        }
        let resource = file.file.resource
        return combineLatest(
            fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .wallpaper(wallpaper: .slug(file.slug), resource: resource))
            |> map { _ in true }
            |> `catch` { _ in .single(false) },
            context.account.postbox.mediaBox.resourceData(resource)
        )
        |> filter { _, data in data.complete }
        |> take(1)
        |> map { _, data in try? Data(contentsOf: URL(fileURLWithPath: data.path)) }
    }
    |> deliverOnMainQueue
    casmosBannerFetchDisposable.set(signal.start(next: { data in
        casmosBannerFetching.remove(id)
        if let data, !data.isEmpty {
            CasmosProfileBanners.save(data, peerId: id, slug: slug)
        }
    }, completed: {
        casmosBannerFetching.remove(id)
    }))
}

func casmosPresentProfileBannerEditor(context: AccountContext, peerId: Int64, onChange: @escaping () -> Void) {
    let own = peerId == context.peerId.toInt64()
    let pick = {
        filePanel(with: photoExts, allowMultiple: false, for: context.window) { paths in
            guard let path = paths?.first, let image = NSImage(contentsOfFile: path) else {
                return
            }
            context.bindings.rootNavigation().push(CasmosBannerEditorController(context, image: image, onConfirm: { offset, scale, quarters, viewport in
                guard let data = casmosProfileBannerJPEG(image, offset: offset, scale: scale, quarters: quarters, viewport: viewport) else {
                    return
                }
                CasmosProfileBanners.save(data, peerId: peerId)
                onChange()
                if own {
                    casmosShareOwnBanner(context: context, jpeg: data)
                }
            }))
        }
    }
    if CasmosProfileBanners.exists(peerId: peerId) {
        verifyAlert(for: context.window, header: strings().peerInfoProfileBanner, information: strings().peerInfoProfileBannerInfo, ok: strings().peerInfoProfileBannerChange, cancel: strings().alertCancel, option: strings().peerInfoProfileBannerRemove, optionIsSelected: nil, successHandler: { result in
            switch result {
            case .basic:
                pick()
            case .thrid:
                CasmosProfileBanners.remove(peerId: peerId)
                onChange()
                if own {
                    casmosShareOwnBanner(context: context, jpeg: nil)
                }
            }
        })
    } else {
        pick()
    }
}
