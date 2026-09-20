import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import Casmos

func casmosPromptGroupName(context: AccountContext, title: String, initial: String, done: @escaping (String) -> Void) {
    showModal(with: TextInputController(context: context, title: title, placeholder: "Name", initialText: initial, limit: Int32(CasmosChatGroups.nameLimit), callback: { name in
        done(name)
    }), for: context.window)
}

let casmosChatPeerPasteboardType = NSPasteboard.PasteboardType("app.casmos.chat-peer-id")

private final class CasmosChatDragSource: NSObject, NSDraggingSource {
    static let shared = CasmosChatDragSource()
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

func casmosPeerId(from dragging: NSDraggingInfo) -> Int64? {
    let pasteboard = dragging.draggingPasteboard
    if let value = pasteboard.string(forType: casmosChatPeerPasteboardType), let peerId = Int64(value) {
        return peerId
    }
    for item in pasteboard.pasteboardItems ?? [] {
        if let value = item.string(forType: casmosChatPeerPasteboardType), let peerId = Int64(value) {
            return peerId
        }
    }
    return nil
}

@discardableResult
func casmosBeginChatGroupDrag(item: TableRowItem, event: NSEvent, view: NSView) -> Bool {
    guard let item = item as? ChatListRowItem, !item.isGroup, !item.isAd, let peerId = item.peerId else {
        return false
    }
    let writer = NSPasteboardItem()
    writer.setString("\(peerId.toInt64())", forType: casmosChatPeerPasteboardType)
    let dragItem = NSDraggingItem(pasteboardWriter: writer)
    let image: NSImage
    if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
        view.cacheDisplay(in: view.bounds, to: bitmap)
        image = NSImage(size: view.bounds.size)
        image.addRepresentation(bitmap)
    } else {
        image = NSImage(size: view.bounds.size)
    }
    dragItem.setDraggingFrame(view.bounds, contents: image)
    view.beginDraggingSession(with: [dragItem], event: event, source: CasmosChatDragSource.shared)
    return true
}

func casmosChatGroupMenuItems(peerId: PeerId, context: AccountContext) -> [ContextMenuItem] {
    let encoded = peerId.toInt64()
    var items: [ContextMenuItem] = []
    for group in CasmosChatGroups.groups {
        let inGroup = group.peerIds.contains(encoded)
        items.append(ContextMenuItem(group.name, handler: {
            CasmosChatGroups.toggle(peerId: encoded, groupId: group.id)
        }, state: inGroup ? .on : nil))
    }
    if !items.isEmpty {
        items.append(ContextSeparatorItem())
    }
    items.append(ContextMenuItem("New Group…", handler: {
        casmosPromptGroupName(context: context, title: "New Group", initial: "") { name in
            _ = CasmosChatGroups.create(name: name, adding: encoded)
        }
    }))
    return items
}

private enum CasmosGroupTabModel: Equatable {
    case all
    case ungrouped
    case group(CasmosChatGroup)

    var title: String {
        switch self {
        case .all:
            return "All"
        case .ungrouped:
            return "Ungrouped"
        case let .group(group):
            return group.name
        }
    }

    var groupId: String? {
        if case let .group(group) = self {
            return group.id
        }
        return nil
    }
}

private func casmosTabStrokeIcon(size: CGFloat, color: NSColor, draw: (CGContext, CGRect) -> Void) -> CGImage {
    generateImage(NSMakeSize(size, size), contextGenerator: { imageSize, ctx in
        let rect = CGRect(origin: .zero, size: imageSize)
        ctx.clear(rect)
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(1.35)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        draw(ctx, rect.insetBy(dx: 1.5, dy: 1.5))
    })!
}

private func casmosTabGlyph(_ model: CasmosGroupTabModel, color: NSColor) -> CGImage {
    casmosTabStrokeIcon(size: 14, color: color) { ctx, rect in
        switch model {
        case .all:
            let w = rect.width
            let s = w * 0.38
            let g = w * 0.16
            for row in 0..<2 {
                for col in 0..<2 {
                    let cell = CGRect(x: rect.minX + CGFloat(col) * (s + g), y: rect.minY + CGFloat(row) * (s + g), width: s, height: s)
                    ctx.stroke(cell)
                }
            }
        case .ungrouped:
            ctx.strokeEllipse(in: rect)
        case .group:
            let tab = CGRect(x: rect.minX + 1, y: rect.minY, width: rect.width * 0.42, height: 3.5)
            let body = CGRect(x: rect.minX, y: rect.minY + 3, width: rect.width, height: rect.height - 3)
            ctx.addPath(CGPath(roundedRect: tab, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
            ctx.addPath(CGPath(roundedRect: body, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil))
            ctx.strokePath()
        }
    }
}

private func casmosTabCloseImage(color: NSColor) -> CGImage {
    casmosTabStrokeIcon(size: 10, color: color) { ctx, rect in
        ctx.move(to: CGPoint(x: rect.minX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        ctx.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        ctx.strokePath()
    }
}

private func casmosTabPlusImage(color: NSColor) -> CGImage {
    casmosTabStrokeIcon(size: 13, color: color) { ctx, rect in
        ctx.move(to: CGPoint(x: rect.midX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        ctx.move(to: CGPoint(x: rect.minX, y: rect.midY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        ctx.strokePath()
    }
}

private func casmosChromeTabPath(in rect: CGRect, ear: CGFloat, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let bottom: CGFloat = 0
    let top = max(radius + 1, rect.height - 3)
    let left = rect.minX + ear
    let right = rect.maxX - ear
    let r = min(radius, min(max(2, (right - left) / 2), max(2, top - bottom)))
    path.move(to: CGPoint(x: rect.minX, y: bottom))
    path.addCurve(to: CGPoint(x: left, y: ear), control1: CGPoint(x: rect.minX + ear * 0.55, y: bottom), control2: CGPoint(x: left, y: bottom))
    path.addLine(to: CGPoint(x: left, y: top - r))
    path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: left + r, y: top), radius: r)
    path.addLine(to: CGPoint(x: right - r, y: top))
    path.addArc(tangent1End: CGPoint(x: right, y: top), tangent2End: CGPoint(x: right, y: top - r), radius: r)
    path.addLine(to: CGPoint(x: right, y: ear))
    path.addCurve(to: CGPoint(x: rect.maxX, y: bottom), control1: CGPoint(x: right, y: bottom), control2: CGPoint(x: rect.maxX - ear * 0.55, y: bottom))
    path.closeSubpath()
    return path
}

private final class CasmosChromeTabView: Control {
    static let overlap: CGFloat = 6
    static let ear: CGFloat = 6

    private let shapeLayer = CAShapeLayer()
    private let iconView = ImageView()
    private let titleView = TextView()
    private let closeButton = ImageButton()
    private let separator = View()
    private(set) var model: CasmosGroupTabModel = .all
    private var isActive: Bool = false
    private var showsSeparator: Bool = true
    private var isDropTarget: Bool = false
    private var titleWidth: CGFloat = 32
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?
    var onRename: (() -> Void)?
    var onDropPeer: ((Int64) -> Bool)?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([casmosChatPeerPasteboardType])
        set(background: .clear, for: .Normal)
        set(background: .clear, for: .Hover)
        set(background: .clear, for: .Highlight)
        layer?.masksToBounds = false
        layer?.addSublayer(shapeLayer)
        shapeLayer.zPosition = -1
        shapeLayer.isGeometryFlipped = false
        shapeLayer.masksToBounds = false
        addSubview(iconView)
        addSubview(titleView)
        addSubview(closeButton)
        addSubview(separator)
        iconView.isEventLess = true
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        closeButton.autohighlight = false
        closeButton.scaleOnClick = true
        set(handler: { [weak self] _ in
            self?.onSelect?()
        }, for: .Click)
        closeButton.set(handler: { [weak self] _ in
            self?.onClose?()
        }, for: .Click)
        contextMenu = { [weak self] in
            guard let self, self.model.groupId != nil else {
                return nil
            }
            let menu = ContextMenu()
            menu.addItem(ContextMenuItem("Rename…", handler: { [weak self] in
                self?.onRename?()
            }))
            menu.addItem(ContextMenuItem("Delete Group", handler: { [weak self] in
                self?.onClose?()
            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            return menu
        }
        setAccessibilityRole(.radioButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(model: CasmosGroupTabModel, active: Bool, showsDivider: Bool) {
        self.model = model
        self.isActive = active
        self.showsSeparator = showsDivider && !active
        let color = active ? theme.colors.text : theme.colors.grayText
        iconView.image = casmosTabGlyph(model, color: color)
        iconView.setFrameSize(NSMakeSize(14, 14))
        let layout = TextViewLayout(.initialize(string: model.title, color: color, font: .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        layout.measure(width: .greatestFiniteMagnitude)
        titleWidth = layout.layoutSize.width
        titleView.update(layout)
        toolTip = model.title
        let canClose = model.groupId != nil
        closeButton.isHidden = !canClose
        if canClose {
            closeButton.set(image: casmosTabCloseImage(color: color), for: .Normal)
            closeButton.sizeToFit(NSZeroSize, NSMakeSize(18, 18), thatFit: true)
            closeButton.setAccessibilityLabel("Close \(model.title)")
        }
        separator.backgroundColor = theme.colors.grayText.withAlphaComponent(0.35)
        separator.isHidden = !showsSeparator
        setAccessibilityLabel(model.title)
        setAccessibilityValue(active ? "selected" : nil)
        switch model {
        case .all:
            setAccessibilityHelp(nil)
        case .ungrouped:
            setAccessibilityHelp("Drop a chat here to remove it from groups")
        case .group:
            setAccessibilityHelp("Drop a chat here to add it to \(model.title)")
        }
        needsLayout = true
        needsDisplay = true
    }

    private var acceptsDrop: Bool {
        switch model {
        case .all:
            return false
        case .ungrouped, .group:
            return true
        }
    }

    private func setDropTarget(_ value: Bool) {
        guard isDropTarget != value else {
            return
        }
        isDropTarget = value
        needsLayout = true
        needsDisplay = true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptsDrop, casmosPeerId(from: sender) != nil else {
            setDropTarget(false)
            return []
        }
        setDropTarget(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDropTarget(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setDropTarget(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setDropTarget(false)
        guard acceptsDrop, let peerId = casmosPeerId(from: sender) else {
            return false
        }
        return onDropPeer?(peerId) ?? false
    }

    func fittedWidth() -> CGFloat {
        let closeW: CGFloat = closeButton.isHidden ? 0 : 18
        return Self.ear + 6 + 14 + 6 + ceil(titleWidth) + closeW + 6 + Self.ear
    }

    override func layout() {
        super.layout()
        let ear = Self.ear
        let inset: CGFloat = 6
        let closeW: CGFloat = closeButton.isHidden ? 0 : 18
        iconView.setFrameOrigin(NSMakePoint(ear + inset, floorToScreenPixels(backingScaleFactor, (frame.height - 14) / 2)))
        let titleX = iconView.frame.maxX + 6
        let titleMax = max(20, frame.width - ear - inset - closeW - titleX)
        titleView.textLayout?.measure(width: titleMax)
        titleView.update(titleView.textLayout)
        titleView.setFrameSize(titleView.textLayout?.layoutSize ?? .zero)
        titleView.setFrameOrigin(NSMakePoint(titleX, floorToScreenPixels(backingScaleFactor, (frame.height - titleView.frame.height) / 2)))
        if !closeButton.isHidden {
            closeButton.centerY(x: frame.width - ear - inset - closeButton.frame.width)
        }
        separator.frame = NSMakeRect(ear, floorToScreenPixels(backingScaleFactor, (frame.height - 14) / 2), .borderSize, 14)
        shapeLayer.frame = bounds
        shapeLayer.path = casmosChromeTabPath(in: bounds, ear: ear, radius: 8)
        if isDropTarget {
            shapeLayer.fillColor = theme.colors.accent.withAlphaComponent(0.28).cgColor
        } else if isActive {
            shapeLayer.fillColor = theme.colors.background.cgColor
        } else {
            shapeLayer.fillColor = NSColor.clear.cgColor
        }
    }
}

private final class CasmosGroupsPlusButton: ImageButton {
    var onDropPeer: ((Int64) -> Bool)?
    private var isDropTarget = false

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([casmosChatPeerPasteboardType])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setDropTarget(_ value: Bool) {
        isDropTarget = value
        layer?.backgroundColor = value ? theme.colors.grayText.withAlphaComponent(0.22).cgColor : NSColor.clear.cgColor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard casmosPeerId(from: sender) != nil else {
            setDropTarget(false)
            return []
        }
        setDropTarget(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setDropTarget(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setDropTarget(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setDropTarget(false)
        guard let peerId = casmosPeerId(from: sender) else {
            return false
        }
        return onDropPeer?(peerId) ?? false
    }
}

final class CasmosGroupsBar: View {
    static let height: CGFloat = CasmosChatGroups.barHeight

    private let scrollView = HorizontalScrollView(frame: .zero)
    private let documentView = View()
    private let plusButton = CasmosGroupsPlusButton(frame: NSMakeRect(0, 0, 28, 28))
    private let fadeView = View()
    private let fadeLayer = CAGradientLayer()
    private var tabs: [CasmosChromeTabView] = []
    private weak var context: AccountContext?
    private var observer: NSObjectProtocol?
    private var pendingScrollToSelected = false
    private var reloadKey = ""

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        documentView.backgroundColor = .clear
        documentView.layer?.masksToBounds = false
        scrollView.documentView = documentView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        addSubview(scrollView)
        plusButton.autohighlight = false
        plusButton.scaleOnClick = true
        plusButton.setAccessibilityLabel("New group")
        plusButton.set(handler: { [weak self] _ in
            self?.createGroup()
        }, for: .Click)
        plusButton.onDropPeer = { [weak self] peerId in
            self?.createGroup(adding: peerId)
            return true
        }
        plusButton.setAccessibilityHelp("Drop a chat here to create a group")
        addSubview(plusButton)
        fadeView.userInteractionEnabled = false
        fadeView.isEventLess = true
        fadeView.layer?.addSublayer(fadeLayer)
        addSubview(fadeView)
        setAccessibilityElement(true)
        setAccessibilityRole(.tabGroup)
        setAccessibilityLabel("Chat groups")
        observer = NotificationCenter.default.addObserver(forName: CasmosPreferences.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func attach(context: AccountContext) {
        self.context = context
        reload()
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        reload()
    }

    override func layout() {
        super.layout()
        layoutTabs()
    }

    func reload() {
        var models: [CasmosGroupTabModel] = [.all]
        models.append(contentsOf: CasmosChatGroups.groups.map { .group($0) })
        if !CasmosChatGroups.groups.isEmpty {
            models.append(.ungrouped)
        }
        let selected = CasmosChatGroups.selected
        let key = selected.storageValue + "|" + CasmosChatGroups.groups.map { "\($0.id)=\($0.name)" }.joined(separator: ",") + "|\(theme.colors.background.hashValue)"
        if key == reloadKey, tabs.count == models.count {
            return
        }
        reloadKey = key
        backgroundColor = theme.colors.background.darker(amount: 0.14)
        plusButton.set(image: casmosTabPlusImage(color: theme.colors.grayText), for: .Normal)
        plusButton.set(background: .clear, for: .Normal)
        plusButton.set(background: theme.colors.grayText.withAlphaComponent(0.14), for: .Hover)
        plusButton.layer?.cornerRadius = 6
        plusButton.sizeToFit(NSZeroSize, NSMakeSize(28, 28), thatFit: true)

        while tabs.count > models.count {
            tabs.removeLast().removeFromSuperview()
        }
        while tabs.count < models.count {
            let tab = CasmosChromeTabView(frame: .zero)
            documentView.addSubview(tab)
            tabs.append(tab)
        }

        for (index, model) in models.enumerated() {
            let tab = tabs[index]
            let active: Bool
            switch (selected, model) {
            case (.all, .all), (.ungrouped, .ungrouped):
                active = true
            case let (.group(id), .group(group)):
                active = id == group.id
            default:
                active = false
            }
            let nextIsActive: Bool
            if index + 1 < models.count {
                let next = models[index + 1]
                switch (selected, next) {
                case (.all, .all), (.ungrouped, .ungrouped):
                    nextIsActive = true
                case let (.group(id), .group(group)):
                    nextIsActive = id == group.id
                default:
                    nextIsActive = false
                }
            } else {
                nextIsActive = false
            }
            tab.update(model: model, active: active, showsDivider: index > 0 && !active && !nextIsActive)
            if active {
                tab.layer?.zPosition = 10
            } else {
                tab.layer?.zPosition = CGFloat(index)
            }
            tab.onSelect = { [weak self] in
                self?.select(model)
            }
            tab.onClose = { [weak self] in
                self?.delete(model)
            }
            tab.onRename = { [weak self] in
                self?.rename(model)
            }
            tab.onDropPeer = { [weak self] peerId in
                self?.drop(peerId, onto: model) ?? false
            }
        }
        pendingScrollToSelected = true
        layoutTabs()
    }

    private func layoutTabs() {
        let overlap = CasmosChromeTabView.overlap
        let plusSize = plusButton.frame.size == .zero ? NSMakeSize(28, 28) : plusButton.frame.size
        var x: CGFloat = 4
        for tab in tabs {
            let width = tab.fittedWidth()
            tab.frame = NSMakeRect(x, 0, width, frame.height)
            x += width - overlap
        }
        let contentWidth = max(x + overlap + 6, 1)
        documentView.frame = NSMakeRect(0, 0, contentWidth, frame.height)
        let plusX: CGFloat
        if contentWidth + plusSize.width + 8 > frame.width, frame.width > 40 {
            plusX = max(8, frame.width - plusSize.width - 6)
        } else {
            plusX = contentWidth + 2
        }
        plusButton.frame = NSMakeRect(plusX, floorToScreenPixels(backingScaleFactor, (frame.height - plusSize.height) / 2), plusSize.width, plusSize.height)
        plusButton.layer?.zPosition = 20
        scrollView.frame = NSMakeRect(0, 0, max(0, plusButton.frame.minX - 2), frame.height)
        let overflowing = documentView.frame.width > scrollView.frame.width + 1
        fadeView.isHidden = !overflowing
        fadeView.frame = NSMakeRect(max(0, plusButton.frame.minX - 18), 0, 18, frame.height)
        fadeView.layer?.zPosition = 19
        fadeLayer.frame = fadeView.bounds
        let barColor = theme.colors.background.darker(amount: 0.14)
        fadeLayer.colors = [barColor.withAlphaComponent(0).cgColor, barColor.cgColor]
        fadeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fadeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        if pendingScrollToSelected {
            pendingScrollToSelected = false
            scrollSelectedIntoView()
        }
    }

    private func isSelected(_ model: CasmosGroupTabModel) -> Bool {
        switch (CasmosChatGroups.selected, model) {
        case (.all, .all), (.ungrouped, .ungrouped):
            return true
        case let (.group(id), .group(group)):
            return id == group.id
        default:
            return false
        }
    }

    private func scrollSelectedIntoView() {
        guard scrollView.frame.width > 1 else {
            return
        }
        guard let tab = tabs.first(where: { isSelected($0.model) }) else {
            return
        }
        let visible = scrollView.contentView.bounds
        var origin = visible.origin
        if tab.frame.minX < visible.minX + 4 {
            origin.x = max(0, tab.frame.minX - 4)
        } else if tab.frame.maxX > visible.maxX - 4 {
            origin.x = tab.frame.maxX - visible.width + 4
        } else {
            return
        }
        let maxX = max(0, documentView.frame.width - visible.width)
        origin.x = min(max(0, origin.x), maxX)
        scrollView.clipView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.clipView)
    }

    private func select(_ model: CasmosGroupTabModel) {
        switch model {
        case .all:
            CasmosChatGroups.selected = .all
        case .ungrouped:
            CasmosChatGroups.selected = .ungrouped
        case let .group(group):
            CasmosChatGroups.selected = .group(group.id)
        }
    }

    private func drop(_ peerId: Int64, onto model: CasmosGroupTabModel) -> Bool {
        switch model {
        case .all:
            return false
        case .ungrouped:
            CasmosChatGroups.removeFromAllGroups(peerId)
            return true
        case let .group(group):
            CasmosChatGroups.add(peerId: peerId, to: group.id)
            return true
        }
    }

    private func createGroup(adding peerId: Int64? = nil) {
        guard let context else {
            return
        }
        casmosPromptGroupName(context: context, title: "New Group", initial: "") { name in
            _ = CasmosChatGroups.create(name: name, adding: peerId)
        }
    }

    private func rename(_ model: CasmosGroupTabModel) {
        guard let context, case let .group(group) = model else {
            return
        }
        casmosPromptGroupName(context: context, title: "Rename Group", initial: group.name) { name in
            CasmosChatGroups.rename(id: group.id, to: name)
        }
    }

    private func delete(_ model: CasmosGroupTabModel) {
        guard let context, case let .group(group) = model else {
            return
        }
        verifyAlert_button(for: context.window, information: "Delete \(group.name)? Chats stay in All.", ok: "Delete", successHandler: { _ in
            CasmosChatGroups.delete(id: group.id)
        })
    }
}
