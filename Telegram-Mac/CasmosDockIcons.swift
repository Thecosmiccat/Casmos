import AppKit
import Dock

enum CasmosDockIcons {
    static func restoreFromPrefs() {
        Dock.setCustomAppIcon(path: nil, silence: true)
        NSApplication.shared.applicationIconImage = nil
    }
}
