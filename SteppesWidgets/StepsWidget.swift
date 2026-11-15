import WidgetKit
import SwiftUI

struct StepsEntry: TimelineEntry {
    let date: Date
    let week: WeekSnapshot
    /// False until the app has written a snapshot at least once.
    let hasData: Bool
}

/// Reads the week the app last wrote to the shared keychain item. The widget
/// never queries Motion/Health itself — the app refreshes the snapshot on
/// every foreground, Health background delivery and background refresh, then
/// asks WidgetKit to reload.
struct StepsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsEntry {
        StepsEntry(date: .now, week: Self.sample(), hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> Void) {
        let now = Date.now
        var entries = [entry(at: now)]
        // Roll to a fresh day at midnight even if the app hasn't run.
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        entries.append(entry(at: midnight))
        let next = min(now.addingTimeInterval(30 * 60), midnight.addingTimeInterval(60))
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    private func entry(at date: Date) -> StepsEntry {
        guard let stored = SharedStore.load() else {
            return StepsEntry(date: date, week: .empty(now: date), hasData: false)
        }
        return StepsEntry(date: date, week: stored.rolled(to: date), hasData: true)
    }

    static func sample() -> WeekSnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let values = [2_750, 3_840, 3_900, 4_120, 6_030, 6_556, 4_310]
        var counts: [Date: Int] = [:]
        for (i, v) in values.enumerated() {
            if let d = cal.date(byAdding: .day, value: i - (values.count - 1), to: today) { counts[d] = v }
        }
        return .build(counts: counts, goal: 10_000)
    }
}

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StepsWidget", provider: StepsProvider()) { entry in
            StepsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.04, green: 0.13, blue: 0.08), .black],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Steps")
        .description("Today's steps and your last 7 days.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StepsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StepsEntry

    private var week: WeekSnapshot { entry.week }

    var body: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    // MARK: - Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            count(size: 34)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 6)
            WeekBars(days: week.days, goal: week.goal, labels: .none, spacing: 4)
                .frame(height: 34)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 4)
                count(size: 36)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                ProgressView(value: week.progress)
                    .tint(.green)
                Text("Avg \(week.average.formatted()) a day")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            WeekBars(days: week.days, goal: week.goal, labels: .narrow, spacing: 6)
                .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: week.goalReached ? "checkmark.seal.fill" : "figure.walk")
            Text("Steps")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.green)
        .widgetAccentable()
    }

    private func count(size: CGFloat) -> some View {
        Text(week.today, format: .number)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }

    private var subtitle: String {
        if !entry.hasData { return "Open Steppes to start" }
        return week.goalReached ? "Goal reached" : "of \(week.goal.formatted()) · \(week.percent)%"
    }

    // MARK: - Lock screen

    private var circular: some View {
        Gauge(value: week.progress) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(week.today, format: .number.notation(.compactName))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Label("Steps", systemImage: "figure.walk")
                    .font(.caption2.weight(.semibold))
                    .widgetAccentable()
                Text(week.today, format: .number)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(week.percent)% of goal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            WeekBars(days: week.days, goal: week.goal, labels: .none, spacing: 3)
        }
    }

    private var inline: some View {
        Label("\(week.today.formatted()) steps", systemImage: "figure.walk")
    }
}
