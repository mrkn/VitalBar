import Combine
import Foundation
import VitalBarCore

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var samples: [CPULoadSample] = []
    @Published private(set) var currentUsageText = "--%"
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
}
