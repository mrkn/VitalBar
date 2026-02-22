import SwiftUI
import VitalBarCore

struct MenuBarLabelView: View {
    static let sparklineWidth: CGFloat = 42
    static let sparklineHeight: CGFloat = 12

    let samples: [CPULoadSample]
    let usageText: String
    let isStale: Bool

    var body: some View {
        let level = UsageStyle.level(for: samples.last?.usage, isStale: isStale)
        let color = UsageStyle.color(for: level)

        HStack(spacing: 6) {
            SparklineView(samples: Array(samples.suffix(40)), color: color)
                .frame(width: Self.sparklineWidth, height: Self.sparklineHeight)

            Text(usageText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        
    }
}
