import AppKit
import TGUIKit
import Casmos
import Dock
import ApiCredentials

enum CasmosDockIcon: String, CaseIterable {
    case void
    case light
    case nebula
    case gold
    case mint
    case dusk

    var title: String {
        switch self {
        case .void: return "Void"
        case .light: return "Light"
        case .nebula: return "Nebula"
        case .gold: return "Gold"
        case .mint: return "Mint"
        case .dusk: return "Dusk"
        }
    }
}

enum CasmosDockIcons {
    static func restoreFromPrefs() {
        apply(current)
    }

    static var current: CasmosDockIcon {
        CasmosDockIcon(rawValue: CasmosPreferences.string(forKey: CasmosPrefKey.Appearance.dockIcon, default: CasmosDockIcon.void.rawValue)) ?? .void
    }

    static func apply(_ icon: CasmosDockIcon) {
        CasmosPreferences.set(icon.rawValue, forKey: CasmosPrefKey.Appearance.dockIcon)
        if icon == .void {
            _ = Dock.setCustomAppIcon(path: nil, silence: true)
            NSApplication.shared.applicationIconImage = nil
        } else {
            let image = render(icon, size: 1024)
            NSApplication.shared.applicationIconImage = image
            if let path = writePNG(image, name: icon.rawValue) {
                _ = Dock.setCustomAppIcon(path: path, silence: true)
            }
        }
    }

    static func render(_ icon: CasmosDockIcon, size: CGFloat) -> NSImage {
        let canvas = NSSize(width: size, height: size)
        let image = NSImage(size: canvas)
        image.lockFocus()
        fillBackground(icon, in: NSRect(origin: .zero, size: canvas))
        if icon == .nebula || icon == .dusk {
            drawStars(in: NSRect(origin: .zero, size: canvas), count: icon == .nebula ? 48 : 28)
        }
        let mark = NSImage(named: "CasmosLoginMark") ?? NSImage(named: "NSApplicationIcon")
        let inset = size * 0.14
        let markRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        if icon == .light, let mark {
            mark.draw(in: markRect, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor.white.withAlphaComponent(0.72).setFill()
            markRect.fill(using: .sourceAtop)
            NSColor.black.withAlphaComponent(0.85).setFill()
            markRect.fill(using: .destinationOver)
        } else {
            mark?.draw(in: markRect, from: .zero, operation: .sourceOver, fraction: 1)
            if icon == .gold {
                NSColor(calibratedRed: 1, green: 0.78, blue: 0.28, alpha: 0.35).setFill()
                markRect.fill(using: .sourceAtop)
            }
        }
        image.unlockFocus()
        return image
    }

    private static func fillBackground(_ icon: CasmosDockIcon, in rect: NSRect) {
        let color: NSColor
        switch icon {
        case .void: color = NSColor.black
        case .light: color = NSColor(calibratedWhite: 0.92, alpha: 1)
        case .nebula: color = NSColor(calibratedRed: 0.12, green: 0.05, blue: 0.22, alpha: 1)
        case .gold: color = NSColor(calibratedRed: 0.08, green: 0.06, blue: 0.02, alpha: 1)
        case .mint: color = NSColor(calibratedRed: 0.02, green: 0.16, blue: 0.14, alpha: 1)
        case .dusk: color = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.2, alpha: 1)
        }
        color.setFill()
        rect.fill()
    }

    private static func drawStars(in rect: NSRect, count: Int) {
        NSColor.white.setFill()
        var seed: UInt64 = 0xC45A05
        for i in 0..<count {
            seed = seed &* 6364136223846793005 &+ UInt64(i)
            let x = CGFloat(seed % 1000) / 1000 * rect.width
            let y = CGFloat((seed / 1000) % 1000) / 1000 * rect.height
            let r = CGFloat((seed / 1_000_000) % 4) + 0.6
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r, height: r)).fill()
        }
    }

    private static func writePNG(_ image: NSImage, name: String) -> String? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let data = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        let dir = (ApiEnvironment.containerURL ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("casmos-dock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        try? data.write(to: url)
        return url.path
    }
}

final class CasmosDockIconRowItem: GeneralRowItem {
    override func viewClass() -> AnyClass {
        CasmosDockIconRowView.self
    }

    override var height: CGFloat {
        108
    }
}

private final class CasmosDockIconRowView: GeneralRowView {
    private let strip = CasmosDockIconStrip(frame: .zero)

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(strip)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        strip.frame = NSMakeRect(20, 16, frame.width - 40, 76)
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        strip.reload()
    }
}

final class CasmosDockIconStrip: View {
    private var buttons: [Control] = []

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        let selected = CasmosDockIcons.current
        for icon in CasmosDockIcon.allCases {
            let button = Control(frame: NSMakeRect(0, 0, 56, 76))
            button.layer?.cornerRadius = 12
            let imageView = ImageView(frame: NSMakeRect(4, 0, 48, 48))
            imageView.nsImage = CasmosDockIcons.render(icon, size: 96)
            imageView.contentGravity = .resize
            button.addSubview(imageView)
            if icon == selected {
                button.layer?.borderWidth = 2
                button.layer?.borderColor = NSColor.white.withAlphaComponent(0.85).cgColor
            }
            button.set(handler: { [weak self] _ in
                CasmosDockIcons.apply(icon)
                self?.reload()
            }, for: .Click)
            addSubview(button)
            buttons.append(button)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard !buttons.isEmpty else {
            return
        }
        let spacing = max(6, (frame.width - CGFloat(buttons.count) * 56) / CGFloat(buttons.count + 1))
        var x = spacing
        for button in buttons {
            button.setFrameOrigin(NSMakePoint(floor(x), 0))
            x += 56 + spacing
        }
    }
}
