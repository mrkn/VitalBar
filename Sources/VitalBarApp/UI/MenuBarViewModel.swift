import Combine
import Foundation
import VitalBarCore

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var samples: [CPULoadSample] = []
    @Published private(set) var currentUsageText = "--%"
    @Published private(set) var memoryUsageText = "-- / --"
    @Published private(set) var memoryPressureText = "--"
    @Published private(set) var memoryPressureLevel: MemoryPressureLevel?
    @Published private(set) var appMemoryText = "--"
    @Published private(set) var wiredMemoryText = "--"
    @Published private(set) var cachedFilesText = "--"
    @Published private(set) var compressedText = "--"
    @Published private(set) var swapUsedText = "--"
    @Published private(set) var uptimeText = "--"
    @Published private(set) var isStale = false
    @Published private(set) var staleMessage: String?

    private let service: any CPUHistoryStreaming
    private var streamTask: Task<Void, Never>?

    init(service: any CPUHistoryStreaming) {
        self.service = service
        start()
    }

    deinit {
        streamTask?.cancel()
        let historyService = service

        Task {
            await historyService.stop()
        }
    }

    var currentUsage: Double? {
        samples.last?.usage
    }

    func start() {
        guard streamTask == nil else {
            return
        }

        streamTask = Task { [weak self] in
            guard let self else {
                return
            }

            await service.start()
            let stream = await service.snapshots()

            for await snapshot in stream {
                self.apply(snapshot)
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil

        Task {
            await service.stop()
        }
    }

    static func percentText(for usage: Double?) -> String {
        guard let usage else {
            return "--%"
        }

        return "\(Int((usage * 100.0).rounded()))%"
    }

    static func memoryFractionText(for sample: MemoryUsageSample?) -> String {
        guard let sample else {
            return "-- / --"
        }

        return "\(formatGigabytes(sample.usedBytes)) / \(formatGigabytes(sample.totalBytes))"
    }

    static func memoryPressureText(for sample: MemoryUsageSample?) -> String {
        guard let sample else {
            return "--"
        }

        switch sample.pressureLevel {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        case .unknown:
            return "Unknown"
        }
    }

    static func bytesText(for bytes: UInt64?) -> String {
        guard let bytes else {
            return "--"
        }

        return formatGigabytes(bytes)
    }

    static func uptimeText(for uptimeSeconds: TimeInterval) -> String {
        guard uptimeSeconds >= 0 else {
            return "--"
        }

        let totalSeconds = Int(uptimeSeconds.rounded(.down))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        }

        return "\(hours)h \(minutes)m"
    }

    private func apply(_ snapshot: CPUHistorySnapshot) {
        samples = snapshot.history
        currentUsageText = Self.percentText(for: snapshot.latest?.usage)
        memoryUsageText = Self.memoryFractionText(for: snapshot.memoryUsage)
        memoryPressureLevel = snapshot.memoryUsage?.pressureLevel
        memoryPressureText = Self.memoryPressureText(for: snapshot.memoryUsage)
        appMemoryText = Self.bytesText(for: snapshot.memoryUsage?.appBytes)
        wiredMemoryText = Self.bytesText(for: snapshot.memoryUsage?.wiredBytes)
        cachedFilesText = Self.bytesText(for: snapshot.memoryUsage?.cachedBytes)
        compressedText = Self.bytesText(for: snapshot.memoryUsage?.compressedBytes)
        swapUsedText = Self.bytesText(for: snapshot.memoryUsage?.swapUsedBytes)
        uptimeText = Self.uptimeText(for: ProcessInfo.processInfo.systemUptime)
        isStale = snapshot.isStale

        if snapshot.isStale {
            if let lastErrorDescription = snapshot.lastErrorDescription {
                staleMessage = "Sampling error: \(lastErrorDescription)"
            } else {
                staleMessage = "No successful update in the last 5 seconds."
            }
        } else {
            staleMessage = nil
        }
    }

    private static func formatGigabytes(_ bytes: UInt64) -> String {
        let gibibytes = Double(bytes) / 1_073_741_824.0
        if let formatted = gigabyteFormatter.string(from: NSNumber(value: gibibytes)) {
            return "\(formatted) GB"
        }

        return "0.0 GB"
    }

    private static let gigabyteFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
