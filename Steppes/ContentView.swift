import SwiftUI
import UIKit

struct ContentView: View {
    private let store = StepStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ringCard
                    statsRow
                    islandCard
                    goalCard
                    if store.motionDenied { permissionCard }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("Steppes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.green)
        .onChange(of: store.islandOn) { _, _ in
            Task { await store.ensureActivity() }
        }
    }

    // MARK: - Sections

    private var progress: Double {
        store.goal > 0 ? min(Double(store.snapshot.steps) / Double(store.goal), 1) : 0
    }

    private var ringCard: some View {
        VStack(spacing: 12) {
            ZStack {
                StepRing(progress: progress, lineWidth: 24)
                    .frame(width: 240, height: 240)
                    .animation(.easeOut(duration: 0.6), value: progress)
                VStack(spacing: 4) {
                    Text(store.snapshot.steps, format: .number)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: store.snapshot.steps)
                    Text("of \(store.goal.formatted()) steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            HStack(spacing: 6) {
                Image(systemName: progress >= 1 ? "checkmark.seal.fill" : "figure.walk")
                Text(progress >= 1 ? "Goal reached" : "\(Int((progress * 100).rounded()))% of today's goal")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(progress >= 1 ? .green : .secondary)
            Text("Updated \(store.snapshot.updatedAt, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .card()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath",
                     value: StepFormat.distance(store.snapshot.distanceMeters),
                     label: "Distance")
            StatTile(icon: "figure.stairs",
                     value: "\(store.snapshot.floors)",
                     label: store.snapshot.floors == 1 ? "Floor" : "Floors")
            StatTile(icon: "target",
                     value: "\(max(store.goal - store.snapshot.steps, 0).formatted())",
                     label: "To go")
        }
    }

    private var islandCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { store.islandOn }, set: { store.islandOn = $0 })) {
                Label("Show in Dynamic Island", systemImage: "capsule.fill")
                    .font(.headline)
            }
            Text(islandStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .card()
    }

    private var islandStatus: String {
        if !store.islandOn { return "Off. Flip it on to pin today's steps to the top of your screen." }
        if store.activityActive { return "Live. Steps refresh when you open the app, when Health logs new steps, and every ~15 minutes in the background. iOS retires a Live Activity after 8 hours — open Steppes to start it again." }
        return "Starting… if nothing shows up, allow Live Activities for Steppes in Settings."
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily goal", systemImage: "flag.checkered")
                    .font(.headline)
                Spacer()
                Text(store.goal.formatted())
                    .font(.headline.monospacedDigit())
            }
            Slider(value: Binding(get: { Double(store.goal) },
                                  set: { store.goal = Int(($0 / 500).rounded()) * 500 }),
                   in: 1_000...30_000, step: 500)
            HStack {
                ForEach([5_000, 8_000, 10_000, 12_500], id: \.self) { preset in
                    Button(preset.formatted()) { store.goal = preset }
                        .buttonStyle(.bordered)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(16)
        .card()
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Motion access is off", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Steppes counts steps with the motion coprocessor. Turn on Motion & Fitness for Steppes in Settings, or grant Health access to use Health's step count instead.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .card()
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.03, green: 0.09, blue: 0.06), .black],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Pieces

struct StatTile: View {
    var icon: String
    var value: String
    var label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card()
    }
}

private extension View {
    func card() -> some View {
        self.glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    ContentView()
}
