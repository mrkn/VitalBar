import SwiftUI
import VitalBarCore

@main
struct VitalBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: MenuBarViewModel

    init() {
        let loadSampler = CPULoadSampler()
        let historyService = CPUHistoryService(
            sampler: loadSampler,
            historyCapacity: CPUHistoryService.defaultHistoryCapacity,
            sampleInterval: CPUHistoryService.defaultSampleInterval,
            staleAfter: CPUHistoryService.defaultStaleAfter
        )

        _viewModel = StateObject(wrappedValue: MenuBarViewModel(service: historyService))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            MenuBarLabelView(
                samples: viewModel.samples,
                usageText: viewModel.currentUsageText,
                isStale: viewModel.isStale
            )
        }
        .menuBarExtraStyle(.window)
    }
}
