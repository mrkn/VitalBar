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

    private var accessibilityValue: String {
        let cpuText = percentText(cpuSamples.last?.usage)
        let memoryText = percentText(memorySamples.last.map { $0.appRatio + $0.wiredRatio + $0.cachedRatio })
        let diskText = diskSamples.last.map(percentText) ?? "Unknown"
        return "CPU \(cpuText), Memory \(memoryText), Disk \(diskText)"
    }

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System usage")
        .accessibilityValue(accessibilityValue)
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else {
            return "Unknown"
        }

        let clamped = min(max(value, 0.0), 1.0)
        return "\(Int((clamped * 100.0).rounded()))%"
    }
}

private struct CPUAreaSparklineView: View {
    let samples: [CPULoadSample]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.primary.opacity(0.35), lineWidth: 1)

                if samples.isEmpty {
                    Path { path in
                        let midY = geometry.size.height / 2
                        path.move(to: CGPoint(x: 1, y: midY))
                        path.addLine(to: CGPoint(x: max(1, geometry.size.width - 1), y: midY))
                    }
                    .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2]))
                } else {
                    areaPath(in: geometry.size)
                        .fill(color.opacity(0.35))

                    sparklinePath(in: geometry.size)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
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
            let y = max(1, min(size.height - 1, size.height - (size.height * CGFloat(sample.usage))))

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
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.primary.opacity(0.35), lineWidth: 1)

                if samples.isEmpty {
                    Path { path in
                        let oneThirdY = geometry.size.height / 3
                        let twoThirdsY = geometry.size.height * 2 / 3
                        path.move(to: CGPoint(x: 1, y: oneThirdY))
                        path.addLine(to: CGPoint(x: max(1, geometry.size.width - 1), y: oneThirdY))
                        path.move(to: CGPoint(x: 1, y: twoThirdsY))
                        path.addLine(to: CGPoint(x: max(1, geometry.size.width - 1), y: twoThirdsY))
                    }
                    .stroke(.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 2]))
                } else {
                    stackedPath(in: geometry.size, upper: { $0.cachedRatio }, lower: { _ in 0.0 })
                        .fill(cachedColor.opacity(0.9))

                    stackedPath(in: geometry.size, upper: { $0.cachedRatio + $0.wiredRatio }, lower: { $0.cachedRatio })
                        .fill(wiredColor.opacity(0.9))

                    stackedPath(
                        in: geometry.size,
                        upper: { $0.cachedRatio + $0.wiredRatio + $0.appRatio },
                        lower: { $0.cachedRatio + $0.wiredRatio }
                    )
                    .fill(appColor.opacity(0.95))
                }
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
            let usage = samples.last
            let color: Color = isStale ? .secondary : .purple

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color.opacity(0.9), lineWidth: 1)

                if let usage {
                    let ratio = min(max(usage, 0.0), 1.0)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color.opacity(0.65))
                        .frame(height: geometry.size.height * CGFloat(ratio))
                } else {
                    Rectangle()
                        .fill(color.opacity(0.35))
                        .frame(width: geometry.size.width - 2, height: 1)
                        .padding(.bottom, geometry.size.height / 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
