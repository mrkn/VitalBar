#!/usr/bin/env swift

import AppKit
import Foundation

enum IconCandidate: String, CaseIterable {
    case pulseGrid = "vitalbar-icon-pulse-grid"
    case pressureRing = "vitalbar-icon-pressure-ring"
    case monitorBars = "vitalbar-icon-monitor-bars"
    case monogramV = "vitalbar-icon-monogram-v"
}

let outputDirectory = CommandLine.arguments.dropFirst().first ?? "Assets/IconCandidates"
let canvasSize = NSSize(width: 1_024, height: 1_024)

try FileManager.default.createDirectory(
    at: URL(fileURLWithPath: outputDirectory, isDirectory: true),
    withIntermediateDirectories: true
)

for candidate in IconCandidate.allCases {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
    guard let bitmap else {
        throw NSError(domain: "IconGenerator", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGenerator", code: 3)
    }
    NSGraphicsContext.current = context
    drawCandidate(candidate, on: NSRect(origin: .zero, size: canvasSize))
    NSGraphicsContext.restoreGraphicsState()

    let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        .appendingPathComponent("\(candidate.rawValue).png")
    try writePNG(bitmap: bitmap, to: outputURL)
    print(outputURL.path)
}

func drawCandidate(_ candidate: IconCandidate, on rect: NSRect) {
    switch candidate {
    case .pulseGrid:
        drawPulseGrid(on: rect)
    case .pressureRing:
        drawPressureRing(on: rect)
    case .monitorBars:
        drawMonitorBars(on: rect)
    case .monogramV:
        drawMonogramV(on: rect)
    }
}

func writePNG(bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }

    try png.write(to: url)
}

func iconPath(in rect: NSRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40), xRadius: 220, yRadius: 220)
}

func drawPulseGrid(on rect: NSRect) {
    let path = iconPath(in: rect)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.17, blue: 0.22, alpha: 1.0),
        NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.11, alpha: 1.0),
    ])!
    gradient.draw(in: path, angle: -55)

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let lineColor = NSColor(calibratedWhite: 1.0, alpha: 0.07)
    lineColor.setStroke()
    for index in 0...10 {
        let x = rect.minX + CGFloat(index) * rect.width / 10
        let line = NSBezierPath()
        line.move(to: CGPoint(x: x, y: rect.minY))
        line.line(to: CGPoint(x: x, y: rect.maxY))
        line.lineWidth = 2
        line.stroke()
    }
    for index in 0...10 {
        let y = rect.minY + CGFloat(index) * rect.height / 10
        let line = NSBezierPath()
        line.move(to: CGPoint(x: rect.minX, y: y))
        line.line(to: CGPoint(x: rect.maxX, y: y))
        line.lineWidth = 2
        line.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    let chartFrame = NSBezierPath(roundedRect: rect.insetBy(dx: 170, dy: 260), xRadius: 70, yRadius: 70)
    NSColor(calibratedWhite: 1.0, alpha: 0.10).setFill()
    chartFrame.fill()

    let sparkline = NSBezierPath()
    let points: [CGPoint] = [
        CGPoint(x: 0.08, y: 0.40),
        CGPoint(x: 0.18, y: 0.44),
        CGPoint(x: 0.28, y: 0.35),
        CGPoint(x: 0.36, y: 0.68),
        CGPoint(x: 0.45, y: 0.30),
        CGPoint(x: 0.56, y: 0.52),
        CGPoint(x: 0.66, y: 0.46),
        CGPoint(x: 0.78, y: 0.73),
        CGPoint(x: 0.92, y: 0.62),
    ]
    for (index, point) in points.enumerated() {
        let target = CGPoint(
            x: rect.minX + 170 + point.x * (rect.width - 340),
            y: rect.minY + 260 + point.y * (rect.height - 520)
        )
        if index == 0 {
            sparkline.move(to: target)
        } else {
            sparkline.line(to: target)
        }
    }
    sparkline.lineWidth = 42
    sparkline.lineCapStyle = .round
    sparkline.lineJoinStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedRed: 0.33, green: 0.95, blue: 0.74, alpha: 0.55)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = .zero
    shadow.set()
    NSColor(calibratedRed: 0.47, green: 0.98, blue: 0.80, alpha: 1.0).setStroke()
    sparkline.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

func drawPressureRing(on rect: NSRect) {
    let path = iconPath(in: rect)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.14, green: 0.08, blue: 0.20, alpha: 1.0),
        NSColor(calibratedRed: 0.28, green: 0.11, blue: 0.08, alpha: 1.0),
    ])!
    gradient.draw(in: path, angle: 35)

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let outerRadius: CGFloat = 280
    let innerRadius: CGFloat = 190

    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: outerRadius, startAngle: 140, endAngle: -40)
    ring.appendArc(withCenter: center, radius: innerRadius, startAngle: -40, endAngle: 140, clockwise: true)
    ring.close()

    let ringGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.99, green: 0.77, blue: 0.18, alpha: 1.0),
        NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.22, alpha: 1.0),
        NSColor(calibratedRed: 0.90, green: 0.16, blue: 0.26, alpha: 1.0),
    ])!
    ringGradient.draw(in: ring, angle: -10)

    let core = NSBezierPath(ovalIn: NSRect(x: center.x - 155, y: center.y - 155, width: 310, height: 310))
    NSColor(calibratedWhite: 0.08, alpha: 0.95).setFill()
    core.fill()

    let pulse = NSBezierPath()
    let startX = rect.minX + 250
    let width = rect.width - 500
    let baseY = rect.midY - 20
    let pulsePoints: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.00),
        CGPoint(x: 0.18, y: 0.00),
        CGPoint(x: 0.31, y: 0.20),
        CGPoint(x: 0.40, y: -0.27),
        CGPoint(x: 0.52, y: 0.42),
        CGPoint(x: 0.63, y: -0.08),
        CGPoint(x: 0.78, y: 0.10),
        CGPoint(x: 1.00, y: 0.10),
    ]
    for (index, point) in pulsePoints.enumerated() {
        let target = CGPoint(
            x: startX + point.x * width,
            y: baseY + point.y * 220
        )
        if index == 0 {
            pulse.move(to: target)
        } else {
            pulse.line(to: target)
        }
    }
    pulse.lineWidth = 28
    pulse.lineCapStyle = .round
    pulse.lineJoinStyle = .round
    NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.98, alpha: 1.0).setStroke()
    pulse.stroke()
}

func drawMonitorBars(on rect: NSRect) {
    let path = iconPath(in: rect)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.02, green: 0.07, blue: 0.14, alpha: 1.0),
        NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.20, alpha: 1.0),
    ])!
    gradient.draw(in: path, angle: -90)

    let frame = NSBezierPath(roundedRect: rect.insetBy(dx: 155, dy: 185), xRadius: 90, yRadius: 90)
    NSColor(calibratedWhite: 1.0, alpha: 0.11).setFill()
    frame.fill()

    let baseline = rect.minY + 260
    let barWidth: CGFloat = 120
    let gap: CGFloat = 48
    let startX = rect.midX - ((barWidth * 4 + gap * 3) / 2)
    let heights: [CGFloat] = [210, 320, 420, 290]
    let colors: [NSColor] = [
        NSColor(calibratedRed: 0.40, green: 0.90, blue: 0.62, alpha: 1.0),
        NSColor(calibratedRed: 0.63, green: 0.93, blue: 0.35, alpha: 1.0),
        NSColor(calibratedRed: 0.98, green: 0.83, blue: 0.30, alpha: 1.0),
        NSColor(calibratedRed: 0.97, green: 0.47, blue: 0.30, alpha: 1.0),
    ]
    for index in 0..<4 {
        let barRect = NSRect(
            x: startX + CGFloat(index) * (barWidth + gap),
            y: baseline,
            width: barWidth,
            height: heights[index]
        )
        let bar = NSBezierPath(roundedRect: barRect, xRadius: 32, yRadius: 32)
        colors[index].setFill()
        bar.fill()
    }

    let sparkline = NSBezierPath()
    let points: [CGPoint] = [
        CGPoint(x: 0.13, y: 0.37),
        CGPoint(x: 0.27, y: 0.52),
        CGPoint(x: 0.43, y: 0.42),
        CGPoint(x: 0.55, y: 0.68),
        CGPoint(x: 0.72, y: 0.49),
        CGPoint(x: 0.87, y: 0.57),
    ]
    for (index, point) in points.enumerated() {
        let target = CGPoint(
            x: rect.minX + 155 + point.x * (rect.width - 310),
            y: rect.minY + 185 + point.y * (rect.height - 370)
        )
        if index == 0 {
            sparkline.move(to: target)
        } else {
            sparkline.line(to: target)
        }
    }
    sparkline.lineWidth = 20
    sparkline.lineCapStyle = .round
    sparkline.lineJoinStyle = .round
    NSColor(calibratedRed: 0.77, green: 0.95, blue: 1.0, alpha: 1.0).setStroke()
    sparkline.stroke()
}

func drawMonogramV(on rect: NSRect) {
    let path = iconPath(in: rect)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.95, alpha: 1.0),
        NSColor(calibratedRed: 0.92, green: 0.94, blue: 0.90, alpha: 1.0),
    ])!
    gradient.draw(in: path, angle: 90)

    let guide = NSBezierPath(roundedRect: rect.insetBy(dx: 180, dy: 180), xRadius: 80, yRadius: 80)
    NSColor(calibratedWhite: 0.10, alpha: 0.08).setStroke()
    guide.lineWidth = 12
    guide.stroke()

    let vPath = NSBezierPath()
    vPath.move(to: CGPoint(x: rect.midX - 250, y: rect.midY + 220))
    vPath.line(to: CGPoint(x: rect.midX - 20, y: rect.midY - 190))
    vPath.line(to: CGPoint(x: rect.midX + 230, y: rect.midY + 220))
    vPath.lineWidth = 82
    vPath.lineCapStyle = .round
    vPath.lineJoinStyle = .round
    NSColor(calibratedRed: 0.06, green: 0.12, blue: 0.16, alpha: 1.0).setStroke()
    vPath.stroke()

    let wave = NSBezierPath()
    let wavePoints: [CGPoint] = [
        CGPoint(x: 0.19, y: 0.44),
        CGPoint(x: 0.30, y: 0.49),
        CGPoint(x: 0.41, y: 0.34),
        CGPoint(x: 0.50, y: 0.59),
        CGPoint(x: 0.62, y: 0.39),
        CGPoint(x: 0.74, y: 0.50),
        CGPoint(x: 0.84, y: 0.46),
    ]
    for (index, point) in wavePoints.enumerated() {
        let target = CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
        if index == 0 {
            wave.move(to: target)
        } else {
            wave.line(to: target)
        }
    }
    wave.lineWidth = 30
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    NSColor(calibratedRed: 0.14, green: 0.62, blue: 0.95, alpha: 1.0).setStroke()
    wave.stroke()
}
