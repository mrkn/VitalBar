import Foundation
import XCTest
@testable import VitalBarApp
@testable import VitalBarCore

actor MockCPUHistoryService: CPUHistoryStreaming {
    private let stream: AsyncStream<CPUHistorySnapshot>
    private var continuation: AsyncStream<CPUHistorySnapshot>.Continuation?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    init(initialSnapshot: CPUHistorySnapshot) {
        var capturedContinuation: AsyncStream<CPUHistorySnapshot>.Continuation?

        stream = AsyncStream { continuation in
            capturedContinuation = continuation
        }

        continuation = capturedContinuation
        continuation?.yield(initialSnapshot)
    }

    func start() async {
        startCallCount += 1
    }

    func stop() async {
        stopCallCount += 1
        continuation?.finish()
    }

    func snapshots() async -> AsyncStream<CPUHistorySnapshot> {
        stream
    }

    func emit(_ snapshot: CPUHistorySnapshot) async {
        continuation?.yield(snapshot)
    }
}

final class MockLaunchAtLoginController: LaunchAtLoginControlling {
    var currentStatus: LaunchAtLoginStatus
    var nextSetResult: Result<Void, Error> = .success(())
    private(set) var setEnabledCalls: [Bool] = []

    init(status: LaunchAtLoginStatus) {
        self.currentStatus = status
    }

    func status() -> LaunchAtLoginStatus {
        currentStatus
    }

    func setEnabled(_ enabled: Bool) throws {
        setEnabledCalls.append(enabled)
        switch nextSetResult {
        case .success:
            currentStatus = enabled ? .enabled : .disabled
        case let .failure(error):
            throw error
        }
    }
}

final class MenuBarViewModelTests: XCTestCase {
    @MainActor
    func testViewModelReceives120Samples() async throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let viewModel = MenuBarViewModel(service: service)

        let samples = (0..<120).map { index in
            CPULoadSample(
                timestamp: base.addingTimeInterval(Double(index)),
                usage: Double(index % 100) / 100.0
            )
        }

        let gib = UInt64(1_073_741_824)
        await service.emit(
            makeSnapshot(
                samples: samples,
                latest: samples.last,
                memoryUsage: MemoryUsageSample(
                    usedBytes: 8 * gib,
                    totalBytes: 16 * gib,
                    appBytes: 4 * gib,
                    wiredBytes: 2 * gib,
                    cachedBytes: 5 * gib,
                    compressedBytes: 2 * gib,
                    swapUsedBytes: gib,
                    pressureLevel: .warning
                ),
                diskUsage: DiskUsageSample(usedBytes: 412_000_000_000, totalBytes: 1_000_000_000_000),
                temperatures: [
                    TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 63.2),
                    TemperatureSensorReading(id: "gpu", name: "GPU Temperature", celsius: 58.0),
                ]
            )
        )
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.samples.count, 120)
        XCTAssertEqual(viewModel.currentUsageText, MenuBarViewModel.percentText(for: samples.last?.usage))
        XCTAssertEqual(viewModel.diskUsageText, "412GB / 1TB (41%)")
        XCTAssertEqual(viewModel.memoryUsageText, "8.0 GB / 16.0 GB")
        XCTAssertEqual(viewModel.memoryPressureText, "Warning")
        XCTAssertEqual(viewModel.appMemoryText, "4.0 GB")
        XCTAssertEqual(viewModel.wiredMemoryText, "2.0 GB")
        XCTAssertEqual(viewModel.cachedFilesText, "5.0 GB")
        XCTAssertEqual(viewModel.compressedText, "2.0 GB")
        XCTAssertEqual(viewModel.swapUsedText, "1.0 GB")
        XCTAssertEqual(viewModel.temperatureReadings.count, 2)
        XCTAssertEqual(viewModel.temperatureReadings[0].id, "cpu")
        XCTAssertEqual(viewModel.temperatureReadings[0].celsius, 63.2, accuracy: 0.0001)
        XCTAssertNotEqual(viewModel.uptimeText, "--")
        viewModel.stop()
    }

    @MainActor
    func testViewModelEntersStaleState() async throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let viewModel = MenuBarViewModel(service: service)

        let gib = UInt64(1_073_741_824)
        let latest = CPULoadSample(timestamp: base, usage: 0.42)
        await service.emit(
            makeSnapshot(
                samples: [latest],
                latest: latest,
                memoryUsage: MemoryUsageSample(
                    usedBytes: 12 * gib,
                    totalBytes: 16 * gib,
                    appBytes: 6 * gib,
                    wiredBytes: 3 * gib,
                    cachedBytes: 2 * gib,
                    compressedBytes: gib,
                    swapUsedBytes: 0,
                    pressureLevel: .normal
                ),
                diskUsage: DiskUsageSample(usedBytes: 0, totalBytes: 0),
                temperatures: [
                    TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 55.5),
                ],
                lastSuccessfulSampleAt: base,
                isStale: true,
                consecutiveFailures: 3,
                lastErrorDescription: "sample failure"
            )
        )

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(viewModel.isStale)
        XCTAssertEqual(viewModel.currentUsageText, "42%")
        XCTAssertEqual(viewModel.diskUsageText, "0B / 0B (0%)")
        XCTAssertEqual(viewModel.memoryUsageText, "12.0 GB / 16.0 GB")
        XCTAssertEqual(viewModel.memoryPressureText, "Normal")
        XCTAssertEqual(viewModel.appMemoryText, "6.0 GB")
        XCTAssertEqual(viewModel.wiredMemoryText, "3.0 GB")
        XCTAssertEqual(viewModel.cachedFilesText, "2.0 GB")
        XCTAssertEqual(viewModel.compressedText, "1.0 GB")
        XCTAssertEqual(viewModel.swapUsedText, "0.0 GB")
        XCTAssertEqual(viewModel.temperatureReadings.count, 1)
        XCTAssertEqual(viewModel.temperatureReadings[0].id, "cpu")
        XCTAssertEqual(viewModel.temperatureReadings[0].celsius, 55.5, accuracy: 0.0001)
        XCTAssertNotNil(viewModel.staleMessage)
        viewModel.stop()
    }

    @MainActor
    func testPercentTextFormatting() {
        XCTAssertEqual(MenuBarViewModel.percentText(for: nil), "--%")
        XCTAssertEqual(MenuBarViewModel.percentText(for: 0.424), "42%")
        XCTAssertEqual(MenuBarViewModel.percentText(for: 0.995), "100%")
    }

    @MainActor
    func testUptimeTextFormatting() {
        XCTAssertEqual(MenuBarViewModel.uptimeText(for: -1), "--")
        XCTAssertEqual(MenuBarViewModel.uptimeText(for: 3599), "0h 59m")
        XCTAssertEqual(MenuBarViewModel.uptimeText(for: 3661), "1h 1m")
        XCTAssertEqual(MenuBarViewModel.uptimeText(for: 90_061), "1d 1h 1m")
    }

    @MainActor
    func testMemoryFractionFormatting() {
        let gib = UInt64(1_073_741_824)

        XCTAssertEqual(MenuBarViewModel.memoryFractionText(for: nil), "-- / --")
        XCTAssertEqual(
            MenuBarViewModel.memoryFractionText(
                for: MemoryUsageSample(usedBytes: 8 * gib, totalBytes: 16 * gib)
            ),
            "8.0 GB / 16.0 GB"
        )
    }


    @MainActor
    func testDiskUsageFormatting() {
        XCTAssertEqual(MenuBarViewModel.diskUsageText(for: nil), "N/A")
        XCTAssertEqual(
            MenuBarViewModel.diskUsageText(
                for: DiskUsageSample(usedBytes: 412_000_000_000, totalBytes: 1_000_000_000_000)
            ),
            "412GB / 1TB (41%)"
        )
    }

    @MainActor
    func testMemoryPressureFormatting() {
        let gib = UInt64(1_073_741_824)

        XCTAssertEqual(MenuBarViewModel.memoryPressureText(for: nil), "--")
        XCTAssertEqual(
            MenuBarViewModel.memoryPressureText(
                for: MemoryUsageSample(usedBytes: 8 * gib, totalBytes: 16 * gib, pressureLevel: .normal)
            ),
            "Normal"
        )
        XCTAssertEqual(
            MenuBarViewModel.memoryPressureText(
                for: MemoryUsageSample(usedBytes: 8 * gib, totalBytes: 16 * gib, pressureLevel: .critical)
            ),
            "Critical"
        )
    }

    @MainActor
    func testBytesFormatting() {
        let gib = UInt64(1_073_741_824)

        XCTAssertEqual(MenuBarViewModel.bytesText(for: nil), "--")
        XCTAssertEqual(MenuBarViewModel.bytesText(for: 3 * gib), "3.0 GB")
    }

    @MainActor
    func testTemperatureFormatting() {
        XCTAssertEqual(MenuBarViewModel.temperatureText(for: nil), "N/A")
        XCTAssertEqual(MenuBarViewModel.temperatureText(for: 60.0), "60.0°C")
        XCTAssertEqual(MenuBarViewModel.temperatureText(for: 48.26), "48.3°C")
    }

    @MainActor
    func testCPUAndSoCTemperatureSummaryFormatting() {
        XCTAssertNil(MenuBarViewModel.cpuSoCTemperatureText(for: []))

        let cpuOnly = [TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 60.0)]
        XCTAssertEqual(MenuBarViewModel.cpuSoCTemperatureText(for: cpuOnly), "60.0°C")

        let socOnly = [TemperatureSensorReading(id: "soc", name: "SoC Temperature", celsius: 37.5)]
        XCTAssertEqual(MenuBarViewModel.cpuSoCTemperatureText(for: socOnly), "37.5°C")

        let cpuAndSoc = [
            TemperatureSensorReading(id: "soc", name: "SoC Temperature", celsius: 37.5),
            TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 35.3),
            TemperatureSensorReading(id: "gpu", name: "GPU Temperature", celsius: 33.0),
        ]
        XCTAssertEqual(MenuBarViewModel.cpuSoCTemperatureText(for: cpuAndSoc), "35.3°C / 37.5°C")
    }

    @MainActor
    func testTemperatureDetailMenuVisibility() {
        XCTAssertFalse(MenuBarViewModel.shouldShowTemperatureDetails(for: []))

        let cpuAndSoc = [
            TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 35.3),
            TemperatureSensorReading(id: "soc", name: "SoC Temperature", celsius: 37.5),
        ]
        XCTAssertFalse(MenuBarViewModel.shouldShowTemperatureDetails(for: cpuAndSoc))

        let gpuOnly = [TemperatureSensorReading(id: "gpu", name: "GPU Temperature", celsius: 45.0)]
        XCTAssertTrue(MenuBarViewModel.shouldShowTemperatureDetails(for: gpuOnly))

        let cpuAndGpu = [
            TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 35.3),
            TemperatureSensorReading(id: "gpu", name: "GPU Temperature", celsius: 45.0),
        ]
        XCTAssertTrue(MenuBarViewModel.shouldShowTemperatureDetails(for: cpuAndGpu))
    }

    func testUsageStyleThresholds() {
        XCTAssertEqual(UsageStyle.level(for: nil, isStale: false), .unknown)
        XCTAssertEqual(UsageStyle.level(for: 0.10, isStale: false), .idle)
        XCTAssertEqual(UsageStyle.level(for: 0.65, isStale: false), .moderate)
        XCTAssertEqual(UsageStyle.level(for: 0.90, isStale: false), .high)
        XCTAssertEqual(UsageStyle.level(for: 0.20, isStale: true), .stale)
    }

    @MainActor
    func testMenuBarLabelGraphDimensions() {
        XCTAssertEqual(MenuBarLabelView.cpuGraphWidth, 34)
        XCTAssertEqual(MenuBarLabelView.memoryGraphWidth, 34)
        XCTAssertEqual(MenuBarLabelView.diskGraphWidth, 8)
        XCTAssertEqual(MenuBarLabelView.graphHeight, 18)
    }
    @MainActor
    func testViewModelTracksCompactGraphHistories() async throws {
        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let viewModel = MenuBarViewModel(service: service)
        let gib = UInt64(1_073_741_824)

        for index in 0..<45 {
            await service.emit(
                makeSnapshot(
                    memoryUsage: MemoryUsageSample(
                        usedBytes: 8 * gib,
                        totalBytes: 16 * gib,
                        appBytes: UInt64(index + 1) * 100_000_000,
                        wiredBytes: UInt64(index + 1) * 50_000_000,
                        cachedBytes: UInt64(index + 1) * 25_000_000
                    ),
                    diskUsage: DiskUsageSample(usedBytes: UInt64(index + 1), totalBytes: 100)
                )
            )
        }

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.memoryHistory.count, 40)
        XCTAssertEqual(viewModel.diskUsageHistory.count, 40)
        let lastDiskUsage = try XCTUnwrap(viewModel.diskUsageHistory.last)
        XCTAssertEqual(lastDiskUsage, 0.45, accuracy: 0.0001)
        viewModel.stop()
    }

    @MainActor
    func testLaunchAtLoginReflectsInitialEnabledState() {
        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let controller = MockLaunchAtLoginController(status: .enabled)
        let viewModel = MenuBarViewModel(service: service, launchAtLoginController: controller)

        XCTAssertTrue(viewModel.launchAtLoginEnabled)
        XCTAssertNil(viewModel.launchAtLoginMessage)
        viewModel.stop()
    }

    @MainActor
    func testLaunchAtLoginShowsApprovalMessage() {
        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let controller = MockLaunchAtLoginController(status: .requiresApproval)
        let viewModel = MenuBarViewModel(service: service, launchAtLoginController: controller)

        XCTAssertFalse(viewModel.launchAtLoginEnabled)
        XCTAssertEqual(
            viewModel.launchAtLoginMessage,
            "Approve VitalBar in System Settings > General > Login Items."
        )
        viewModel.stop()
    }

    @MainActor
    func testLaunchAtLoginTreatsUnavailableAsDisabled() {
        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let controller = MockLaunchAtLoginController(status: .disabled)
        let viewModel = MenuBarViewModel(service: service, launchAtLoginController: controller)

        XCTAssertFalse(viewModel.launchAtLoginEnabled)
        XCTAssertNil(viewModel.launchAtLoginMessage)
        viewModel.stop()
    }

    @MainActor
    func testLaunchAtLoginToggleUpdatesState() {
        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let controller = MockLaunchAtLoginController(status: .disabled)
        let viewModel = MenuBarViewModel(service: service, launchAtLoginController: controller)

        viewModel.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(controller.setEnabledCalls, [true])
        XCTAssertTrue(viewModel.launchAtLoginEnabled)
        XCTAssertNil(viewModel.launchAtLoginMessage)
        viewModel.stop()
    }

    @MainActor
    func testLaunchAtLoginTogglePreservesStateOnFailure() {
        struct ToggleError: LocalizedError {
            var errorDescription: String? { "toggle failed" }
        }

        let service = MockCPUHistoryService(initialSnapshot: makeSnapshot())
        let controller = MockLaunchAtLoginController(status: .disabled)
        controller.nextSetResult = .failure(ToggleError())
        let viewModel = MenuBarViewModel(service: service, launchAtLoginController: controller)

        viewModel.setLaunchAtLoginEnabled(true)

        XCTAssertEqual(controller.setEnabledCalls, [true])
        XCTAssertFalse(viewModel.launchAtLoginEnabled)
        XCTAssertEqual(viewModel.launchAtLoginMessage, "toggle failed")
        viewModel.stop()
    }


    private func makeSnapshot(
        samples: [CPULoadSample] = [],
        latest: CPULoadSample? = nil,
        memoryUsage: MemoryUsageSample? = nil,
        diskUsage: DiskUsageSample? = nil,
        temperatures: [TemperatureSensorReading] = [],
        lastSuccessfulSampleAt: Date? = nil,
        isStale: Bool = false,
        consecutiveFailures: Int = 0,
        lastErrorDescription: String? = nil
    ) -> CPUHistorySnapshot {
        CPUHistorySnapshot(
            history: samples,
            latest: latest,
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            temperatures: temperatures,
            lastSuccessfulSampleAt: lastSuccessfulSampleAt,
            isStale: isStale,
            consecutiveFailures: consecutiveFailures,
            lastErrorDescription: lastErrorDescription
        )
    }
}
