import SwiftUI
import VitalBarCore

struct MemoryCompositionPoint: Equatable {
    let appRatio: Double
    let wiredRatio: Double
    let cachedRatio: Double
}

struct MenuBarLabelView: View {
    static let cpuGraphWidth: CGFloat = 34
    static let memoryGraphWidth: CGFloat = 34
    static let diskGraphWidth: CGFloat = 8
    static let graphHeight: CGFloat = 12

    let cpuSamples: [CPULoadSample]
    let memorySamples: [MemoryCompositionPoint]
    let diskSamples: [Double]
    let isStale: Bool

    var body: some View {
        let cpuLevel = UsageStyle.level(for: cpuSamples.last?.usage, isStale: isStale)
        let cpuColor = UsageStyle.color(for: cpuLevel)

        HStack(spacing: 5) {
            CPUAreaSparklineView(samples: Array(cpuSamples.suffix(40)), color: cpuColor)
                .frame(width: Self.cpuGraphWidth, height: Self.graphHeight)

            MemoryStackedSparklineView(samples: Array(memorySamples.suffix(40)))
                .frame(width: Self.memoryGraphWidth, height: Self.graphHeight)

            DiskUsageBarView(samples: Array(diskSamples.suffix(40)), isStale: isStale)
                .frame(width: Self.diskGraphWidth, height: Self.graphHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CPU, memory, and disk usage")
    }
}

private struct CPUAreaSparklineView: View {
    let samples: [CPULoadSample]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                let linePath = sparklinePath(in: geometry.size)
                let areaPath = areaPath(in: geometry.size)

                context.fill(areaPath, with: .color(color.opacity(0.25)))
                context.stroke(
                    linePath,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
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

        let stepX = samples.count > 1 ? size.width / CGFloat(samples.count - 1) : 0

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

    private func areaPath(in size: CGSize) -> Path {
        var path = sparklinePath(in: size)

        guard !samples.isEmpty else {
            return path
        }

        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}

private struct MemoryStackedSparklineView: View {
    let samples: [MemoryCompositionPoint]

    private let appColor = Color.blue.opacity(0.9)
    private let wiredColor = Color.orange.opacity(0.9)
    private let cachedColor = Color.teal.opacity(0.85)

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                let cachedPath = stackedPath(in: geometry.size, upper: { $0.cachedRatio }, lower: { _ in 0.0 })
                let wiredPath = stackedPath(in: geometry.size, upper: { $0.cachedRatio + $0.wiredRatio }, lower: { $0.cachedRatio })
                let appPath = stackedPath(
                    in: geometry.size,
                    upper: { $0.cachedRatio + $0.wiredRatio + $0.appRatio },
                    lower: { $0.cachedRatio + $0.wiredRatio }
                )

                context.fill(cachedPath, with: .color(cachedColor))
                context.fill(wiredPath, with: .color(wiredColor))
                context.fill(appPath, with: .color(appColor))
            }
        }
        .accessibilityHidden(true)
    }

    private func stackedPath(
        in size: CGSize,
        upper: (MemoryCompositionPoint) -> Double,
        lower: (MemoryCompositionPoint) -> Double
    ) -> Path {
        var path = Path()

        guard !samples.isEmpty else {
            return path
        }

        let stepX = samples.count > 1 ? size.width / CGFloat(samples.count - 1) : 0

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * stepX
            let y = size.height - (size.height * CGFloat(clamp(upper(sample))))

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        for (reverseIndex, sample) in samples.enumerated().reversed() {
            let x = CGFloat(reverseIndex) * stepX
            let y = size.height - (size.height * CGFloat(clamp(lower(sample))))
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.closeSubpath()
        return path
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}

private struct DiskUsageBarView: View {
    let samples: [Double]
    let isStale: Bool

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                let usage = samples.last ?? 0.0
                let ratio = min(max(usage, 0.0), 1.0)
                let fillHeight = geometry.size.height * CGFloat(ratio)
                let barRect = CGRect(
                    x: 0,
                    y: geometry.size.height - fillHeight,
                    width: geometry.size.width,
                    height: fillHeight
                )

                let border = RoundedRectangle(cornerRadius: 2)
                let color: Color = isStale ? .secondary : .purple

                context.fill(Path(barRect), with: .color(color.opacity(0.65)))
                context.stroke(border.path(in: CGRect(origin: .zero, size: geometry.size)), with: .color(color.opacity(0.9)), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}
