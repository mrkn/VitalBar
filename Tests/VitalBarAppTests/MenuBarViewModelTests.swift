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
                    cachedBytes: 5 * gib,
                    compressedBytes: 2 * gib,
                    swapUsedBytes: gib,
                    pressureLevel: .warning
                )
            )
        )
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.samples.count, 120)
        XCTAssertEqual(viewModel.currentUsageText, MenuBarViewModel.percentText(for: samples.last?.usage))
        XCTAssertEqual(viewModel.memoryUsageText, "8.0 GB / 16.0 GB")
        XCTAssertEqual(viewModel.memoryPressureText, "Warning")
        XCTAssertEqual(viewModel.cachedFilesText, "5.0 GB")
        XCTAssertEqual(viewModel.compressedText, "2.0 GB")
        XCTAssertEqual(viewModel.swapUsedText, "1.0 GB")
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
                    cachedBytes: 2 * gib,
                    compressedBytes: gib,
                    swapUsedBytes: 0,
                    pressureLevel: .normal
                ),
                lastSuccessfulSampleAt: base,
                isStale: true,
                consecutiveFailures: 3,
                lastErrorDescription: "sample failure"
            )
        )

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(viewModel.isStale)
        XCTAssertEqual(viewModel.currentUsageText, "42%")
        XCTAssertEqual(viewModel.memoryUsageText, "12.0 GB / 16.0 GB")
        XCTAssertEqual(viewModel.memoryPressureText, "Normal")
        XCTAssertEqual(viewModel.cachedFilesText, "2.0 GB")
        XCTAssertEqual(viewModel.compressedText, "1.0 GB")
        XCTAssertEqual(viewModel.swapUsedText, "0.0 GB")
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

    func testUsageStyleThresholds() {
        XCTAssertEqual(UsageStyle.level(for: nil, isStale: false), .unknown)
        XCTAssertEqual(UsageStyle.level(for: 0.10, isStale: false), .idle)
        XCTAssertEqual(UsageStyle.level(for: 0.65, isStale: false), .moderate)
        XCTAssertEqual(UsageStyle.level(for: 0.90, isStale: false), .high)
        XCTAssertEqual(UsageStyle.level(for: 0.20, isStale: true), .stale)
    }

    @MainActor
    func testMenuBarLabelSparklineDimensions() {
        XCTAssertEqual(MenuBarLabelView.sparklineWidth, 42)
        XCTAssertEqual(MenuBarLabelView.sparklineHeight, 12)
    }

    private func makeSnapshot(
        samples: [CPULoadSample] = [],
        latest: CPULoadSample? = nil,
        memoryUsage: MemoryUsageSample? = nil,
        lastSuccessfulSampleAt: Date? = nil,
        isStale: Bool = false,
        consecutiveFailures: Int = 0,
        lastErrorDescription: String? = nil
    ) -> CPUHistorySnapshot {
        CPUHistorySnapshot(
            history: samples,
            latest: latest,
            memoryUsage: memoryUsage,
            lastSuccessfulSampleAt: lastSuccessfulSampleAt,
            isStale: isStale,
            consecutiveFailures: consecutiveFailures,
            lastErrorDescription: lastErrorDescription
        )
    }
}
