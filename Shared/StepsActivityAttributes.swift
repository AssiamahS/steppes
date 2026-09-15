import Foundation
import ActivityKit

/// Payload shared between the app (which requests/updates the Live Activity)
/// and the widget extension (which renders it in the Dynamic Island).
struct StepsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var steps: Int
        var goal: Int
        var distanceMeters: Double
        var floors: Int
        var updatedAt: Date

        var progress: Double { goal > 0 ? min(Double(steps) / Double(goal), 1) : 0 }
        var percent: Int { goal > 0 ? Int((Double(steps) / Double(goal) * 100).rounded()) : 0 }
        var goalReached: Bool { goal > 0 && steps >= goal }
    }

    /// Start of the day this activity is counting (informational, for midnight rollover).
    var startOfDay: Date
}

enum StepFormat {
    static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(1))))
    }
}
