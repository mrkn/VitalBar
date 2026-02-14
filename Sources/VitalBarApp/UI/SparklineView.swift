import SwiftUI
import VitalBarCore

struct SparklineView: View {
    let samples: [CPULoadSample]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                let path = sparklinePath(in: geometry.size)
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func sparklinePath(in size: CGSize) -> Path {
        var path = Path()

        guard !samples.isEmpty else {
            return path
        }

        let count = samples.count
        let stepX = count > 1 ? size.width / CGFloat(count - 1) : 0

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * stepX
            let y = size.height - (size.height * CGFloat(sample.usage))

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}
