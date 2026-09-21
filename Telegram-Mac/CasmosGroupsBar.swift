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

private final class CasmosGroupTabView: Control {
    static let pillHeight: CGFloat = 28
    static let cornerRadius: CGFloat = 8

    private let iconView = ImageView()
    private let titleView = TextView()
    private let closeButton = ImageButton()
    private(set) var model: CasmosGroupTabModel = .all
    private var isActive: Bool = false
    private var isDropTarget: Bool = false
    private var titleWidth: CGFloat = 32
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?
    var onRename: (() -> Void)?
    var onDropPeer: ((Int64) -> Bool)?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([casmosChatPeerPasteboardType])
        layer?.cornerRadius = Self.cornerRadius
        addSubview(iconView)
        addSubview(titleView)
        addSubview(closeButton)
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

    func update(model: CasmosGroupTabModel, active: Bool) {
        self.model = model
        self.isActive = active
        let color = active ? theme.colors.text : theme.colors.grayText
        iconView.image = casmosTabGlyph(model, color: color)
        iconView.setFrameSize(NSMakeSize(14, 14))
        let layout = TextViewLayout(.initialize(string: model.title, color: color, font: active ? .medium(.text) : .normal(.text)), maximumNumberOfLines: 1, truncationType: .end)
        layout.measure(width: .greatestFiniteMagnitude)
        titleWidth = layout.layoutSize.width
        titleView.update(layout)
        toolTip = model.title
        let canClose = model.groupId != nil
        closeButton.isHidden = !canClose
        if canClose {
            closeButton.set(image: casmosTabCloseImage(color: color), for: .Normal)
            closeButton.sizeToFit(NSZeroSize, NSMakeSize(16, 16), thatFit: true)
            closeButton.setAccessibilityLabel("Close \(model.title)")
        }
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
        applyFill()
        needsLayout = true
    }

    private func applyFill() {
        let fill: NSColor
        if isDropTarget {
            fill = theme.colors.accent.withAlphaComponent(0.22)
        } else if isActive {
            fill = theme.colors.grayForeground
        } else {
            fill = .clear
        }
        let hover = isActive || isDropTarget ? fill : theme.colors.grayForeground.withAlphaComponent(0.55)
        set(background: fill, for: .Normal)
        set(background: hover, for: .Hover)
        set(background: hover, for: .Highlight)
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
        applyFill()
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
        let closeW: CGFloat = closeButton.isHidden ? 0 : 16
        return 8 + 14 + 5 + ceil(titleWidth) + (closeButton.isHidden ? 0 : 2 + closeW) + 8
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 8
        iconView.setFrameOrigin(NSMakePoint(inset, floorToScreenPixels(backingScaleFactor, (frame.height - 14) / 2)))
        let titleX = iconView.frame.maxX + 5
        let closeW: CGFloat = closeButton.isHidden ? 0 : closeButton.frame.width
        let titleMax = max(20, frame.width - inset - (closeW > 0 ? closeW + 2 : 0) - titleX)
        titleView.textLayout?.measure(width: titleMax)
        titleView.update(titleView.textLayout)
        titleView.setFrameSize(titleView.textLayout?.layoutSize ?? .zero)
        titleView.setFrameOrigin(NSMakePoint(titleX, floorToScreenPixels(backingScaleFactor, (frame.height - titleView.frame.height) / 2)))
        if !closeButton.isHidden {
            closeButton.centerY(x: frame.width - inset - closeButton.frame.width)
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
        layer?.backgroundColor = value ? theme.colors.grayForeground.withAlphaComponent(0.55).cgColor : NSColor.clear.cgColor
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
    private let hairline = View()
    private var tabs: [CasmosGroupTabView] = []
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
        plusButton.layer?.cornerRadius = CasmosGroupTabView.cornerRadius
        addSubview(plusButton)
        hairline.userInteractionEnabled = false
        hairline.isEventLess = true
        addSubview(hairline)
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
        let key = selected.storageValue + "|" + CasmosChatGroups.groups.map { "\($0.id)=\($0.name)" }.joined(separator: ",") + "|\(theme.colors.background.hashValue)|\(theme.colors.grayForeground.hashValue)"
        if key == reloadKey, tabs.count == models.count {
            return
        }
        reloadKey = key
        backgroundColor = theme.colors.background
        hairline.backgroundColor = theme.colors.border
        plusButton.set(image: casmosTabPlusImage(color: theme.colors.grayText), for: .Normal)
        plusButton.set(background: .clear, for: .Normal)
        plusButton.set(background: theme.colors.grayForeground.withAlphaComponent(0.55), for: .Hover)
        plusButton.layer?.cornerRadius = CasmosGroupTabView.cornerRadius
        plusButton.sizeToFit(NSZeroSize, NSMakeSize(28, 28), thatFit: true)

        while tabs.count > models.count {
            tabs.removeLast().removeFromSuperview()
        }
        while tabs.count < models.count {
            let tab = CasmosGroupTabView(frame: .zero)
            documentView.addSubview(tab)
            tabs.append(tab)
        }

        for (i, model) in models.enumerated() {
            let tab = tabs[i]
            let active: Bool
            switch (selected, model) {
            case (.all, .all), (.ungrouped, .ungrouped):
                active = true
            case let (.group(id), .group(group)):
                active = id == group.id
            default:
                active = false
            }
            tab.update(model: model, active: active)
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
        let plusSize = plusButton.frame.size == .zero ? NSMakeSize(28, 28) : plusButton.frame.size
        let pillH = CasmosGroupTabView.pillHeight
        let y = floorToScreenPixels(backingScaleFactor, (frame.height - pillH) / 2)
        var x: CGFloat = 8
        for tab in tabs {
            let width = tab.fittedWidth()
            tab.frame = NSMakeRect(x, y, width, pillH)
            x += width + 4
        }
        let contentWidth = max(x + 4, 1)
        documentView.frame = NSMakeRect(0, 0, contentWidth, frame.height)
        let plusX: CGFloat
        if contentWidth + plusSize.width + 8 > frame.width, frame.width > 40 {
            plusX = max(8, frame.width - plusSize.width - 8)
        } else {
            plusX = contentWidth
        }
        plusButton.frame = NSMakeRect(plusX, floorToScreenPixels(backingScaleFactor, (frame.height - plusSize.height) / 2), plusSize.width, plusSize.height)
        plusButton.layer?.zPosition = 20
        scrollView.frame = NSMakeRect(0, 0, max(0, plusButton.frame.minX - 4), frame.height)
        let overflowing = documentView.frame.width > scrollView.frame.width + 1
        fadeView.isHidden = !overflowing
        fadeView.frame = NSMakeRect(max(0, plusButton.frame.minX - 18), 0, 18, frame.height)
        fadeView.layer?.zPosition = 19
        fadeLayer.frame = fadeView.bounds
        let barColor = theme.colors.background
        fadeLayer.colors = [barColor.withAlphaComponent(0).cgColor, barColor.cgColor]
        fadeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fadeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        hairline.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
        hairline.layer?.zPosition = 21
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
