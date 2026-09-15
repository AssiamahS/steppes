import WidgetKit
import SwiftUI
import ActivityKit

@main
struct SteppesWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepsLiveActivity()
    }
}

struct StepsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StepsActivityAttributes.self) { context in
            LockScreenStepsView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WalkRing(progress: context.state.progress, size: 48, lineWidth: 6, iconSize: 18)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(StepFormat.distance(context.state.distanceMeters))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(context.state.floors == 1 ? "1 floor" : "\(context.state.floors) floors")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(context.state.steps, format: .number)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(context.state.goalReached ? .green : .white)
                            .contentTransition(.numericText())
                        Text("of \(context.state.goal.formatted()) steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ProgressView(value: context.state.progress)
                            .tint(.green)
                        HStack {
                            Text(context.state.goalReached ? "Goal reached" : "\(context.state.percent)% of goal")
                            Spacer()
                            Text("Updated \(context.state.updatedAt, style: .relative) ago")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                WalkRing(progress: context.state.progress, size: 20, lineWidth: 3, iconSize: 9)
                    .padding(.leading, 2)
            } compactTrailing: {
                Text(context.state.steps, format: .number)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(context.state.goalReached ? .green : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .padding(.trailing, 2)
            } minimal: {
                WalkRing(progress: context.state.progress, size: 20, lineWidth: 3, iconSize: 9)
            }
            .keylineTint(.green)
        }
    }
}

struct LockScreenStepsView: View {
    let state: StepsActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            WalkRing(progress: state.progress, size: 56, lineWidth: 7, iconSize: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.steps, format: .number)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.goalReached ? .green : .white)
                    .contentTransition(.numericText())
                Text("of \(state.goal.formatted()) steps · \(state.percent)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(StepFormat.distance(state.distanceMeters))
                    .font(.headline.monospacedDigit())
                Text(state.floors == 1 ? "1 floor" : "\(state.floors) floors")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

