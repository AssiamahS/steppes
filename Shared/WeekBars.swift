import SwiftUI

/// Seven-day bar chart shared by the app and the widgets. Plain shapes rather
/// than Swift Charts so it renders identically in every widget rendering mode.
struct WeekBars: View {
    enum Labels { case none, narrow, short }

    var days: [DaySteps]
    var goal: Int
    var labels: Labels = .short
    var spacing: CGFloat = 8
    var selected: Date? = nil
    var onSelect: ((Date) -> Void)? = nil

    /// Top of the scale: the goal, or the best day if it beat the goal.
    private var ceiling: Double {
        Double(max(goal, days.map(\.steps).max() ?? 0, 1))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    bar(for: day)
                    if labels != .none {
                        Text(day.day, format: .dateTime.weekday(labels == .narrow ? .narrow : .abbreviated))
                            .font(labels == .narrow ? .system(size: 9, weight: .semibold) : .caption2)
                            .foregroundStyle(isToday(day) ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onSelect?(day.day) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day.day, format: .dateTime.weekday(.wide)))
                .accessibilityValue(Text("\(day.steps) steps"))
            }
        }
    }

    private func bar(for day: DaySteps) -> some View {
        GeometryReader { geo in
            let fraction = min(Double(day.steps) / ceiling, 1)
            let height = max(geo.size.height * fraction, day.steps > 0 ? 3 : 1.5)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: min(geo.size.width / 3, 5), style: .continuous)
                    .fill(fill(for: day))
                    .frame(height: height)
                    .widgetAccentable()
            }
        }
    }

    private func isToday(_ day: DaySteps) -> Bool { day.day == days.last?.day }

    private func fill(for day: DaySteps) -> Color {
        if day.steps == 0 { return .white.opacity(0.15) }
        if let selected { return day.day == selected ? .green : .green.opacity(0.35) }
        return isToday(day) || (goal > 0 && day.steps >= goal) ? .green : .green.opacity(0.5)
    }
}
