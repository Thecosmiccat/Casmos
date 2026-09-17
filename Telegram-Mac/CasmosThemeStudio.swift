import AppKit
import TGUIKit
import ColorPalette

private let casmosPaletteTokenList: [(String, String)] = [
    ("accent", "Accent"),
    ("accentIcon", "Accent Icon"),
    ("accentSelect", "Selected Accent"),
    ("basicAccent", "Base Accent"),
    ("text", "Text"),
    ("grayText", "Secondary Text"),
    ("darkGrayText", "Tertiary Text"),
    ("listGrayText", "List Secondary Text"),
    ("link", "Link"),
    ("background", "Row Background"),
    ("chatBackground", "Chat Background"),
    ("listBackground", "List Background"),
    ("grayBackground", "Gray Background"),
    ("grayForeground", "Gray Foreground"),
    ("border", "Border"),
    ("grayIcon", "Icon"),
    ("badge", "Badge"),
    ("badgeMuted", "Muted Badge"),
    ("redUI", "Destructive"),
    ("greenUI", "Positive"),
    ("premium", "Premium"),
    ("selectText", "Text Selection"),
    ("selectMessage", "Selected Message"),
    ("selectMessageBubble", "Selected Bubble"),
    ("indicatorColor", "Indicator"),
    ("grayHighlight", "Highlight"),
    ("focusAnimationColor", "Focus"),
    ("vibrant", "Vibrant"),
    ("grayUI", "Control"),
    ("blackTransparent", "Dim Overlay"),
    ("grayTransparent", "Gray Overlay"),
    ("bubbleBackground_incoming", "Their Messages"),
    ("bubbleBackground_outgoing", "Your Messages"),
    ("textBubble_incoming", "Their Message Text"),
    ("textBubble_outgoing", "Your Message Text"),
    ("grayTextBubble_incoming", "Their Message Subtitle"),
    ("grayTextBubble_outgoing", "Your Message Subtitle"),
    ("bubbleBorder_incoming", "Their Bubble Border"),
    ("bubbleBorder_outgoing", "Your Bubble Border"),
    ("linkBubble_incoming", "Their Link"),
    ("linkBubble_outgoing", "Your Link"),
    ("grayIconBubble_incoming", "Their Bubble Icon"),
    ("grayIconBubble_outgoing", "Your Bubble Icon"),
    ("accentIconBubble_incoming", "Their Bubble Accent"),
    ("accentIconBubble_outgoing", "Your Bubble Accent"),
    ("bubbleBackgroundHighlight_incoming", "Their Bubble Pressed"),
    ("bubbleBackgroundHighlight_outgoing", "Your Bubble Pressed"),
    ("chatReplyTitle", "Reply Title"),
    ("chatReplyTextEnabled", "Reply Text"),
    ("chatDateText", "Chat Date"),
    ("chatDateActive", "Chat Date Chip"),
    ("fileActivityBackground", "File"),
    ("fileActivityForeground", "File Icon"),
    ("waveformBackground", "Voice Track"),
    ("waveformForeground", "Voice Wave"),
    ("webPreviewActivity", "Link Preview"),
    ("monospacedPre", "Code"),
    ("monospacedCode", "Inline Code"),
    ("revealAction_accent_background", "Swipe Accent"),
    ("revealAction_destructive_background", "Swipe Delete"),
    ("revealAction_constructive_background", "Swipe Positive"),
    ("revealAction_warning_background", "Swipe Warning"),
    ("revealAction_neutral1_background", "Swipe Mute"),
    ("groupPeerNameRed", "Name Red"),
    ("groupPeerNameOrange", "Name Orange"),
    ("groupPeerNameViolet", "Name Violet"),
    ("groupPeerNameGreen", "Name Green"),
    ("groupPeerNameCyan", "Name Cyan"),
    ("groupPeerNameBlue", "Name Blue"),
    ("peerAvatarRedTop", "Avatar Red"),
    ("peerAvatarOrangeTop", "Avatar Orange"),
    ("peerAvatarGreenTop", "Avatar Green"),
    ("peerAvatarBlueTop", "Avatar Blue"),
    ("peerAvatarPinkTop", "Avatar Pink")
]

private func casmosTokenTitle(_ key: String) -> String {
    casmosPaletteTokenList.first(where: { $0.0 == key })?.1 ?? key
}

final class CasmosThemeStudioController: TelegramGenericViewController<CasmosThemeStudioView> {
    private let pick = CasmosStudioColorPick()
    private var overlay: [String: NSColor] = [:]
    private var token = "accent"
    private var page = 0

    override init(_ context: AccountContext) {
        super.init(context)
        bar = .init(height: 50)
    }

    override var enableBack: Bool {
        return true
    }

    override var defaultBarTitle: String {
        return "New Theme"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.update(palette: workingPalette(), token: token, page: page)
        genericView.onPage = { [weak self] page in
            guard let self else { return }
            self.page = page
            self.genericView.update(palette: self.workingPalette(), token: self.token, page: page)
        }
        genericView.onPickToken = { [weak self] token in
            self?.selectToken(token)
        }
        genericView.onWell = { [weak self] in
            self?.openPanel()
        }
        genericView.onTokenMenu = { [weak self] token in
            self?.selectToken(token)
        }
        pick.onChange = { [weak self] color in
            self?.applyColor(color)
        }
        readyOnce()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
        panel.close()
        pick.onChange = nil
        casmosCommitCustomTheme(context: context)
    }

    private func workingPalette() -> ColorPalette {
        theme.colors.withCasmosOverlay(overlay)
    }

    private func selectToken(_ token: String) {
        self.token = token
        genericView.update(palette: workingPalette(), token: token, page: page)
    }

    private func openPanel() {
        let panel = NSColorPanel.shared
        panel.color = workingPalette().casmosColor(token)
        panel.isContinuous = true
        panel.setTarget(pick)
        panel.setAction(#selector(CasmosStudioColorPick.changed(_:)))
        panel.makeKeyAndOrderFront(nil)
    }

    private func applyColor(_ color: NSColor) {
        overlay[token] = color
        let palette = workingPalette()
        genericView.update(palette: palette, token: token, page: page)
        let wallpaper = token == "chatBackground" || token == "background" || token == "listBackground"
        casmosQueueCustomTheme(context: context, palette: palette, wallpaper: wallpaper)
    }
}

final class CasmosStudioColorPick: NSObject {
    var onChange: ((NSColor) -> Void)?
    @objc func changed(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}

final class CasmosThemeStudioView: View {
    var onPage: ((Int) -> Void)?
    var onPickToken: ((String) -> Void)?
    var onWell: (() -> Void)?
    var onTokenMenu: ((String) -> Void)?

    private let segments = NSSegmentedControl()
    private let preview = CasmosThemePreviewCanvas(frame: .zero)
    private let dock = View()
    private let tokenButton = TextButton()
    private let well = Control()
    private let chips = NSScrollView()
    private let chipStrip = View()
    private var palette: ColorPalette = theme.colors
    private var token = "accent"

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        segments.segmentCount = 5
        segments.segmentStyle = .rounded
        segments.trackingMode = .selectOne
        segments.setLabel("Chats", forSegment: 0)
        segments.setLabel("Chat", forSegment: 1)
        segments.setLabel("Call", forSegment: 2)
        segments.setLabel("Settings", forSegment: 3)
        segments.setLabel("Profile", forSegment: 4)
        segments.selectedSegment = 0
        segments.target = self
        segments.action = #selector(changedPage)
        addSubview(segments)

        preview.set(handler: { [weak self] _ in
            self?.handlePreviewClick()
        }, for: .Click)
        addSubview(preview)

        dock.border = [.Top]
        addSubview(dock)

        tokenButton.set(font: .medium(.text), for: .Normal)
        tokenButton.set(handler: { [weak self] _ in
            self?.showTokenMenu()
        }, for: .Click)
        dock.addSubview(tokenButton)

        well.layer?.cornerRadius = 6
        well.layer?.borderWidth = 1
        well.set(handler: { [weak self] _ in
            self?.onWell?()
        }, for: .Click)
        dock.addSubview(well)

        chips.drawsBackground = false
        chips.hasHorizontalScroller = true
        chips.hasVerticalScroller = false
        chips.autohidesScrollers = true
        chips.borderType = .noBorder
        chips.documentView = chipStrip
        dock.addSubview(chips)
        buildChips()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(palette: ColorPalette, token: String, page: Int) {
        self.palette = palette
        self.token = token
        segments.selectedSegment = page
        preview.palette = palette
        preview.page = page
        preview.selected = token
        preview.needsDisplay = true
        tokenButton.set(color: palette.accent, for: .Normal)
        tokenButton.set(text: casmosTokenTitle(token), for: .Normal)
        tokenButton.sizeToFit(NSMakeSize(8, 4))
        well.backgroundColor = palette.casmosColor(token)
        well.layer?.borderColor = palette.border.cgColor
        backgroundColor = palette.listBackground
        dock.backgroundColor = palette.background
        chipStrip.backgroundColor = palette.background
        for view in chipStrip.subviews {
            guard let chip = view as? Control, let key = chip.identifier?.rawValue else {
                continue
            }
            chip.backgroundColor = palette.casmosColor(key)
            chip.layer?.borderWidth = key == token ? 2 : 1
            chip.layer?.borderColor = (key == token ? palette.accent : palette.border).cgColor
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        segments.frame = NSMakeRect(16, 10, frame.width - 32, 24)
        dock.frame = NSMakeRect(0, frame.height - 92, frame.width, 92)
        preview.frame = NSMakeRect(0, 42, frame.width, max(0, frame.height - 42 - 92))
        well.frame = NSMakeRect(16, 10, 28, 28)
        tokenButton.setFrameOrigin(NSMakePoint(52, 12))
        chips.frame = NSMakeRect(0, 46, frame.width, 40)
    }

    @objc private func changedPage() {
        onPage?(segments.selectedSegment)
    }

    private func handlePreviewClick() {
        guard let window else { return }
        let loc = preview.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if let token = preview.token(at: loc) {
            onPickToken?(token)
            onWell?()
        }
    }

    private func buildChips() {
        chipStrip.removeAllSubviews()
        var x: CGFloat = 12
        for (key, title) in casmosPaletteTokenList {
            let chip = Control(frame: NSMakeRect(x, 6, 24, 24))
            chip.layer?.cornerRadius = 12
            chip.layer?.borderWidth = 1
            chip.identifier = NSUserInterfaceItemIdentifier(key)
            chip.toolTip = title
            chip.set(handler: { [weak self] _ in
                self?.onTokenMenu?(key)
                self?.onWell?()
            }, for: .Click)
            chipStrip.addSubview(chip)
            x += 28
        }
        chipStrip.frame = NSMakeRect(0, 0, x + 8, 36)
    }

    private func showTokenMenu() {
        let menu = NSMenu()
        for (key, title) in casmosPaletteTokenList {
            let item = NSMenuItem(title: title, action: #selector(pickedToken(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            item.state = key == token ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSMakePoint(tokenButton.frame.minX, tokenButton.frame.maxY + 4), in: dock)
    }

    @objc private func pickedToken(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        onTokenMenu?(key)
        onWell?()
    }
}

private final class CasmosThemePreviewCanvas: Control {
    var palette: ColorPalette = theme.colors
    var page = 0
    var selected = "accent"
    private var hits: [(NSRect, String)] = []

    func token(at point: NSPoint) -> String? {
        for (rect, token) in hits.reversed() {
            if rect.contains(point) {
                return token
            }
        }
        return nil
    }

    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        hits.removeAll()
        let p = palette
        let bounds = self.bounds
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: isFlipped)
        func mark(_ rect: NSRect, _ token: String) {
            hits.append((rect, token))
            if token == selected {
                NSColor.white.withAlphaComponent(0.45).setStroke()
                let ring = NSBezierPath(roundedRect: rect.insetBy(dx: -2, dy: -2), xRadius: min(12, rect.height / 2 + 2), yRadius: min(12, rect.height / 2 + 2))
                ring.lineWidth = 2
                ring.stroke()
            }
        }
        func fill(_ rect: NSRect, _ color: NSColor, _ token: String, radius: CGFloat = 10) {
            color.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            mark(rect, token)
        }
        func label(_ text: String, _ color: NSColor, _ rect: NSRect, size: CGFloat = 13, medium: Bool = false) {
            let font: NSFont = medium ? .medium(size) : .normal(size)
            (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color])
        }
        switch page {
        case 0:
            drawChats(p, bounds, fill, label, mark)
        case 1:
            drawChat(p, bounds, fill, label, mark)
        case 2:
            drawCall(p, bounds, fill, label, mark)
        case 3:
            drawSettings(p, bounds, fill, label, mark)
        default:
            drawProfile(p, bounds, fill, label, mark)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawChats(_ p: ColorPalette, _ bounds: NSRect, _ fill: (NSRect, NSColor, String, CGFloat) -> Void, _ label: (String, NSColor, NSRect, CGFloat, Bool) -> Void, _ mark: (NSRect, String) -> Void) {
        p.listBackground.setFill()
        NSBezierPath(rect: bounds).fill()
        mark(bounds, "listBackground")
        let search = NSMakeRect(12, 10, bounds.width - 24, 28)
        fill(search, p.grayBackground, "grayBackground", 8)
        label("Search", p.grayText, NSMakeRect(search.minX + 10, search.minY + 6, 120, 16), 12, false)
        mark(NSMakeRect(search.minX + 10, search.minY + 6, 120, 16), "grayText")
        let names = ["Alex Rivera", "Design crew", "Mica", "Saved", "Replies", "Archived"]
        let previews = ["See you in an hour", "Sticker", "Models unloaded", "Notes", "jeff u are so not opsec", "User Info"]
        let tokens = ["peerAvatarPinkTop", "peerAvatarGreenTop", "peerAvatarOrangeTop", "peerAvatarBlueTop", "peerAvatarRedTop", "grayBackground"]
        let tabH: CGFloat = 52
        let rowH: CGFloat = 58
        let startY: CGFloat = 48
        let count = min(names.count, max(4, Int((bounds.height - startY - tabH) / rowH)))
        for i in 0..<count {
            let y = startY + CGFloat(i) * rowH
            let row = NSMakeRect(0, y, bounds.width, rowH - 2)
            fill(row, i == 0 ? p.grayHighlight : p.background, i == 0 ? "grayHighlight" : "background", 0)
            let avatar = NSMakeRect(16, y + 11, 36, 36)
            fill(avatar, p.casmosColor(tokens[i]), tokens[i], 18)
            label(names[i], p.text, NSMakeRect(62, y + 12, 180, 18), 13, true)
            mark(NSMakeRect(62, y + 12, 180, 18), "text")
            label(previews[i], p.listGrayText, NSMakeRect(62, y + 32, 200, 16), 12, false)
            mark(NSMakeRect(62, y + 32, 200, 16), "listGrayText")
            if i == 0 {
                fill(NSMakeRect(row.maxX - 36, y + 19, 20, 20), p.badge, "badge", 10)
            } else if i == 2 {
                fill(NSMakeRect(row.maxX - 36, y + 19, 20, 20), p.badgeMuted, "badgeMuted", 10)
            }
        }
        let tabs = NSMakeRect(0, bounds.height - tabH, bounds.width, tabH)
        fill(tabs, p.background, "background", 0)
        p.border.setFill()
        NSBezierPath(rect: NSMakeRect(0, tabs.minY, bounds.width, 1)).fill()
        mark(NSMakeRect(0, tabs.minY, bounds.width, 1), "border")
        let icons = [p.grayIcon, p.grayIcon, p.accentIcon, p.grayIcon]
        let keys = ["grayIcon", "grayIcon", "accentIcon", "grayIcon"]
        let w = tabs.width / 4
        for i in 0..<4 {
            let dot = NSMakeRect(tabs.minX + w * CGFloat(i) + (w - 22) / 2, tabs.minY + 15, 22, 22)
            fill(dot, icons[i], keys[i], 11)
        }
    }

    private func drawChat(_ p: ColorPalette, _ bounds: NSRect, _ fill: (NSRect, NSColor, String, CGFloat) -> Void, _ label: (String, NSColor, NSRect, CGFloat, Bool) -> Void, _ mark: (NSRect, String) -> Void) {
        p.chatBackground.setFill()
        NSBezierPath(rect: bounds).fill()
        mark(bounds, "chatBackground")
        let header = NSMakeRect(0, 0, bounds.width, 44)
        fill(header, p.background, "background", 0)
        fill(NSMakeRect(12, 8, 28, 28), p.accent, "accent", 14)
        label("Alex Rivera", p.text, NSMakeRect(48, 6, 180, 18), 13, true)
        mark(NSMakeRect(48, 6, 180, 18), "text")
        label("online", p.accent, NSMakeRect(48, 24, 80, 14), 11, false)
        mark(NSMakeRect(48, 24, 80, 14), "accent")
        fill(NSMakeRect(bounds.width - 70, 12, 20, 20), p.grayIcon, "grayIcon", 10)
        fill(NSMakeRect(bounds.width - 40, 12, 20, 20), p.accentIcon, "accentIcon", 10)
        let date = NSMakeRect((bounds.width - 72) / 2, 54, 72, 20)
        fill(date, p.chatDateActive, "chatDateActive", 10)
        label("Today", p.chatDateText, date.insetBy(dx: 14, dy: 3), 11, false)
        mark(date.insetBy(dx: 14, dy: 3), "chatDateText")
        let incoming = NSMakeRect(16, 86, min(230, bounds.width - 80), 54)
        fill(incoming, p.bubbleBackground_incoming, "bubbleBackground_incoming", 12)
        label("On my way", p.textBubble_incoming, NSMakeRect(incoming.minX + 12, incoming.minY + 8, 180, 16), 13, false)
        mark(NSMakeRect(incoming.minX + 12, incoming.minY + 8, 180, 16), "textBubble_incoming")
        label("21:50", p.grayTextBubble_incoming, NSMakeRect(incoming.minX + 12, incoming.minY + 30, 80, 14), 11, false)
        mark(NSMakeRect(incoming.minX + 12, incoming.minY + 30, 80, 14), "grayTextBubble_incoming")
        let replyW = min(250, bounds.width - 80)
        let reply = NSMakeRect(bounds.width - replyW - 16, 152, replyW, 64)
        fill(reply, p.blendedOutgoingColors, "bubbleBackground_outgoing", 12)
        fill(NSMakeRect(reply.minX + 10, reply.minY + 8, 4, 28), p.chatReplyTitle, "chatReplyTitle", 2)
        label("You", p.chatReplyTitle, NSMakeRect(reply.minX + 20, reply.minY + 6, 120, 14), 11, true)
        mark(NSMakeRect(reply.minX + 20, reply.minY + 6, 120, 14), "chatReplyTitle")
        label("Bring the keys", p.chatReplyTextEnabled, NSMakeRect(reply.minX + 20, reply.minY + 22, 160, 14), 11, false)
        mark(NSMakeRect(reply.minX + 20, reply.minY + 22, 160, 14), "chatReplyTextEnabled")
        label("Got it", p.textBubble_outgoing, NSMakeRect(reply.minX + 12, reply.minY + 42, 120, 16), 13, false)
        mark(NSMakeRect(reply.minX + 12, reply.minY + 42, 120, 16), "textBubble_outgoing")
        let voice = NSMakeRect(16, 230, min(200, bounds.width - 90), 36)
        fill(voice, p.bubbleBackground_incoming, "bubbleBackground_incoming", 12)
        fill(NSMakeRect(voice.minX + 10, voice.minY + 8, 20, 20), p.fileActivityBackground, "fileActivityBackground", 10)
        fill(NSMakeRect(voice.minX + 38, voice.minY + 12, voice.width - 50, 12), p.waveformForeground, "waveformForeground", 3)
        let link = NSMakeRect(16, 276, min(220, bounds.width - 80), 40)
        fill(link, p.webPreviewActivity, "webPreviewActivity", 10)
        label("casmos.app", p.link, NSMakeRect(link.minX + 12, link.minY + 12, 160, 16), 12, false)
        mark(NSMakeRect(link.minX + 12, link.minY + 12, 160, 16), "link")
        let composer = NSMakeRect(12, bounds.height - 52, bounds.width - 24, 40)
        fill(composer, p.background, "background", 12)
        fill(NSMakeRect(composer.minX + 8, composer.minY + 8, 24, 24), p.grayIcon, "grayIcon", 8)
        label("Message", p.grayText, NSMakeRect(composer.minX + 40, composer.minY + 11, 120, 18), 13, false)
        mark(NSMakeRect(composer.minX + 40, composer.minY + 11, 120, 18), "grayText")
        fill(NSMakeRect(composer.maxX - 32, composer.minY + 8, 24, 24), p.accent, "accent", 12)
    }

    private func drawCall(_ p: ColorPalette, _ bounds: NSRect, _ fill: (NSRect, NSColor, String, CGFloat) -> Void, _ label: (String, NSColor, NSRect, CGFloat, Bool) -> Void, _ mark: (NSRect, String) -> Void) {
        p.background.darker(amount: 0.35).setFill()
        NSBezierPath(rect: bounds).fill()
        mark(bounds, "background")
        let blob = NSMakeRect((bounds.width - 120) / 2, 16, 120, 120)
        fill(blob, p.accent.withAlphaComponent(0.55), "accent", 60)
        fill(blob.insetBy(dx: 28, dy: 28), p.grayBackground, "grayBackground", 32)
        label("Alex Rivera", p.text, NSMakeRect(16, blob.maxY + 10, bounds.width - 32, 20), 15, true)
        mark(NSMakeRect(16, blob.maxY + 10, bounds.width - 32, 20), "text")
        label("Ringing…", p.grayText, NSMakeRect(16, blob.maxY + 32, bounds.width - 32, 16), 12, false)
        mark(NSMakeRect(16, blob.maxY + 32, bounds.width - 32, 16), "grayText")
        let buttons: [(CGFloat, NSColor, String)] = [
            (-90, p.grayUI, "grayUI"),
            (-30, p.greenUI, "greenUI"),
            (30, p.accent, "accent"),
            (90, p.redUI, "redUI")
        ]
        let by = blob.maxY + 58
        for (dx, color, token) in buttons {
            fill(NSMakeRect(bounds.width / 2 + dx - 18, by, 36, 36), color, token, 18)
        }
        let card = NSMakeRect(12, by + 52, bounds.width - 24, max(90, bounds.height - (by + 64)))
        fill(card, p.background, "background", 12)
        label("Call Settings", p.text, NSMakeRect(card.minX + 16, card.minY + 12, 200, 18), 13, true)
        mark(NSMakeRect(card.minX + 16, card.minY + 12, 200, 18), "text")
        label("Microphone", p.grayText, NSMakeRect(card.minX + 16, card.minY + 38, 160, 16), 12, false)
        mark(NSMakeRect(card.minX + 16, card.minY + 38, 160, 16), "grayText")
        fill(NSMakeRect(card.maxX - 48, card.minY + 38, 32, 18), p.accent, "accent", 9)
        p.border.setFill()
        NSBezierPath(rect: NSMakeRect(card.minX + 16, card.minY + 64, card.width - 32, 1)).fill()
        mark(NSMakeRect(card.minX + 16, card.minY + 64, card.width - 32, 1), "border")
        label("Camera", p.text, NSMakeRect(card.minX + 16, card.minY + 74, 160, 16), 13, false)
        mark(NSMakeRect(card.minX + 16, card.minY + 74, 160, 16), "text")
        fill(NSMakeRect(card.maxX - 48, card.minY + 74, 32, 18), p.grayUI, "grayUI", 9)
    }

    private func drawSettings(_ p: ColorPalette, _ bounds: NSRect, _ fill: (NSRect, NSColor, String, CGFloat) -> Void, _ label: (String, NSColor, NSRect, CGFloat, Bool) -> Void, _ mark: (NSRect, String) -> Void) {
        p.listBackground.setFill()
        NSBezierPath(rect: bounds).fill()
        mark(bounds, "listBackground")
        let card = NSMakeRect(12, 12, bounds.width - 24, min(260, bounds.height - 24))
        fill(card, p.background, "background", 12)
        let rows: [(String, String, String, NSColor)] = [
            ("Notifications", "accent", "On", p.accent),
            ("Privacy", "grayText", "Last seen", p.grayText),
            ("Appearance", "text", "Night", p.text),
            ("Data", "link", "Proxy", p.link),
            ("Premium", "premium", "Stars", p.premium)
        ]
        for (i, row) in rows.enumerated() {
            let y = card.minY + 14 + CGFloat(i) * 40
            label(row.0, p.text, NSMakeRect(card.minX + 16, y, 140, 18), 13, true)
            mark(NSMakeRect(card.minX + 16, y, 140, 18), "text")
            label(row.2, row.3, NSMakeRect(card.maxX - 90, y, 74, 18), 12, false)
            mark(NSMakeRect(card.maxX - 90, y, 74, 18), row.1)
            if i < rows.count - 1 {
                p.border.setFill()
                NSBezierPath(rect: NSMakeRect(card.minX + 16, y + 28, card.width - 32, 1)).fill()
                mark(NSMakeRect(card.minX + 16, y + 28, card.width - 32, 1), "border")
            }
        }
        let dangerY = card.minY + 14 + CGFloat(rows.count) * 40
        if dangerY + 20 < card.maxY {
            label("Delete Account", p.redUI, NSMakeRect(card.minX + 16, dangerY, 200, 18), 13, true)
            mark(NSMakeRect(card.minX + 16, dangerY, 200, 18), "redUI")
        }
    }

    private func drawProfile(_ p: ColorPalette, _ bounds: NSRect, _ fill: (NSRect, NSColor, String, CGFloat) -> Void, _ label: (String, NSColor, NSRect, CGFloat, Bool) -> Void, _ mark: (NSRect, String) -> Void) {
        p.listBackground.setFill()
        NSBezierPath(rect: bounds).fill()
        mark(bounds, "listBackground")
        let banner = NSMakeRect(0, 0, bounds.width, min(210, bounds.height * 0.55))
        fill(banner, p.accent.darker(amount: 0.25), "accent", 0)
        fill(NSMakeRect((bounds.width - 88) / 2, 18, 88, 88), p.grayBackground, "grayBackground", 44)
        label("Alex Rivera", .white, NSMakeRect(16, 116, bounds.width - 32, 22), 16, true)
        mark(NSMakeRect(16, 116, bounds.width - 32, 22), "text")
        label("online", NSColor.white.withAlphaComponent(0.85), NSMakeRect(16, 140, bounds.width - 32, 16), 12, false)
        let actionsY = banner.maxY + 16
        let pillW: CGFloat = 88
        fill(NSMakeRect(bounds.width / 2 - pillW - 8, actionsY, pillW, 32), p.accent, "accent", 8)
        fill(NSMakeRect(bounds.width / 2 + 8, actionsY, pillW, 32), p.grayBackground, "grayBackground", 8)
        let info = NSMakeRect(12, actionsY + 48, bounds.width - 24, 72)
        fill(info, p.background, "background", 12)
        label("bio", p.grayText, NSMakeRect(info.minX + 16, info.minY + 12, 80, 14), 11, false)
        mark(NSMakeRect(info.minX + 16, info.minY + 12, 80, 14), "grayText")
        label("building casmos", p.text, NSMakeRect(info.minX + 16, info.minY + 30, 200, 18), 13, false)
        mark(NSMakeRect(info.minX + 16, info.minY + 30, 200, 18), "text")
        label("@alex", p.link, NSMakeRect(info.minX + 16, info.minY + 50, 120, 16), 12, false)
        mark(NSMakeRect(info.minX + 16, info.minY + 50, 120, 16), "link")
    }
}
