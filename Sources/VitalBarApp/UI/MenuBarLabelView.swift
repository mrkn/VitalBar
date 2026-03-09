import AppKit
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
    static let graphHeight: CGFloat = 18
    static let graphSpacing: CGFloat = 5
    static let awakeIndicatorSize: CGFloat = 16
    static let awakeIndicatorSpacing: CGFloat = 4
    static let maxHistoryCount = 40
    static let totalGraphWidth: CGFloat = cpuGraphWidth + graphSpacing + memoryGraphWidth + graphSpacing + diskGraphWidth
    static let totalAwakeGraphWidth: CGFloat = totalGraphWidth + awakeIndicatorSpacing + awakeIndicatorSize

    let cpuSamples: [CPULoadSample]
    let memorySamples: [MemoryCompositionPoint]
    let diskSamples: [Double]
    let isStale: Bool
    let keepMacAwakeEnabled: Bool

    private var labelWidth: CGFloat {
        if keepMacAwakeEnabled {
            return Self.totalAwakeGraphWidth
        }
        return Self.totalGraphWidth
    }

    private var accessibilityValue: String {
        let cpuText = percentText(cpuSamples.last?.usage)
        let memoryText = percentText(memorySamples.last.map { $0.appRatio + $0.wiredRatio + $0.cachedRatio })
        let diskText = diskSamples.last.map(percentText) ?? "Unknown"
        let awakeText = keepMacAwakeEnabled ? ", Keep Mac Awake enabled" : ""
        return "CPU \(cpuText), Memory \(memoryText), Disk \(diskText)\(awakeText)"
    }

    var body: some View {
        imageGraphs
        .frame(width: labelWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System usage")
        .accessibilityValue(accessibilityValue)
    }

    private var vectorGraphs: some View {
        let cpuLevel = UsageStyle.level(for: cpuSamples.last?.usage, isStale: isStale)
        let cpuColor = UsageStyle.color(for: cpuLevel)

        return HStack(spacing: Self.graphSpacing) {
            CPUAreaSparklineView(samples: Array(cpuSamples.suffix(Self.maxHistoryCount)), color: cpuColor)
                .frame(width: Self.cpuGraphWidth, height: Self.graphHeight)

            MemoryStackedSparklineView(samples: Array(memorySamples.suffix(Self.maxHistoryCount)))
                .frame(width: Self.memoryGraphWidth, height: Self.graphHeight)

            DiskUsageBarView(samples: Array(diskSamples.suffix(Self.maxHistoryCount)), isStale: isStale)
                .frame(width: Self.diskGraphWidth, height: Self.graphHeight)
        }
    }

    private var imageGraphs: some View {
        MenuBarImageGraphView(
            cpuSamples: Array(cpuSamples.suffix(Self.maxHistoryCount)),
            memorySamples: Array(memorySamples.suffix(Self.maxHistoryCount)),
            diskSamples: Array(diskSamples.suffix(Self.maxHistoryCount)),
            isStale: isStale,
            keepMacAwakeEnabled: keepMacAwakeEnabled
        )
        .frame(width: labelWidth, height: Self.graphHeight)
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
            let borderShape = RoundedRectangle(cornerRadius: 2)
            let clipShape = RoundedRectangle(cornerRadius: 1)

            ZStack {
                ZStack {
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
                .clipShape(clipShape)

                borderShape
                    .stroke(.primary.opacity(0.35), lineWidth: 1)
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
            let borderShape = RoundedRectangle(cornerRadius: 2)
            let clipShape = RoundedRectangle(cornerRadius: 1)

            ZStack {
                ZStack {
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
                .clipShape(clipShape)

                borderShape
                    .stroke(.primary.opacity(0.35), lineWidth: 1)
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
            let borderShape = RoundedRectangle(cornerRadius: 2)
            let clipShape = RoundedRectangle(cornerRadius: 1)

            ZStack {
                ZStack(alignment: .bottom) {
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
                .clipShape(clipShape)

                borderShape
                    .stroke(color.opacity(0.9), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MenuBarImageGraphView: View {
    let cpuSamples: [CPULoadSample]
    let memorySamples: [MemoryCompositionPoint]
    let diskSamples: [Double]
    let isStale: Bool
    let keepMacAwakeEnabled: Bool

    var body: some View {
        let cpuLevel = UsageStyle.level(for: cpuSamples.last?.usage, isStale: isStale)
        let image = MenuBarGraphImageRenderer.render(
            cpuSamples: cpuSamples,
            memorySamples: memorySamples,
            diskSamples: diskSamples,
            cpuLevel: cpuLevel,
            isStale: isStale,
            keepMacAwakeEnabled: keepMacAwakeEnabled
        )

        return Image(nsImage: image)
            .interpolation(.none)
            .antialiased(true)
            .accessibilityHidden(true)
    }
}

@MainActor
private enum MenuBarGraphImageRenderer {
    static func render(
        cpuSamples: [CPULoadSample],
        memorySamples: [MemoryCompositionPoint],
        diskSamples: [Double],
        cpuLevel: UsageLevel,
        isStale: Bool,
        keepMacAwakeEnabled: Bool
    ) -> NSImage {
        let width = keepMacAwakeEnabled ? MenuBarLabelView.totalAwakeGraphWidth : MenuBarLabelView.totalGraphWidth
        let size = NSSize(width: width, height: MenuBarLabelView.graphHeight)
        let image = NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            context.saveGState()
            defer { context.restoreGState() }

            context.setAllowsAntialiasing(true)
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)

            let cpuRect = CGRect(x: 0, y: 0, width: MenuBarLabelView.cpuGraphWidth, height: MenuBarLabelView.graphHeight)
            let memoryX = cpuRect.maxX + MenuBarLabelView.graphSpacing
            let memoryRect = CGRect(
                x: memoryX,
                y: 0,
                width: MenuBarLabelView.memoryGraphWidth,
                height: MenuBarLabelView.graphHeight
            )
            let diskX = memoryRect.maxX + MenuBarLabelView.graphSpacing
            let diskRect = CGRect(x: diskX, y: 0, width: MenuBarLabelView.diskGraphWidth, height: MenuBarLabelView.graphHeight)

            drawCPUGraph(in: context, rect: cpuRect, samples: cpuSamples, level: cpuLevel)
            drawMemoryGraph(in: context, rect: memoryRect, samples: memorySamples)
            drawDiskGraph(in: context, rect: diskRect, usage: diskSamples.last, isStale: isStale)
            if keepMacAwakeEnabled {
                let symbolX = diskRect.maxX + MenuBarLabelView.awakeIndicatorSpacing
                let symbolRect = CGRect(
                    x: symbolX,
                    y: (MenuBarLabelView.graphHeight - MenuBarLabelView.awakeIndicatorSize) / 2,
                    width: MenuBarLabelView.awakeIndicatorSize,
                    height: MenuBarLabelView.awakeIndicatorSize
                )
                drawAwakeIndicator(in: context, rect: symbolRect)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawAwakeIndicator(in context: CGContext, rect: CGRect) {
        let configuration = NSImage.SymbolConfiguration(pointSize: MenuBarLabelView.awakeIndicatorSize, weight: .regular)
        guard
            let symbol = NSImage(
                systemSymbolName: "cup.and.saucer.fill",
                accessibilityDescription: "Keep Mac Awake enabled"
            )?.withSymbolConfiguration(configuration),
            let cgImage = symbol.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return
        }

        context.saveGState()
        defer { context.restoreGState() }

        // The menu bar graph renderer flips the whole context for graph drawing.
        // Flip the symbol back so SF Symbols render upright.
        context.translateBy(x: 0, y: rect.minY * 2 + rect.height)
        context.scaleBy(x: 1, y: -1)
        context.setBlendMode(.normal)
        context.clip(to: rect, mask: cgImage)
        context.setFillColor(NSColor.labelColor.cgColor)
        context.fill(rect)
    }

    private static func drawCPUGraph(in context: CGContext, rect: CGRect, samples: [CPULoadSample], level: UsageLevel) {
        clipToInnerMask(in: context, rect: rect) {
            if samples.isEmpty {
                drawHorizontalGuideline(
                    in: context,
                    rect: rect,
                    y: rect.midY,
                    color: NSColor.labelColor.withAlphaComponent(0.55),
                    dashed: true
                )
            } else {
                let sparklinePoints = points(
                    count: samples.count,
                    in: rect,
                    valueProvider: { max(0.0, min(1.0, samples[$0].usage)) }
                )

                fillArea(in: context, rect: rect, points: sparklinePoints, color: color(for: level).withAlphaComponent(0.35))
                strokeLine(in: context, points: sparklinePoints, color: color(for: level), lineWidth: 1.4)
            }
        }

        strokeRoundedRect(
            in: context,
            rect: rect,
            color: NSColor.labelColor.withAlphaComponent(0.35),
            cornerRadius: 2,
            lineWidth: 1
        )
    }

    private static func drawMemoryGraph(in context: CGContext, rect: CGRect, samples: [MemoryCompositionPoint]) {
        clipToInnerMask(in: context, rect: rect) {
            if samples.isEmpty {
                drawHorizontalGuideline(
                    in: context,
                    rect: rect,
                    y: rect.minY + (rect.height / 3.0),
                    color: NSColor.labelColor.withAlphaComponent(0.5),
                    dashed: true
                )
                drawHorizontalGuideline(
                    in: context,
                    rect: rect,
                    y: rect.minY + (rect.height * 2.0 / 3.0),
                    color: NSColor.labelColor.withAlphaComponent(0.5),
                    dashed: true
                )
            } else {
                fillStackedBand(
                    in: context,
                    rect: rect,
                    samples: samples,
                    upper: { clamp($0.cachedRatio) },
                    lower: { _ in 0.0 },
                    color: NSColor.systemTeal.withAlphaComponent(0.85)
                )
                fillStackedBand(
                    in: context,
                    rect: rect,
                    samples: samples,
                    upper: { clamp($0.cachedRatio + $0.wiredRatio) },
                    lower: { clamp($0.cachedRatio) },
                    color: NSColor.systemOrange.withAlphaComponent(0.90)
                )
                fillStackedBand(
                    in: context,
                    rect: rect,
                    samples: samples,
                    upper: { clamp($0.cachedRatio + $0.wiredRatio + $0.appRatio) },
                    lower: { clamp($0.cachedRatio + $0.wiredRatio) },
                    color: NSColor.systemBlue.withAlphaComponent(0.92)
                )
            }
        }

        strokeRoundedRect(
            in: context,
            rect: rect,
            color: NSColor.labelColor.withAlphaComponent(0.35),
            cornerRadius: 2,
            lineWidth: 1
        )
    }

    private static func drawDiskGraph(in context: CGContext, rect: CGRect, usage: Double?, isStale: Bool) {
        let color = isStale ? NSColor.secondaryLabelColor : NSColor.systemPurple

        clipToInnerMask(in: context, rect: rect) {
            if let usage {
                let ratio = clamp(usage)
                let barHeight = rect.height * ratio
                let barRect = CGRect(
                    x: rect.minX + 1,
                    y: rect.maxY - barHeight,
                    width: max(1, rect.width - 2),
                    height: barHeight
                )
                fillRoundedRect(
                    in: context,
                    rect: barRect,
                    color: color.withAlphaComponent(0.65),
                    cornerRadius: 1.5
                )
            } else {
                drawHorizontalGuideline(
                    in: context,
                    rect: rect,
                    y: rect.midY,
                    color: color.withAlphaComponent(0.35),
                    dashed: false
                )
            }
        }

        strokeRoundedRect(
            in: context,
            rect: rect,
            color: color.withAlphaComponent(0.9),
            cornerRadius: 2,
            lineWidth: 1
        )
    }

    private static func clipToInnerMask(in context: CGContext, rect: CGRect, draw: () -> Void) {
        let clipRect = rect.insetBy(dx: 1, dy: 1)
        let clipPath = CGPath(
            roundedRect: clipRect,
            cornerWidth: 1,
            cornerHeight: 1,
            transform: nil
        )

        context.saveGState()
        context.addPath(clipPath)
        context.clip()
        draw()
        context.restoreGState()
    }

    private static func fillStackedBand(
        in context: CGContext,
        rect: CGRect,
        samples: [MemoryCompositionPoint],
        upper: (MemoryCompositionPoint) -> Double,
        lower: (MemoryCompositionPoint) -> Double,
        color: NSColor
    ) {
        guard !samples.isEmpty else {
            return
        }

        let stepX = samples.count > 1 ? rect.width / CGFloat(samples.count - 1) : 0

        context.beginPath()

        for (index, sample) in samples.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let y = rect.maxY - (rect.height * CGFloat(upper(sample)))
            if index == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }

        for (index, sample) in samples.enumerated().reversed() {
            let x = rect.minX + CGFloat(index) * stepX
            let y = rect.maxY - (rect.height * CGFloat(lower(sample)))
            context.addLine(to: CGPoint(x: x, y: y))
        }

        context.closePath()
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    private static func points(
        count: Int,
        in rect: CGRect,
        valueProvider: (Int) -> Double
    ) -> [CGPoint] {
        guard count > 0 else {
            return []
        }

        let stepX = count > 1 ? rect.width / CGFloat(count - 1) : 0
        var result: [CGPoint] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            let x = rect.minX + CGFloat(index) * stepX
            let value = valueProvider(index)
            let y = max(rect.minY + 1, min(rect.maxY - 1, rect.maxY - (rect.height * value)))
            result.append(CGPoint(x: x, y: y))
        }

        return result
    }

    private static func fillArea(in context: CGContext, rect: CGRect, points: [CGPoint], color: NSColor) {
        guard !points.isEmpty else {
            return
        }

        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        context.closePath()
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    private static func strokeLine(in context: CGContext, points: [CGPoint], color: NSColor, lineWidth: CGFloat) {
        guard !points.isEmpty else {
            return
        }

        context.beginPath()
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.strokePath()
    }

    private static func drawHorizontalGuideline(
        in context: CGContext,
        rect: CGRect,
        y: CGFloat,
        color: NSColor,
        dashed: Bool
    ) {
        context.beginPath()
        context.move(to: CGPoint(x: rect.minX + 1, y: y))
        context.addLine(to: CGPoint(x: max(rect.minX + 1, rect.maxX - 1), y: y))
        context.setStrokeColor(color.cgColor)
        context.setLineCap(.round)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: dashed ? [2, 2] : [])
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }

    private static func strokeRoundedRect(
        in context: CGContext,
        rect: CGRect,
        color: NSColor,
        cornerRadius: CGFloat,
        lineWidth: CGFloat
    ) {
        let insetRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let path = CGPath(
            roundedRect: insetRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.strokePath()
    }

    private static func fillRoundedRect(
        in context: CGContext,
        rect: CGRect,
        color: NSColor,
        cornerRadius: CGFloat
    ) {
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private static func color(for level: UsageLevel) -> NSColor {
        switch level {
        case .unknown:
            return NSColor.secondaryLabelColor
        case .idle:
            return NSColor.systemGreen
        case .moderate:
            return NSColor.systemYellow
        case .high:
            return NSColor.systemRed
        case .stale:
            return NSColor.systemOrange
        }
    }
}
