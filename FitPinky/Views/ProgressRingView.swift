import SwiftUI

struct ProgressRingView: View {
    let name: String
    let current: Int
    let goal: Int
    let ringProgress: CGFloat

    private var fraction: CGFloat {
        goal > 0 ? min(CGFloat(current) / CGFloat(goal), 1.0) : 0
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.cardBorder, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: fraction * ringProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.brand, .brandPurple, .brand]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: ringProgress)

                Text("\(current)/\(goal)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 110, height: 110)

            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.textSecondary)
        }
    }
}
