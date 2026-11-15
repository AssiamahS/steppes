import Foundation
import Security

/// One calendar day's step total.
struct DaySteps: Codable, Hashable, Identifiable {
    var day: Date      // start of the day, local calendar
    var steps: Int
    var id: Date { day }
}

/// The last 7 days (oldest first, today last) plus the goal. This is what the
/// app hands to the home screen / lock screen widgets.
struct WeekSnapshot: Codable, Hashable {
    static let length = 7

    var days: [DaySteps]
    var goal: Int
    var updatedAt: Date

    var today: Int { days.last?.steps ?? 0 }
    var total: Int { days.reduce(0) { $0 + $1.steps } }
    var best: Int { days.map(\.steps).max() ?? 0 }
    var progress: Double { goal > 0 ? min(Double(today) / Double(goal), 1) : 0 }
    var percent: Int { goal > 0 ? Int((Double(today) / Double(goal) * 100).rounded()) : 0 }
    var goalReached: Bool { goal > 0 && today >= goal }

    /// Mean over the days that have any steps, so an install-day week of
    /// zeros doesn't drag the number down to nothing.
    var average: Int {
        let active = days.filter { $0.steps > 0 }
        return active.isEmpty ? 0 : active.reduce(0) { $0 + $1.steps } / active.count
    }

    /// Builds the 7-day window ending on `now`'s day. `counts` is keyed by
    /// start-of-day; days with no entry become 0.
    static func build(counts: [Date: Int], goal: Int,
                      now: Date = .now, calendar: Calendar = .current) -> WeekSnapshot {
        let end = calendar.startOfDay(for: now)
        let days = (0..<length).reversed().compactMap { back -> DaySteps? in
            guard let day = calendar.date(byAdding: .day, value: -back, to: end) else { return nil }
            return DaySteps(day: day, steps: max(counts[day] ?? 0, 0))
        }
        return WeekSnapshot(days: days, goal: goal, updatedAt: now)
    }

    /// Same data re-windowed to end on `now`'s day. The widget renders stored
    /// data without the app running, so after midnight yesterday's count must
    /// slide left and today must start at 0 instead of repeating yesterday.
    func rolled(to now: Date = .now, calendar: Calendar = .current) -> WeekSnapshot {
        if let last = days.last, calendar.isDate(last.day, inSameDayAs: now), days.count == Self.length {
            return self
        }
        let counts = Dictionary(days.map { ($0.day, $0.steps) }, uniquingKeysWith: max)
        var out = Self.build(counts: counts, goal: goal, now: now, calendar: calendar)
        out.updatedAt = updatedAt
        return out
    }

    static func empty(goal: Int = 10_000, now: Date = .now) -> WeekSnapshot {
        build(counts: [:], goal: goal, now: now)
    }
}

/// App ↔ widget hand-off without an App Group: a keychain item in a
/// team-prefixed access group. Every provisioning profile already allows
/// `TEAMID.*`, so nothing has to be registered in the developer portal
/// (App Groups can't be created by the CI's API-key session).
enum SharedStore {
    static let accessGroup = "QGMAWHX827.com.assiamah.steppes"
    static let service = "com.assiamah.steppes.week"
    static let account = "snapshot"

    static func save(_ snap: WeekSnapshot) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        if !write(data, group: accessGroup) { _ = write(data, group: nil) }
    }

    static func load() -> WeekSnapshot? {
        guard let data = read(group: accessGroup) ?? read(group: nil) else { return nil }
        return try? JSONDecoder().decode(WeekSnapshot.self, from: data)
    }

    private static func base(_ group: String?) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    private static func write(_ data: Data, group: String?) -> Bool {
        var q = base(group)
        // AfterFirstUnlock so the lock screen widget can still read it while locked.
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
        if status == errSecSuccess { return true }
        if status != errSecItemNotFound { return false }
        attrs.forEach { q[$0.key] = $0.value }
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    private static func read(group: String?) -> Data? {
        var q = base(group)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
}
