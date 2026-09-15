import SwiftUI

/// Progress ring shared by the app and the Live Activity.
struct StepRing: View {
    var progress: Double
    var lineWidth: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.005))
                .stroke(AngularGradient(colors: [.green, .mint, .green], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Ring with the walking figure inside — the island's leading/minimal glyph.
struct WalkRing: View {
    var progress: Double
    var size: CGFloat
    var lineWidth: CGFloat
    var iconSize: CGFloat

    var body: some View {
        StepRing(progress: progress, lineWidth: lineWidth)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "figure.walk")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.green)
            }
    }
}
