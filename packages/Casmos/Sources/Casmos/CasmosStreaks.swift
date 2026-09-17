import Foundation

/// Local TikTok-style 1:1 streaks. A calendar day counts when this account
/// sent and received at least one message that local day. Not sent to Telegram.
public enum CasmosStreaks {
    private static let defaultsKey = "casmos.pref.chat.streaks"
    private static let lock = NSLock()
    private static var states: [String: State] = load()
    private static var saveWork: DispatchWorkItem?

    private struct State: Codable {
        var count: Int = 0
        var lastQualifiedDay: Int = 0
        var lastInDay: Int = 0
        var lastOutDay: Int = 0
    }

    private static var lastNoted: [Int64: (incoming: Bool, timestamp: Int32)] = [:]
    private static var cachedToday: (unix: Int32, day: Int)?

    /// `peerId` is `PeerId.toInt64()`. Incoming vs outgoing from the latest list message.
    public static func note(peerId: Int64, incoming: Bool, timestamp: Int32) {
        lock.lock()
        if let previous = lastNoted[peerId], previous.incoming == incoming, previous.timestamp == timestamp {
            lock.unlock()
            return
        }
        lastNoted[peerId] = (incoming, timestamp)
        let today = cachedDayNumber()
        let messageDay = dayNumber(timestamp)
        let key = String(peerId)
        var state = states[key] ?? State()
        let before = state
        apply(to: &state, incoming: incoming, messageDay: messageDay, today: today)
        states[key] = state
        let changed = before.count != state.count || before.lastQualifiedDay != state.lastQualifiedDay || before.lastInDay != state.lastInDay || before.lastOutDay != state.lastOutDay
        lock.unlock()
        if changed {
            scheduleSave()
        }
    }

    public static func flamePointSize(_ count: Int) -> Int {
        switch count {
        case 1..<7:
            return 22
        case 7..<30:
            return 24
        case 30..<100:
            return 26
        default:
            return 28
        }
    }

    /// Solid fill. More days → hotter: yellow, orange, red, purple, blue.
    public static func flameColor(_ count: Int) -> UInt32 {
        switch count {
        case 1..<7:
            return 0xFFD54F
        case 7..<30:
            return 0xFF8C00
        case 30..<100:
            return 0xE53935
        case 100..<365:
            return 0x8E24AA
        default:
            return 0x1E88E5
        }
    }

    public static func displayCount(peerId: Int64) -> Int {
        lock.lock()
        let today = cachedDayNumber()
        let state = states[String(peerId)]
        lock.unlock()
        guard let state else {
            return 0
        }
        if state.lastQualifiedDay == today || state.lastQualifiedDay == today - 1 {
            return state.count
        }
        return 0
    }

    private static func apply(to state: inout State, incoming: Bool, messageDay: Int, today: Int) {
        guard messageDay >= today - 1 else {
            return
        }
        if incoming {
            state.lastInDay = max(state.lastInDay, messageDay)
        } else {
            state.lastOutDay = max(state.lastOutDay, messageDay)
        }
        let day = messageDay
        guard state.lastInDay == day, state.lastOutDay == day else {
            return
        }
        if state.lastQualifiedDay == day {
            return
        }
        if state.lastQualifiedDay == day - 1 {
            state.count += 1
        } else {
            state.count = 1
        }
        state.lastQualifiedDay = day
    }

    private static func cachedDayNumber() -> Int {
        let unix = Int32(Date().timeIntervalSince1970)
        if let cached = cachedToday, unix - cached.unix < 30 {
            return cached.day
        }
        let day = dayNumber(unix)
        cachedToday = (unix, day)
        return day
    }

    private static func dayNumber(_ unix: Int32) -> Int {
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        return Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    private static func load() -> [String: State] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: State].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem {
            lock.lock()
            let snapshot = states
            lock.unlock()
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}
