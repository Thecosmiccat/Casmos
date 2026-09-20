import Foundation
import CoreGraphics

/// Local chat groups. Stored on this Mac only — not synced as Telegram folders.
public struct CasmosChatGroup: Codable, Equatable {
    public var id: String
    public var name: String
    public var peerIds: [Int64]

    public init(id: String = UUID().uuidString, name: String, peerIds: [Int64] = []) {
        self.id = id
        self.name = name
        self.peerIds = peerIds
    }
}

public enum CasmosChatGroupTab: Equatable {
    case all
    case ungrouped
    case group(String)

    public var storageValue: String {
        switch self {
        case .all:
            return "all"
        case .ungrouped:
            return "ungrouped"
        case let .group(id):
            return id
        }
    }

    public static func from(storage: String) -> CasmosChatGroupTab {
        switch storage {
        case "", "all":
            return .all
        case "ungrouped":
            return .ungrouped
        default:
            return .group(storage)
        }
    }
}

public enum CasmosChatGroups {
    public static let barHeight: CGFloat = 40
    public static let nameLimit = 24

    private static let groupsKey = "casmos.pref.chat.groups"
    private static let selectedKey = "casmos.pref.chat.groupsSelected"

    public static var groups: [CasmosChatGroup] {
        get {
            guard let data = UserDefaults.standard.data(forKey: groupsKey),
                  let decoded = try? JSONDecoder().decode([CasmosChatGroup].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            let encoded = (try? JSONEncoder().encode(newValue)) ?? Data()
            UserDefaults.standard.set(encoded, forKey: groupsKey)
            CasmosPreferences.notifyDidChange()
        }
    }

    public static var selected: CasmosChatGroupTab {
        get {
            let stored = CasmosPreferences.string(forKey: selectedKey, default: "all")
            let tab = CasmosChatGroupTab.from(storage: stored)
            if case let .group(id) = tab, groups.contains(where: { $0.id == id }) == false {
                return .all
            }
            return tab
        }
        set {
            CasmosPreferences.set(newValue.storageValue, forKey: selectedKey)
        }
    }

    public static func group(id: String) -> CasmosChatGroup? {
        groups.first(where: { $0.id == id })
    }

    public static func normalizedName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return nil
        }
        if name.count <= nameLimit {
            return name
        }
        return String(name.prefix(nameLimit))
    }

    @discardableResult
    public static func create(name: String, adding peerId: Int64? = nil) -> CasmosChatGroup? {
        guard let name = normalizedName(name) else {
            return nil
        }
        var list = groups
        var created = CasmosChatGroup(name: name)
        if let peerId, !created.peerIds.contains(peerId) {
            created.peerIds.append(peerId)
        }
        list.append(created)
        groups = list
        selected = .group(created.id)
        return created
    }

    public static func rename(id: String, to raw: String) {
        guard let name = normalizedName(raw) else {
            return
        }
        var list = groups
        guard let index = list.firstIndex(where: { $0.id == id }) else {
            return
        }
        list[index].name = name
        groups = list
    }

    public static func delete(id: String) {
        var list = groups
        list.removeAll(where: { $0.id == id })
        if case let .group(selectedId) = selected, selectedId == id {
            UserDefaults.standard.set("all", forKey: selectedKey)
        }
        groups = list
    }

    public static func contains(_ peerId: Int64, groupId: String) -> Bool {
        group(id: groupId)?.peerIds.contains(peerId) == true
    }

    public static func toggle(peerId: Int64, groupId: String) {
        var list = groups
        guard let index = list.firstIndex(where: { $0.id == groupId }) else {
            return
        }
        if let existing = list[index].peerIds.firstIndex(of: peerId) {
            list[index].peerIds.remove(at: existing)
        } else {
            list[index].peerIds.append(peerId)
        }
        groups = list
    }

    public static func add(peerId: Int64, to groupId: String) {
        var list = groups
        guard let index = list.firstIndex(where: { $0.id == groupId }) else {
            return
        }
        if list[index].peerIds.contains(peerId) {
            return
        }
        list[index].peerIds.append(peerId)
        groups = list
    }

    public static func removeFromAllGroups(_ peerId: Int64) {
        var list = groups
        var changed = false
        for i in list.indices {
            let before = list[i].peerIds.count
            list[i].peerIds.removeAll { $0 == peerId }
            if list[i].peerIds.count != before {
                changed = true
            }
        }
        if changed {
            groups = list
        }
    }

    public static func groupedPeerIds() -> Set<Int64> {
        Set(groups.flatMap { $0.peerIds })
    }

    public static func isPeerVisible(_ peerId: Int64) -> Bool {
        switch selected {
        case .all:
            return true
        case .ungrouped:
            return !groupedPeerIds().contains(peerId)
        case let .group(id):
            return contains(peerId, groupId: id)
        }
    }

    public static var emptyCopy: String {
        switch selected {
        case .all:
            return ""
        case .ungrouped:
            return "Chats that are not in a group show up here. Drag a chat onto a group tab, or right-click to add it."
        case let .group(id):
            let name = group(id: id)?.name ?? "this group"
            return "No chats in \(name) yet. Drag a chat onto this tab, or right-click and choose Add to Group."
        }
    }
}
